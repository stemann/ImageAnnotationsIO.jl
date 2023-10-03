struct LabelMeXMLSerializer{C <: Real} <: AbstractAnnotationSerializer
    include_deleted::Bool
    include_annotation_date_attribute::Bool
    include_annotation_id_attribute::Bool
    include_annotation_verified_attribute::Bool
    rounding_config::RoundingConfig
end

function LabelMeXMLSerializer{C}(;
    include_deleted::Bool = false,
    include_annotation_date_attribute::Bool = false,
    include_annotation_id_attribute::Bool = false,
    include_annotation_verified_attribute::Bool = false,
    round_digits::Int = 1,
    round_enabled::Bool = true,
    round_mode::RoundingMode = RoundNearest,
) where {C}
    return LabelMeXMLSerializer{C}(
        include_deleted,
        include_annotation_date_attribute,
        include_annotation_id_attribute,
        include_annotation_verified_attribute,
        RoundingConfig(round_digits, round_enabled, round_mode),
    )
end

is_filename_valid(filename::AbstractString, ::LabelMeXMLSerializer) = endswith(filename, ".xml")

function FileIO.load(filename::AbstractString, serializer::LabelMeXMLSerializer)::AnnotatedImage
    doc = read(filename, Node)
    annotated_image = load_from_xml(doc, serializer)
    return annotated_image
end

function load_from_string(s::AbstractString, serializer::LabelMeXMLSerializer)::AnnotatedImage
    doc = parse(Node, s)
    annotated_image = load_from_xml(doc, serializer)
    return annotated_image
end

function load_from_xml(doc::XML.AbstractXMLNode, serializer::LabelMeXMLSerializer)::AnnotatedImage
    root_element = doc[end]
    return deserialize(AnnotatedImage, root_element, serializer)
end

function FileIO.save(filename::AbstractString, annotated_image::AbstractAnnotatedImage, serializer::LabelMeXMLSerializer)
    root_element = serialize(annotated_image, serializer)
    declaration = XML.Declaration(; version = "1.0", encoding = "UTF-8")
    doc = XML.Document(declaration, root_element)
    XML.write(filename, doc)
    return nothing
end

function deserialize(::Type{AnnotatedImage}, e::XML.AbstractXMLNode, serializer::LabelMeXMLSerializer{TCoordinate}) where {TCoordinate}
    if !isnothing(attributes(e))
        for (k, v) in attributes(e)
            @warn "Unexpected attribute for $(tag(e)): $k = $v"
        end
    end
    filename = ""
    folder = ""
    image_height, image_width = nothing, nothing
    annotations = AbstractObjectAnnotation{Label{String}, TCoordinate}[]
    for c in children(e)
        if tag(c) == "filename"
            filename = simplevalue(c)
        elseif tag(c) == "folder"
            folder = simplevalue(c)
        elseif tag(c) == "source"
            # Ignoring source
        elseif tag(c) == "imagesize"
            image_height, image_width = get_image_size(c, serializer)
        elseif tag(c) == "object"
            annotation = deserialize(AbstractObjectAnnotation, c, serializer)
            if annotation !== nothing
                push!(annotations, annotation)
            end
        else
            @warn "Unexpected child element for $(tag(e)): $(XML.write(c))"
        end
    end
    image_file_path = joinpath(folder, filename)
    if isempty(image_file_path)
        image_file_path = nothing
    end
    return AnnotatedImage(annotations, image_file_path, image_height, image_width)
end

function get_image_size(e::XML.AbstractXMLNode, ::LabelMeXMLSerializer)
    nrows = tryparse(Int, element_content(e, "nrows"))
    ncols = tryparse(Int, element_content(e, "ncols"))
    return (nrows, ncols)
end

function deserialize(
    ::Type{<:AbstractObjectAnnotation}, e::XML.AbstractXMLNode, serializer::LabelMeXMLSerializer{TCoordinate}
) where {TCoordinate}
    attributes = Dict{String, Any}()
    class = ""
    vertices = Point2{TCoordinate}[]
    TAnnotation = PolygonAnnotation
    for c in children(e)
        if tag(c) == "deleted"
            deleted = parse_bool(simplevalue(c))
            if !serializer.include_deleted && deleted
                return nothing
            elseif !serializer.include_deleted && !deleted
                continue
            end
            attributes["deleted"] = deleted
        elseif tag(c) == "id"
            if !serializer.include_annotation_id_attribute
                continue
            end
            attributes["id"] = parse(Int, simplevalue(c))
        elseif tag(c) == "name"
            class = unescape_unicode(simplevalue(c))
        elseif tag(c) == "verified"
            if !serializer.include_annotation_verified_attribute
                continue
            end
            attributes["verified"] = parse_bool(simplevalue(c))
        elseif tag(c) == "occluded"
            attributes["occluded"] = parse_bool(simplevalue(c))
        elseif tag(c) == "parts"
            parts_parent = tryparse(Int, element_content(c, "ispartof"))
            if parts_parent !== nothing
                attributes["ispartof"] = parts_parent
            end
            hasparts = element_content(c, "hasparts")
            if !isempty(hasparts)
                attributes["hasparts"] = [parse(Int, p) for p in split(hasparts, ','; keepempty = false)]
            end
        elseif tag(c) == "date"
            if !serializer.include_annotation_date_attribute
                continue
            end
            attributes["date"] = DateTime(simplevalue(c), "d-u-yyyy H:M:S")
        elseif tag(c) == "attributes"
            if !is_simple(c) # <attributes/>
                if isnothing(XML.attributes(c)) && isempty(children(c))
                    continue
                end
            end
            for p in split(simplevalue(c), ','; keepempty = false) # separator
                k, v = split(p, ':') # separator
                attributes[string(k)] = unescape_unicode(v)
            end
        elseif tag(c) == "polygon"
            vertices = deserialize_polygon(c, serializer)
        elseif tag(c) == "type"
            if simplevalue(c) == "bounding_box"
                TAnnotation = BoundingBoxAnnotation
            elseif simplevalue(c) == "polygon"
                TAnnotation = PolygonAnnotation
            else
                @warn "Unexpected type for $(tag(e)): $(XML.write(c))"
            end
        else
            @warn "Unexpected child element for $(tag(e)): $(XML.write(c))"
        end
    end
    try
        return TAnnotation(vertices, Label(class, attributes))
    catch exception
        if exception isa ArgumentError
            @warn "Error creating $TAnnotation for $(XML.write(e)): $exception"
            return nothing
        else
            rethrow(e)
        end
    end
end

function deserialize_polygon(e::XML.AbstractXMLNode, ::LabelMeXMLSerializer{TCoordinate}) where {TCoordinate}
    vertices = Point2{TCoordinate}[]
    for c in children(e)
        if tag(c) == "pt"
            pt_x = parse(TCoordinate, element_content(c, "x"))
            pt_y = parse(TCoordinate, element_content(c, "y"))
            push!(vertices, Point2{TCoordinate}(pt_x, pt_y))
        elseif tag(c) == "username"
            # Ignoring username
        else
            @warn "Unexpected child element for $(tag(e)): $(XML.write(c))"
        end
    end
    return vertices
end

function element_content(e::XML.AbstractXMLNode, tag_name::AbstractString)
    child_elements = filter(c -> tag(c) == tag_name, children(e))
    if isempty(child_elements)
        return ""
    end
    first_child_element = first(child_elements)
    if !is_simple(first_child_element)
        return ""
    end
    return simplevalue(first_child_element)
end

function serialize(a::AbstractAnnotatedImage, serializer::LabelMeXMLSerializer{C})::XML.AbstractXMLNode where {C}
    e = XML.Element("annotation")
    push!(e, XML.Element("filename", Text(a.image_file_path === nothing ? "" : basename(a.image_file_path))))
    push!(e, XML.Element("folder", Text(a.image_file_path === nothing ? "" : dirname(a.image_file_path))))
    e_source = XML.Element("source")
    push!(e_source, XML.Element("sourceImage", Text("")))
    push!(e_source, XML.Element("sourceAnnotation", Text("")))
    push!(e, e_source)
    i = XML.Element("imagesize")
    push!(i, XML.Element("nrows", Text(isnothing(a.image_height) ? "" : string(a.image_height))))
    push!(i, XML.Element("ncols", Text(isnothing(a.image_width) ? "" : string(a.image_width))))
    push!(e, i)
    for annotation in sort(a.annotations)
        if !(annotation isa PolygonAnnotation)
            @warn "Skipping annotation of type $(typeof(annotation)): $annotation"
            continue
        end
        push!(e, serialize(annotation, serializer))
    end
    return e
end

function serialize(
    annotation::AbstractPolygonAnnotation{<:AbstractLabel}, serializer::LabelMeXMLSerializer{C}
)::XML.AbstractXMLNode where {C}
    e = XML.Element("object")
    push!(e, XML.Element("name", Text(get_label(annotation).value)))
    attributes = deepcopy(get_label(annotation).attributes)
    if haskey(attributes, "id")
        push!(e, XML.Element("id", Text(string(attributes["id"]))))
        pop!(attributes, "id")
    end
    if haskey(attributes, "deleted")
        push!(e, XML.Element("deleted", Text(string(UInt(attributes["deleted"])))))
        pop!(attributes, "deleted")
    end
    if haskey(attributes, "verified")
        push!(e, XML.Element("verified", Text(string(UInt(attributes["verified"])))))
        pop!(attributes, "verified")
    end
    if haskey(attributes, "occluded")
        push!(e, XML.Element("occluded", Text(string(UInt(attributes["occluded"])))))
        pop!(attributes, "occluded")
    end
    p = XML.Element("parts")
    if haskey(attributes, "ispartof")
        push!(p, XML.Element("ispartof", Text(string(attributes["ispartof"]))))
        pop!(attributes, "ispartof")
    end
    if haskey(attributes, "hasparts")
        push!(p, XML.Element("hasparts", Text(join(attributes["hasparts"], ","))))
        pop!(attributes, "hasparts")
    end
    push!(e, p)
    if haskey(attributes, "date")
        push!(e, XML.Element("date", Text(Dates.format(attributes["date"], "d-u-yyyy H:M:S"))))
        pop!(attributes, "date")
    end
    attributes_str = join(["$k:$(string(v))" for (k, v) in attributes], ",") # separator
    push!(e, XML.Element("attributes", Text(attributes_str)))
    push!(e, XML.Element("type", Text("polygon")))
    push!(e, serialize(annotation.vertices, serializer))
    return e
end

function serialize(
    vertices::Vector{Point2{TCoordinate}}, serializer::LabelMeXMLSerializer{TCoordinate}
)::XML.AbstractXMLNode where {TCoordinate}
    e = XML.Element("polygon")
    for pt in vertices
        pt_x_e = XML.Element("x", Text(to_string(pt[1], serializer.rounding_config)))
        pt_y_e = XML.Element("y", Text(to_string(pt[2], serializer.rounding_config)))
        pt_e = XML.Element("pt", pt_x_e, pt_y_e)
        push!(e, pt_e)
    end
    return e
end
