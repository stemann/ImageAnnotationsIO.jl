using Test

include("test_artifacts.jl")

@testset "ImageAnnotationsIO" begin
    include("cvat_xml_serializer_tests.jl")
    include("labelme_xml_serializer_tests.jl")
end
