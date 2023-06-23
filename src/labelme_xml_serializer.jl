struct LabelMeXMLSerializer{C <: Real} <: AbstractAnnotationSerializer
    include_deleted::Bool
    include_annotation_date_attribute::Bool
    include_annotation_id_attribute::Bool
    include_annotation_verified_attribute::Bool
end

function LabelMeXMLSerializer{C}(;
    include_deleted::Bool = false,
    include_annotation_date_attribute::Bool = false,
    include_annotation_id_attribute::Bool = false,
    include_annotation_verified_attribute::Bool = false,
) where {C}
    return LabelMeXMLSerializer{C}(
        include_deleted, include_annotation_date_attribute, include_annotation_id_attribute, include_annotation_verified_attribute
    )
end

is_filename_valid(filename::AbstractString, ::LabelMeXMLSerializer) = endswith(filename, ".xml")

function FileIO.load(filename::AbstractString, serializer::LabelMeXMLSerializer)::AnnotatedImage
    doc = parse_file(filename)
    return load_from_xml(doc, serializer)
end

function load_from_string(s::AbstractString, serializer::LabelMeXMLSerializer)::AnnotatedImage
    doc = parse_string(s)
    return load_from_xml(doc, serializer)
end

function load_from_xml(doc::XMLDocument, serializer::LabelMeXMLSerializer)::AnnotatedImage
    root_element = root(doc)
    return deserialize(AnnotatedImage, root_element, serializer)
end

function FileIO.save(filename::AbstractString, annotated_image::AnnotatedImage, serializer::LabelMeXMLSerializer)
    root_element = serialize(annotated_image, serializer)
    doc = XMLDocument()
    set_root(doc, root_element)
    save_file(doc, filename)
    return nothing
end

function deserialize(::Type{AnnotatedImage}, e::XMLElement, serializer::LabelMeXMLSerializer{TCoordinate}) where {TCoordinate}
    for a in attributes(e)
        @warn "Unexpected attribute for $(name(e)): $a"
    end
    filename = ""
    folder = ""
    image_height, image_width = nothing, nothing
    annotations = AbstractObjectAnnotation{Label{String}, TCoordinate}[]
    for c in child_elements(e)
        if name(c) == "filename"
            filename = content(c)
        elseif name(c) == "folder"
            folder = content(c)
        elseif name(c) == "source"
            # Ignoring source
        elseif name(c) == "imagesize"
            image_height, image_width = get_image_size(c, serializer)
        elseif name(c) == "object"
            annotation = deserialize(AbstractObjectAnnotation, c, serializer)
            if annotation !== nothing
                push!(annotations, annotation)
            end
        else
            @warn "Unexpected child element for $(name(e)): $c"
        end
    end
    image_file_path = joinpath(folder, filename)
    if isempty(image_file_path)
        image_file_path = nothing
    end
    return AnnotatedImage(annotations, image_file_path, image_height, image_width)
end

function get_image_size(e::XMLElement, ::LabelMeXMLSerializer)
    nrows = tryparse(Int, element_content(e, "nrows"))
    ncols = tryparse(Int, element_content(e, "ncols"))
    return (nrows, ncols)
end

function deserialize(::Type{<:AbstractObjectAnnotation}, e::XMLElement, serializer::LabelMeXMLSerializer{TCoordinate}) where {TCoordinate}
    attributes = Dict{String, Any}()
    class = ""
    vertices = Point2{TCoordinate}[]
    TAnnotation = PolygonAnnotation
    for c in child_elements(e)
        if name(c) == "deleted"
            deleted = parse_bool(content(c))
            if !serializer.include_deleted && deleted
                return nothing
            elseif !serializer.include_deleted && !deleted
                continue
            end
            attributes["deleted"] = deleted
        elseif name(c) == "id"
            if !serializer.include_annotation_id_attribute
                continue
            end
            attributes["id"] = parse(Int, content(c))
        elseif name(c) == "name"
            class = content(c)
        elseif name(c) == "verified"
            if !serializer.include_annotation_verified_attribute
                continue
            end
            attributes["verified"] = parse_bool(content(c))
        elseif name(c) == "occluded"
            attributes["occluded"] = parse_bool(content(c))
        elseif name(c) == "parts"
            parts_parent = tryparse(Int, element_content(c, "ispartof"))
            if parts_parent !== nothing
                attributes["ispartof"] = parts_parent
            end
            hasparts = element_content(c, "hasparts")
            if !isempty(hasparts)
                attributes["hasparts"] = [parse(Int, p) for p in split(hasparts, ','; keepempty = false)]
            end
        elseif name(c) == "date"
            if !serializer.include_annotation_date_attribute
                continue
            end
            attributes["date"] = DateTime(content(c), "d-u-yyyy H:M:S")
        elseif name(c) == "attributes"
            for p in split(content(c), ','; keepempty = false) # separator
                k, v = split(p, ':') # separator
                attributes[string(k)] = v
            end
        elseif name(c) == "polygon"
            vertices = deserialize_polygon(c, serializer)
        elseif name(c) == "type"
            if content(c) == "bounding_box"
                TAnnotation = BoundingBoxAnnotation
            elseif content(c) == "polygon"
                TAnnotation = PolygonAnnotation
            else
                @warn "Unexpected type for $(name(e)): $c"
            end
        else
            @warn "Unexpected child element for $(name(e)): $c"
        end
    end
    try
        return TAnnotation(vertices, Label(class, attributes))
    catch exception
        if exception isa ArgumentError
            @warn "Error creating $TAnnotation for $e: $exception"
            return nothing
        else
            rethrow(e)
        end
    end
end

function deserialize_polygon(e::XMLElement, ::LabelMeXMLSerializer{TCoordinate}) where {TCoordinate}
    vertices = Point2{TCoordinate}[]
    for c in child_elements(e)
        if name(c) == "pt"
            push!(vertices, Point2(parse(TCoordinate, element_content(c, "x")), parse(TCoordinate, element_content(c, "y"))))
        elseif name(c) == "username"
            # Ignoring username
        else
            @warn "Unexpected child element for $(name(e)): $c"
        end
    end
    return vertices
end

function element_content(e::XMLElement, tag::AbstractString)
    first = find_element(e, tag)
    if first === nothing
        return ""
    end
    return content(first)
end

function serialize(a::AnnotatedImage, serializer::LabelMeXMLSerializer{C})::XMLElement where {C}
    e = new_element("annotation")
    add_text(new_child(e, "filename"), a.image_file_path === nothing ? "" : basename(a.image_file_path))
    add_text(new_child(e, "folder"), a.image_file_path === nothing ? "" : dirname(a.image_file_path))
    e_source = new_element("source")
    add_text(new_child(e_source, "sourceImage"), "")
    add_text(new_child(e_source, "sourceAnnotation"), "")
    add_child(e, e_source)
    i = new_child(e, "imagesize")
    add_text(new_child(i, "nrows"), isnothing(a.image_height) ? "" : string(a.image_height))
    add_text(new_child(i, "ncols"), isnothing(a.image_width) ? "" : string(a.image_width))
    for annotation in sort(a.annotations)
        if !(annotation isa PolygonAnnotation)
            @warn "Skipping annotation of type $(typeof(annotation)): $annotation"
            continue
        end
        add_child(e, serialize(annotation, serializer))
    end
    return e
end

function serialize(annotation::PolygonAnnotation{<:AbstractLabel}, serializer::LabelMeXMLSerializer{C})::XMLElement where {C}
    e = new_element("object")
    add_text(new_child(e, "name"), get_label(annotation).value)
    attributes = deepcopy(get_label(annotation).attributes)
    if haskey(attributes, "id")
        add_text(new_child(e, "id"), string(attributes["id"]))
        pop!(attributes, "id")
    end
    if haskey(attributes, "deleted")
        add_text(new_child(e, "deleted"), string(UInt(attributes["deleted"])))
        pop!(attributes, "deleted")
    end
    if haskey(attributes, "verified")
        add_text(new_child(e, "verified"), string(UInt(attributes["verified"])))
        pop!(attributes, "verified")
    end
    if haskey(attributes, "occluded")
        add_text(new_child(e, "occluded"), string(UInt(attributes["occluded"])))
        pop!(attributes, "occluded")
    end
    p = new_child(e, "parts")
    if haskey(attributes, "ispartof")
        add_text(new_child(p, "ispartof"), string(attributes["ispartof"]))
        pop!(attributes, "ispartof")
    end
    if haskey(attributes, "hasparts")
        add_text(new_child(p, "hasparts"), join(attributes["hasparts"], ","))
        pop!(attributes, "hasparts")
    end
    if haskey(attributes, "date")
        add_text(new_child(e, "date"), Dates.format(attributes["date"], "d-u-yyyy H:M:S"))
        pop!(attributes, "date")
    end
    attributes_str = join(["$k:$(string(v))" for (k, v) in attributes], ",") # separator
    add_text(new_child(e, "attributes"), attributes_str)
    add_text(new_child(e, "type"), "polygon")
    add_child(e, serialize(annotation.vertices, serializer))
    return e
end

function serialize(vertices::Vector{Point2{TCoordinate}}, ::LabelMeXMLSerializer{TCoordinate})::XMLElement where {TCoordinate}
    e = new_element("polygon")
    for pt in vertices
        pt_e = new_child(e, "pt")
        add_text(new_child(pt_e, "x"), string(pt[1]))
        add_text(new_child(pt_e, "y"), string(pt[2]))
    end
    return e
end
