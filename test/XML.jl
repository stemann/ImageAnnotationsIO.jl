using FactCheck
using LabelMe

facts("annotation") do
    context("empty") do
        expected = Annotation()
        element = XML.element(expected)
        actual = XML.annotation(element)
        @fact actual --> expected
    end
    context("non-empty") do
        expected = Annotation("img1.xml", "test", Source(), nothing, [Object()])
        element = XML.element(expected)
        actual = XML.annotation(element)
        @fact actual --> expected
    end
end

facts("source") do
    context("empty") do
        expected = Source()
        element = XML.element(expected)
        actual = XML.source(element)
        @fact actual --> expected
    end
    context("non-empty") do
        expected = Source("image source", "annotation source")
        element = XML.element(expected)
        actual = XML.source(element)
        @fact actual --> expected
    end
end

facts("object") do
    context("empty") do
        expected = Object()
        element = XML.element(expected)
        actual = XML.object(element)
        @fact actual --> expected
    end
    context("non-empty") do
        expected = Object(1, "car", nothing, true, false, "colour:white", 0, [2,3], DateTime(2013,7,1,12,30,59), Polygon())
        element = XML.element(expected)
        actual = XML.object(element)
        @fact actual --> expected
    end
end

facts("polygon") do
    context("empty") do
        expected = Polygon()
        polygon_element = XML.element(expected)
        actual = XML.polygon(polygon_element)
        @fact actual --> expected
    end
    context("username") do
        expected = Polygon("bob", [])
        polygon_element = XML.element(expected)
        actual = XML.polygon(polygon_element)
        @fact actual --> expected
    end
    context("points") do
        expected = Polygon("", [(2,3),(5,8)])
        polygon_element = XML.element(expected)
        actual = XML.polygon(polygon_element)
        @fact actual --> expected
    end
end
