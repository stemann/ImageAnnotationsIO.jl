struct CVATXMLSerializer{C <: Real} <: AbstractAnnotationSerializer
    include_image_id::Bool
    include_schema::Bool
    sort_annotations::Bool
end

function CVATXMLSerializer{C}(; include_image_id::Bool = false, include_schema::Bool = false, sort_annotations::Bool = true) where {C}
    return CVATXMLSerializer{C}(include_image_id, include_schema, sort_annotations)
end

is_filename_valid(filename::AbstractString, ::CVATXMLSerializer) = endswith(filename, ".xml")

function FileIO.load(filename::AbstractString, serializer::CVATXMLSerializer)::ImageAnnotationDataSet
    doc = read(filename, Node)
    dataset = load_from_xml(doc, serializer)
    return dataset
end

function load_from_string(s::AbstractString, serializer::CVATXMLSerializer)::ImageAnnotationDataSet
    doc = parse(Node, s)
    dataset = load_from_xml(doc, serializer)
    return dataset
end

function load_from_xml(doc::XML.AbstractXMLNode, serializer::CVATXMLSerializer)::ImageAnnotationDataSet
    root_element = doc[end]
    return deserialize(ImageAnnotationDataSet, root_element, serializer)
end

function FileIO.save(filename::AbstractString, data_set::ImageAnnotationDataSet, serializer::CVATXMLSerializer)
    root_element = serialize(data_set, serializer)
    declaration = XML.Declaration(; version = "1.0", encoding = "UTF-8")
    doc = XML.Document(declaration, root_element)
    XML.write(filename, doc)
    return nothing
end

function serialize(data_set::ImageAnnotationDataSet, serializer::CVATXMLSerializer)
    e = XML.Element("annotations", XML.Element("version", XML.Text("1.1")))
    if !isempty(data_set.schema) && serializer.include_schema
        meta_element = XML.Element("meta")
        task_element = XML.Element("task")
        labels_element = XML.Element("labels")
        for label in data_set.schema
            push!(labels_element, serialize_label(label, serializer))
        end
        push!(task_element, labels_element)
        push!(meta_element, task_element)
        push!(e, meta_element)
    end
    for (image_id, annotated_image) in enumerate(sort(data_set.annotated_images))
        push!(e, serialize(annotated_image, image_id - 1, serializer))
    end
    return e
end

function deserialize(::Type{ImageAnnotationDataSet}, root_element::XML.AbstractXMLNode, serializer::CVATXMLSerializer)
    @assert tag(root_element) == "annotations"
    schema = Label{String}[]
    if serializer.include_schema
        meta_elements = filter(c -> tag(c) == "meta", children(root_element))
        if !isempty(meta_elements)
            meta_element = first(meta_elements)
            task = first(filter(c -> tag(c) == "task", children(meta_element)))
            if task !== nothing
                labels_element = first(filter(c -> tag(c) == "labels", children(task)))
                if labels_element !== nothing
                    schema = deserialize_labels(labels_element, serializer)
                end
            end
        end
    end
    annotated_images = AnnotatedImage[]
    for image_element in filter(c -> tag(c) == "image", children(root_element))
        annotated_image = deserialize(AnnotatedImage, image_element, serializer)
        if annotated_image !== nothing
            push!(annotated_images, annotated_image)
        end
    end
    data_set = ImageAnnotationDataSet(schema, annotated_images)
    return data_set
end

function serialize_label(label::AbstractString, serializer::CVATXMLSerializer)
    return serialize_label(Concept(label), serializer)
end

function serialize_label(label::Concept{<:AbstractString}, serializer::CVATXMLSerializer)
    e = XML.Element("label")
    push!(e, XML.Element("name", XML.Text(label.value)))
    if !isempty(label.attributes)
        attributes_element = XML.Element("attributes")
        for (_, attribute) in label.attributes
            attribute_element = XML.Element("attribute")
            push!(attribute_element, XML.Element("name", attribute.name))
            push!(attribute_element, XML.Element("default_value", string(attribute.default_value)))
            push!(attribute_element, XML.Element("values", join(string.(attribute.values), ' ')))
            push!(attributes_element, attribute_element)
        end
        push!(e, attributes_element)
    end
    return e
end

function deserialize_labels(element::XML.AbstractXMLNode, serializer::CVATXMLSerializer)
    labels = Concept{String}[]
    for c in children(element)
        if tag(c) == "label"
            push!(labels, deserialize_label(c, serializer))
        else
            @warn "Unexpected child element for $(tag(element)): $(XML.write(c))"
        end
    end
    return labels
end

function deserialize_label(element::XML.AbstractXMLNode, serializer::CVATXMLSerializer)
    value = ""
    attributes = CategoricalConceptAttribute[]
    for c in children(element)
        if tag(c) == "name"
            value = simplevalue(c)
        elseif tag(c) == "attributes"
            for a in children(c)
                if tag(a) == "attribute"
                    attribute = deserialize_label_attribute(a, serializer)
                    push!(attributes, attribute)
                else
                    @warn "Unexpected child element for $(tag(c)): $(XML.write(a))"
                end
            end
        else
            @warn "Unexpected child element for $(tag(element)): $(XML.write(c))"
        end
    end
    return Concept(value; attributes)
end

function deserialize_label_attribute(element::XML.AbstractXMLNode, serializer::CVATXMLSerializer)
    attribute_name = ""
    default_value = nothing
    values = Any[]
    for c in children(element)
        if tag(c) == "name"
            attribute_name = simplevalue(c)
        elseif tag(c) == "default_value"
            default_value = parse_simple(simplevalue(c))
        elseif tag(c) == "input_type"
            # Ignoring input_type
        elseif tag(c) == "values"
            values = map(parse_simple, split(simplevalue(c), ' '))
        else
            @warn "Unexpected child element for $(tag(element)): $(XML.write(c))"
        end
    end
    if default_value ∉ values
        push!(values, default_value)
    end
    if eltype(values) == Integer
        values = Int.(values)
        default_value = Int(default_value)
    elseif eltype(values) == Real
        values = Float32.(values)
        default_value = Float32(default_value)
    end
    return CategoricalConceptAttribute(attribute_name, values, default_value)
end

function deserialize(::Type{AnnotatedImage}, element::XML.AbstractXMLNode, serializer::CVATXMLSerializer{TCoordinate}) where {TCoordinate}
    image_height, image_file_path, image_width = nothing, nothing, nothing
    for (k, v) in attributes(element)
        if k == "height"
            image_height = parse(Int, v)
        elseif k == "id"
            # Ignoring id # TODO add attributes to AnnotatedImage
        elseif k == "name"
            image_file_path = v
        elseif k == "task_id"
            # Ignoring task_id
        elseif k == "subset"
            # Ignoring subset
        elseif k == "width"
            image_width = parse(Int, v)
        else
            @warn "Unexpected attribute for $(tag(element)): $(k) = $(v)"
        end
    end
    annotations = AbstractImageAnnotation{Label{String}}[]
    for c in children(element)
        if tag(c) == "box"
            if haskey(attributes(c), "rotation")
                annotation = deserialize(OrientedBoundingBoxAnnotation{Label{String}, TCoordinate}, c, serializer)
            else
                annotation = deserialize(BoundingBoxAnnotation{Label{String}, TCoordinate}, c, serializer)
            end
            push!(annotations, annotation)
        elseif tag(c) == "polygon"
            annotation = deserialize(PolygonAnnotation{Label{String}, TCoordinate}, c, serializer)
            push!(annotations, annotation)
        elseif tag(c) == "tag"
            annotation = deserialize(ImageAnnotation{Label{String}}, c, serializer)
            push!(annotations, annotation)
        else
            @warn "Unexpected child element for $(tag(element)): $(XML.write(c))"
        end
    end
    annotations = serializer.sort_annotations ? sort(annotations) : annotations
    return AnnotatedImage(annotations, image_file_path, image_height, image_width)
end

function deserialize(
    ::Type{TAnnotation}, element::XML.AbstractXMLNode, serializer::CVATXMLSerializer{T}
) where {T, TAnnotation <: AbstractImageAnnotation{Label{String}}}
    annotation_attributes = Dict{String, Any}()
    label::Union{String, Nothing} = nothing
    geometry = nothing
    for (k, v) in attributes(element)
        if k == "label"
            label = unescape_unicode(v)
        elseif k == "occluded"
            annotation_attributes["occluded"] = parse(Int, v) == 1
        elseif tag(element) == "box" && (k == "xbr" || k == "ybr" || k == "xtl" || k == "ytl" || k == "rotation")
            # Cf. below
        elseif tag(element) == "polygon" && k == "points"
            points = v
            vertices = Point2{T}[]
            for p_str in split(points, ';')
                p = split(p_str, ',')
                push!(vertices, Point2{T}(parse(T, p[1]), parse(T, p[2])))
            end
            geometry = (vertices,)
        elseif k == "source"
            # Ignoring source
        elseif k == "z_order"
            # Ignoring z_order
        else
            @warn "Unexpected attribute for $(tag(element)): $(k) = $(v)"
        end
    end
    if tag(element) == "box"
        xbr = parse(T, element["xbr"])
        ybr = parse(T, element["ybr"])
        xtl = parse(T, element["xtl"])
        ytl = parse(T, element["ytl"])
        rect = get_bounding_box([Point2{T}(xtl, ytl), Point2{T}(xbr, ybr)])
        if haskey(attributes(element), "rotation")
            center = rect.origin + rect.widths / 2
            width, height = rect.widths
            orientation = parse(T, element["rotation"])
            geometry = (Point2{T}(center...), width, height, orientation)
        else
            geometry = (rect,)
        end
    end
    for c in children(element)
        if tag(c) == "attribute"
            if haskey(annotation_attributes, c["name"])
                @warn "Duplicate attribute for $(tag(element)): $(c["name"])"
            end
            @assert length(children(c)) == 1
            v = value(first(children(c)))
            v = parse_simple(v)
            if v isa String
                v = unescape_unicode(v)
            end
            annotation_attributes[c["name"]] = v
        else
            @warn "Unexpected child element for $(tag(element)): $(XML.write(c))"
        end
    end
    if !isnothing(geometry)
        return TAnnotation(geometry..., Label(label, annotation_attributes))
    else
        return TAnnotation(Label(label, annotation_attributes))
    end
end

function serialize(annotated_image::AnnotatedImage, image_id::Int, serializer::CVATXMLSerializer)
    if isnothing(annotated_image.image_file_path)
        throw(ArgumentError("$(AnnotatedImage).image_file_path cannot be nothing"))
    end
    e = XML.Element("image")
    xml_attributes = OrderedDict{String, String}()
    xml_attributes["name"] = annotated_image.image_file_path
    if annotated_image.image_width !== nothing
        xml_attributes["width"] = string(annotated_image.image_width)
    end
    if annotated_image.image_height !== nothing
        xml_attributes["height"] = string(annotated_image.image_height)
    end
    if serializer.include_image_id
        xml_attributes["id"] = string(image_id)
    end
    for (k, v) in sort(xml_attributes)
        e[k] = v
    end
    annotations = serializer.sort_annotations ? sort(annotated_image.annotations) : annotated_image.annotations
    for annotation in annotations
        push!(e, serialize(annotation, serializer))
    end
    return e
end

function serialize(annotation::AbstractImageAnnotation{Label{String}}, ::CVATXMLSerializer{TCoordinate}) where {TCoordinate}
    attributes = OrderedDict(get_label(annotation).attributes)
    xml_attributes = OrderedDict{String, String}()
    if annotation isa BoundingBoxAnnotation
        e = XML.Element("box")
        xml_attributes["xtl"] = string(annotation.rect.origin[1])
        xml_attributes["ytl"] = string(annotation.rect.origin[2])
        xml_attributes["xbr"] = string(annotation.rect.origin[1] + annotation.rect.widths[1])
        xml_attributes["ybr"] = string(annotation.rect.origin[2] + annotation.rect.widths[2])
    elseif annotation isa ImageAnnotation
        e = XML.Element("tag")
    elseif annotation isa OrientedBoundingBoxAnnotation
        e = XML.Element("box")
        top_left = annotation.center - Point2{TCoordinate}(annotation.width, annotation.height) / 2
        xml_attributes["xtl"] = string(top_left[1])
        xml_attributes["ytl"] = string(top_left[2])
        xml_attributes["xbr"] = string(top_left[1] + annotation.width)
        xml_attributes["ybr"] = string(top_left[2] + annotation.height)
        xml_attributes["rotation"] = string(annotation.orientation)
    elseif annotation isa PolygonAnnotation
        e = XML.Element("polygon")
        xml_attributes["points"] = join(map(v -> "$(v[1]),$(v[2])", annotation.vertices), ';')
    else
        @error "Unsupported annotation type: $(typeof(annotation))"
    end
    xml_attributes["label"] = get_label(annotation).value
    if haskey(attributes, "occluded")
        if attributes["occluded"] == true
            xml_attributes["occluded"] = string(Int(attributes["occluded"]))
        end
        pop!(attributes, "occluded")
    end
    if haskey(attributes, "z_order")
        if attributes["z_order"] != 0
            xml_attributes["z_order"] = string(attributes["z_order"])
        end
        pop!(attributes, "z_order")
    end
    for (k, v) in sort(xml_attributes)
        e[k] = v
    end
    for (key, value) in sort(attributes)
        attribute_element = XML.Element("attribute", string(value))
        attribute_element["name"] = key
        push!(e, attribute_element)
    end
    return e
end
