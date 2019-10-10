load("//openapi:openapi.bzl", "openapi_gen")

openapi_gen(
    name = "petstore",
    language = "go",
    spec = "petstore.yaml",
    outputs = [
        "model_error.go",
        "model_pet.go",
        "api_pets.go",
        "configuration.go",
        "client.go",
        "response.go",
        "go.mod",
        "go.sum",
    ]
)

openapi_gen(
    name = "petstore_java",
    language = "java",
    spec = "petstore.yaml",
    outputs = [
        "src/test/java/org/openapitools/client/model/PetTest.java",
    ]
)

openapi_gen(
    name = "petstore_java_feign",
    additional_properties = {
        "library": "feign",
    },
    language = "java",
    spec = "petstore.yaml",
    outputs = [
        "src/main/java/org/openapitools/client/api/PetsApi.java",
        "src/test/java/org/openapitools/client/api/PetsApiTest.java",
    ]
)

openapi_gen(
    name = "petstore_java_no_tests",
    language = "java",
    spec = "petstore.yaml",
    system_properties = {
        "apiTests": "false",
        "modelTests": "false",
    },
    outputs = [
        "src/main/java/org/openapitools/client/model/Pet.java",
    ]
)

openapi_gen(
    name = "petstore_java_bigdecimal",
    language = "java",
    spec = "petstore.yaml",
    type_mappings = {
        "Integer": "java.math.BigDecimal",
    },
    outputs = [
        "src/main/java/org/openapitools/client/model/Error.java",
    ]
)
