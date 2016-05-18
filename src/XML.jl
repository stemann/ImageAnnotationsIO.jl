module XML

using LabelMe
using LightXML

export load, annotation, source, image_size, object, polygon, element

function load(filename::AbstractString)
    e = root(parse_file(filename))
    return annotation(e)
end

function annotation(e::XMLElement)
    a = Annotation()
    a.filename = element_content(e, "filename")
    a.folder = element_content(e, "folder")
    a.source = source(find_element(e, "source"))
    a.image_size = image_size(find_element(e, "imagesize"))
    for object_element in get_elements_by_tagname(e, "object")
        push!(a.objects, object(object_element))
    end
    return a
end

function source(e::XMLElement)
    s = Source()
    s.sourceImage = element_content(e, "sourceImage")
    s.sourceAnnotation = element_content(e, "sourceAnnotation")
    return s
end

function image_size(e::XMLElement)
    nrows = tryparse(Int64, element_content(e, "nrows"))
    ncols = tryparse(Int64, element_content(e, "ncols"))
    if isnull(nrows) || isnull(ncols)
        return nothing
    end
    return (nrows, ncols)
end

function object(e::XMLElement)
    o = Object()
    o.id = tryparse(Int64, element_content(e, "id"))
    o.name = element_content(e, "name")
    o.deleted = tryparse(UInt8, element_content(e, "deleted"))
    o.verified = tryparse(UInt8, element_content(e, "verified"))
    o.occluded = tryparse(UInt8, element_content(e, "occluded"))
    o.attributes = element_content(e, "attributes")
    o.parts_parent = tryparse(Int64, element_content(find_element(e, "parts"), "ispartof"))
    hasparts = element_content(find_element(e, "parts"), "hasparts")
    o.parts_children = [parse(Int64, p) for p in split(hasparts, ','; keep=false)]
    o.date = DateTime(element_content(e, "date"), "d-u-yyyy H:M:S")
    o.polygon = polygon(find_element(e, "polygon"))
    return o
end

function polygon(e::XMLElement)
    p = Polygon()
    p.username = element_content(e, "username")
    for pt_element in get_elements_by_tagname(e, "pt")
        push!(p.points, (
            parse(Int64, element_content(pt_element, "x")),
            parse(Int64, element_content(pt_element, "y"))
            ))
    end
    return p
end

function element_content(e::XMLElement, tag::AbstractString)
    first = find_element(e, tag)
    if first == nothing
        return ""
    end
    return content(first)
end

function element(a::Annotation)
    e = new_element("annotation")
    add_text(new_child(e, "filename"), a.filename)
    add_text(new_child(e, "folder"), a.folder)
    add_child(e, element(a.source))
    i = new_child(e, "imagesize")
    add_text(new_child(i, "nrows"), isnull(a.image_size) ? "" : string(get(a.image_size)[1]))
    add_text(new_child(i, "ncols"), isnull(a.image_size) ? "" : string(get(a.image_size)[2]))
    for o in a.objects
        add_child(e, element(o))
    end
    return e
end

function element(s::Source)
    e = new_element("source")
    add_text(new_child(e, "sourceImage"), s.sourceImage)
    add_text(new_child(e, "sourceAnnotation"), s.sourceAnnotation)
    return e
end

function element(o::Object)
    e = new_element("object")
    if !isnull(o.id)
        add_text(new_child(e, "id"), string(get(o.id)))
    end
    add_text(new_child(e, "name"), o.name)
    if !isnull(o.deleted)
        add_text(new_child(e, "deleted"), string(UInt8(get(o.deleted))))
    end
    if !isnull(o.verified)
        add_text(new_child(e, "verified"), string(UInt8(get(o.verified))))
    end
    if !isnull(o.occluded)
        add_text(new_child(e, "occluded"), string(UInt8(get(o.occluded))))
    end
    add_text(new_child(e, "attributes"), o.attributes)
    p = new_child(e, "parts")
    if !isnull(o.parts_parent)
        add_text(new_child(p, "ispartof"), string(get(o.parts_parent)))
    end
    add_text(new_child(p, "hasparts"), join(o.parts_children, ","))
    add_text(new_child(e, "date"), Dates.format(o.date, "d-u-yyyy H:M:S"))
    add_child(e, element(o.polygon))
    return e
end

function element(p::Polygon)
    e = new_element("polygon")
    add_text(new_child(e, "username"), p.username)
    for pt in p.points
        pt_e = new_child(e, "pt")
        add_text(new_child(pt_e, "x"), string(pt[1]))        
        add_text(new_child(pt_e, "y"), string(pt[2]))        
    end
    return e
end

end # module
