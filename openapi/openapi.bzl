load("@bazel_tools//tools/build_defs/repo:jvm.bzl", "jvm_maven_import_external")

def openapi_repositories(
      openapi_cli_version="4.0.3",
      openapi_cli_sha256="c5b1f9925740026b21929b1b86dff1a47c92d2b32bd56b64552fa028cc6a09f4",
      prefix="io_bazel_rules_openapi"):

    jvm_maven_import_external(
        name = prefix + "_io_swagger_swagger_codegen_cli",
        artifact = "org.openapitools:openapi-generator-cli:" + openapi_cli_version,
        artifact_sha256 = openapi_cli_sha256,
        server_urls = ["https://repo.maven.apache.org/maven2"],
        licenses = ["notice"],  # Apache 2.0 License
    )
    native.bind(
        name = prefix + '/dependency/openapi-cli',
        actual = '@' + prefix + '_io_swagger_swagger_codegen_cli//jar',
    )

def _comma_separated_pairs(pairs):
    return ",".join([
        "{}={}".format(k, v) for k, v in pairs.items()
    ])

def _new_generator_command(ctx, gen_dir, rjars):
  gen_cmd = [
    str(ctx.attr._jdk[java_common.JavaRuntimeInfo].java_executable_exec_path),

    '-cp {cli_jar}:{jars}'.format(
      cli_jar = ctx.file.codegen_cli.path,
      jars = ":".join([j.path for j in rjars.to_list()]),
    ),

    'org.openapitools.codegen.OpenAPIGenerator',
    'generate',
    '--input-spec',     ctx.file.spec.path,
    '--generator-name', ctx.attr.language,
    '--output',         gen_dir,
    '-D "{properties}"'.format(properties=_comma_separated_pairs(ctx.attr.system_properties))
  ]

  # java_path = ctx.attr._jdk[java_common.JavaRuntimeInfo].java_executable_exec_path
  # gen_cmd = str(java_path)
  gen_cmd = ' '.join(gen_cmd)

  additional_properties = dict(ctx.attr.additional_properties)

  # This is needed to ensure reproducible Java output
  if ctx.attr.language == "java" and \
      "hideGenerationTimestamp" not in ctx.attr.additional_properties:
      additional_properties["hideGenerationTimestamp"] = "true"

  gen_cmd += ' --additional-properties "{properties}"'.format(
      properties=_comma_separated_pairs(additional_properties),
  )

  gen_cmd += ' --type-mappings "{mappings}"'.format(
      mappings=_comma_separated_pairs(ctx.attr.type_mappings),
  )

  if ctx.attr.api_package:
      gen_cmd += " --api-package {package}".format(
          package=ctx.attr.api_package
      )
  if ctx.attr.invoker_package:
      gen_cmd += " --invoker-package {package}".format(
          package=ctx.attr.invoker_package
      )
  if ctx.attr.model_package:
      gen_cmd += " --model-package {package}".format(
          package=ctx.attr.model_package
      )
  return gen_cmd

def _impl(ctx):
    jars = _collect_jars(ctx.attr.deps)
    (cjars, rjars) = (jars.compiletime, jars.runtime)
    gen_dir = "{dirname}/{rule_name}".format(
        dirname=ctx.file.spec.dirname,
        rule_name=ctx.attr.name
    )

    commands = [
      "mkdir -p {gen_dir}".format(
        gen_dir=gen_dir
      ),
      _new_generator_command(ctx, gen_dir, rjars),
      # forcing a timestamp for deterministic artifacts
      "find {gen_dir} -exec touch -t 198001010000 {{}} \;".format(
         gen_dir=gen_dir
      ),
      "cp -r {gen_dir}/* {bin_dir}/{dirname}".format(
        gen_dir=gen_dir,
        bin_dir=ctx.bin_dir.path,
        dirname=ctx.file.spec.dirname
      ),
    ]

    inputs = ctx.files._jdk + ctx.files.data + [
        ctx.file.codegen_cli,
        ctx.file.spec
    ] + cjars.to_list() + rjars.to_list()
    ctx.actions.run_shell(
        inputs=inputs,
        outputs=ctx.outputs.outputs,
        command=" && ".join(commands),
        progress_message="generating openapi sources %s" % ctx.label,
        arguments=[],

        # TODO: This does not appear to work
        env={'JAVA_OPTS': '-Dlog.level=%s' % ctx.attr.log_level}
    )

# taken from rules_scala
def _collect_jars(targets):
    """Compute the runtime and compile-time dependencies from the given targets"""  # noqa
    compile_jars = depset()
    runtime_jars = depset()
    for target in targets:
        found = False
        if hasattr(target, "scala"):
            if hasattr(target.scala.outputs, "ijar"):
                compile_jars = depset(transitive = [compile_jars, [target.scala.outputs.ijar]])
            compile_jars = depset(transitive = [compile_jars, target.scala.transitive_compile_exports])
            runtime_jars = depset(transitive = [runtime_jars, target.scala.transitive_runtime_deps])
            runtime_jars = depset(transitive = [runtime_jars, target.scala.transitive_runtime_exports])
            found = True
        if hasattr(target, "JavaInfo"):
            # see JavaSkylarkApiProvider.java,
            # this is just the compile-time deps
            # this should be improved in bazel 0.1.5 to get outputs.ijar
          # compile_jars = depset(transitive = [compile_jars, [target.java.outputs.ijar]])
            compile_jars = depset(transitive = [compile_jars, target[JavaInfo].transitive_deps])
            runtime_jars = depset(transitive = [runtime_jars, target[JavaInfo].transitive_runtime_deps])
            found = True
        if not found:
            # support http_file pointed at a jar. http_jar uses ijar,
            # which breaks scala macros
            runtime_jars = depset(transitive = [runtime_jars, target.files])
            compile_jars = depset(transitive = [compile_jars, target.files])

    return struct(compiletime = compile_jars, runtime = runtime_jars)

openapi_gen = rule(
    attrs = {
        # downstream dependencies
        "deps": attr.label_list(),
        # openapi spec file
        "spec": attr.label(
            mandatory=True,
            allow_single_file=[".json", ".yaml"]
        ),
        # language to generate
        "language": attr.string(mandatory=True),
        "api_package": attr.string(),
        "invoker_package": attr.string(),
        "model_package": attr.string(),
        "additional_properties": attr.string_dict(),
        "system_properties": attr.string_dict(),
        "log_level": attr.string(default="debug"),
        "type_mappings": attr.string_dict(),
        "data": attr.label_list(allow_files=[".json", ".yaml"]),
        "outputs": attr.output_list(allow_empty=False, mandatory=True),
        "_jdk": attr.label(
            default=Label("@bazel_tools//tools/jdk:current_java_runtime"),
            providers = [java_common.JavaRuntimeInfo]
        ),
        "codegen_cli": attr.label(
            cfg = "host",
            default = Label("//external:io_bazel_rules_openapi/dependency/openapi-cli"),
            allow_single_file = True,
        ),
    },
    implementation = _impl,
)
