using GeometryBasics
using ImageAnnotations
using ImageAnnotationsIO
using OrderedCollections
using Test
using XML

@testset "CVATXMLSerializer" begin
    serializer = CVATXMLSerializer{Float64}()

    @testset "AnnotatedImage" begin
        image_file_path = joinpath("images", "img1.jpeg")
        image_id = 2
        image_height = 480
        image_width = 640
        @testset "empty" begin
            expected = AnnotatedImage(; image_file_path)
            element = serialize(expected, image_id, serializer)
            actual = deserialize(AnnotatedImage, element, serializer)
            @test actual == expected
        end
        @testset "non-empty" begin
            expected = AnnotatedImage(
                [
                    BoundingBoxAnnotation(Point2(0.0, 1.0), 2.0, 3.0, Label("car")),
                    ImageAnnotation(Label("car")),
                    OrientedBoundingBoxAnnotation(Point2(3.0, 3.0), 4.0, 2.0, pi / 2, Label("car")),
                    PolygonAnnotation([Point2(0.0, 0.0), Point2(0.0, 1.0), Point2(1.0, 0.0)], Label("car")),
                ];
                image_file_path,
                image_width = 640,
                image_height = 480,
            )
            element = serialize(expected, image_id, serializer)
            actual = deserialize(AnnotatedImage, element, serializer)
            @test actual == expected
        end
    end

    @testset "AbstractImageAnnotation" begin
        @testset "BoundingBoxAnnotation" begin
            expected = BoundingBoxAnnotation(Point2(0.0, 1.0), 2.0, 3.0, Label("car"))

            element = serialize(expected, serializer)
            @test tag(element) == "box"
            @test !isnothing(attributes(element))
            @test attributes(element) == OrderedDict("label" => "car", "xtl" => "0.0", "ytl" => "1.0", "xbr" => "2.0", "ybr" => "4.0")

            annotation = deserialize(BoundingBoxAnnotation{Label{String}, Float64}, element, serializer)
            @test annotation == expected
        end
        @testset "ImageAnnotation" begin
            expected = ImageAnnotation(Label("car"))

            element = serialize(expected, serializer)
            @test tag(element) == "tag"
            @test !isnothing(attributes(element))
            @test attributes(element) == OrderedDict("label" => "car")
        end
        @testset "OrientedBoundingBoxAnnotation" begin
            expected = OrientedBoundingBoxAnnotation(Point2(3.0, 3.0), 4.0, 2.0, pi / 2, Label("car"))

            element = serialize(expected, serializer)
            @test tag(element) == "box"
            @test !isnothing(attributes(element))
            @test attributes(element) ==
                OrderedDict("label" => "car", "xtl" => "1.0", "ytl" => "2.0", "xbr" => "5.0", "ybr" => "4.0", "rotation" => "90.0")

            annotation = deserialize(OrientedBoundingBoxAnnotation{Label{String}, Float64}, element, serializer)
            @test annotation == expected
        end
        @testset "PolygonAnnotation" begin
            expected = PolygonAnnotation([Point2(0.0, 0.0), Point2(0.0, 1.0), Point2(1.0, 0.0)], Label("car"))

            element = serialize(expected, serializer)
            @test tag(element) == "polygon"
            @test !isnothing(attributes(element))
            @test attributes(element) == OrderedDict("label" => "car", "points" => "0.0,0.0;0.0,1.0;1.0,0.0")

            annotation = deserialize(PolygonAnnotation{Label{String}, Float64}, element, serializer)
            @test annotation == expected
        end
    end

    @testset "Save/load equivalence for datumaro test assets" begin
        for (dir_path, file_path) in [("export_task", "train.xml")] # Disabled ("export_project", "annotations.xml")] due to sorting difference
            @testset "$dir_path/$file_path" begin
                filename = joinpath(datumaro_test_assets_path, "cvat_dataset", "for_images", dir_path, file_path)
                serializer = CVATXMLSerializer{Float64}(; include_image_id = true, include_schema = false, sort_annotations = true)
                dataset = load(filename, serializer)

                expected = deepcopy(dataset)

                mktemp() do tmp_path, _
                    save(tmp_path, dataset, serializer)
                    actual = load(tmp_path, serializer)
                    @test actual == expected
                end
            end
        end
    end
end
