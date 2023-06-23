using Dates
using GeometryBasics
using ImageAnnotations
using ImageAnnotations.Dummies
using ImageAnnotationsIO
using Test

@testset "LabelMe" begin
    serializer = LabelMeXMLSerializer{Float64}()
    @testset "AnnotatedImage" begin
        @testset "empty" begin
            expected = AnnotatedImage()
            element = serialize(expected, serializer)
            actual = deserialize(AnnotatedImage, element, serializer)
            @test actual == expected
        end
        @testset "non-empty" begin
            expected = AnnotatedImage(
                PolygonAnnotation([Point2(0.0, 0.0), Point2(0.0, 1.0), Point2(1.0, 0.0)], Label("class"));
                image_file_path = joinpath("test", "img1.xml"),
                image_width = 640,
                image_height = 480,
            )
            element = serialize(expected, serializer)
            actual = deserialize(AnnotatedImage, element, serializer)
            @test actual == expected
        end
    end

    @testset "PolygonAnnotation" begin
        @testset "non-empty" begin
            serializer = LabelMeXMLSerializer{Float64}(;
                include_deleted = true,
                include_annotation_date_attribute = true,
                include_annotation_id_attribute = true,
                include_annotation_verified_attribute = true,
            )
            expected = PolygonAnnotation(
                [Point2(0.0, 0.0), Point2(0.0, 1.0), Point2(1.0, 0.0)],
                Label(
                    "car",
                    Dict{String, Any}(
                        "id" => 1,
                        "deleted" => false,
                        "verified" => true,
                        "occluded" => false,
                        "colour" => "white",
                        "ispartof" => 0,
                        "hasparts" => [2, 3],
                        "date" => DateTime(2013, 7, 1, 12, 30, 59),
                    ),
                ),
            )
            element = serialize(expected, serializer)
            actual = deserialize(AbstractObjectAnnotation, element, serializer)
            @test actual == expected
        end
    end
end
