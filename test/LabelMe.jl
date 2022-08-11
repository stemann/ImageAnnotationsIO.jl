using Dates
using ImageAnnotationsIO.LabelMe
using Test

@testset "==" begin
    @testset "Annotation" begin
        a = Annotation("img1.xml", "test", Source(), nothing, [Object()])
        b = Annotation("img1.xml", "test", Source(), nothing, [Object()])
        @test a == b
    end
    @testset "Source" begin
        a = Source("image source", "annotation source")
        b = Source("image source", "annotation source")
        @test a == b
    end
    @testset "Object" begin
        a = Object(1, "car", nothing, true, false, "", 0, [2,3], DateTime(2013,7,1,12,30,59), Polygon())
        b = Object(1, "car", nothing, true, false, "", 0, [2,3], DateTime(2013,7,1,12,30,59), Polygon())
        @test a == b
    end
    @testset "Polygon" begin
        a = Polygon("bob", [(2,3),(5,8)])
        b = Polygon("bob", [(2,3),(5,8)])
        @test a == b
    end
end
