using Dates
using ImageAnnotationsIO.LabelMe
using Test

@testset "annotation" begin
    @testset "empty" begin
        expected = Annotation()
        element = XML.element(expected)
        actual = XML.annotation(element)
        @test actual == expected
    end
    @testset "non-empty" begin
        expected = Annotation("img1.xml", "test", Source(), nothing, [Object()])
        element = XML.element(expected)
        actual = XML.annotation(element)
        @test actual == expected
    end
end

@testset "source" begin
    @testset "empty" begin
        expected = Source()
        element = XML.element(expected)
        actual = XML.source(element)
        @test actual == expected
    end
    @testset "non-empty" begin
        expected = Source("image source", "annotation source")
        element = XML.element(expected)
        actual = XML.source(element)
        @test actual == expected
    end
end

@testset "object" begin
    @testset "empty" begin
        expected = Object()
        element = XML.element(expected)
        actual = XML.object(element)
        @test actual == expected
    end
    @testset "non-empty" begin
        expected = Object(1, "car", nothing, true, false, "colour:white", 0, [2,3], DateTime(2013,7,1,12,30,59), Polygon())
        element = XML.element(expected)
        actual = XML.object(element)
        @test actual == expected
    end
end

@testset "polygon" begin
    @testset "empty" begin
        expected = Polygon()
        polygon_element = XML.element(expected)
        actual = XML.polygon(polygon_element)
        @test actual == expected
    end
    @testset "username" begin
        expected = Polygon("bob", [])
        polygon_element = XML.element(expected)
        actual = XML.polygon(polygon_element)
        @test actual == expected
    end
    @testset "points" begin
        expected = Polygon("", [(2,3),(5,8)])
        polygon_element = XML.element(expected)
        actual = XML.polygon(polygon_element)
        @test actual == expected
    end
end
