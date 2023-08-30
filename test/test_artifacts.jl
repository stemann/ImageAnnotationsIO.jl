using Artifacts
using LazyArtifacts

datumaro_path = first(readdir(artifact"datumaro"; join = true))
datumaro_test_assets_path = joinpath(datumaro_path, "tests", "assets")
