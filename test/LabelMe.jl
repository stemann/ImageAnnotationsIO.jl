using FactCheck
using LabelMe: Annotation, Source, Object, Polygon

facts("==") do
    context("Annotation") do
        a = Annotation("img1.xml", "test", Source(), nothing, [Object()])
        b = Annotation("img1.xml", "test", Source(), nothing, [Object()])
        @fact a --> b
    end
    context("Source") do
        a = Source("image source", "annotation source")
        b = Source("image source", "annotation source")
        @fact a --> b
    end
    context("Object") do
        a = Object(1, "car", nothing, true, false, "", 0, [2,3], DateTime(2013,7,1,12,30,59), Polygon())
        b = Object(1, "car", nothing, true, false, "", 0, [2,3], DateTime(2013,7,1,12,30,59), Polygon())
        @fact a --> b
    end
    context("Polygon") do
        a = Polygon("bob", [(2,3),(5,8)])
        b = Polygon("bob", [(2,3),(5,8)])
        @fact a --> b
    end
end
