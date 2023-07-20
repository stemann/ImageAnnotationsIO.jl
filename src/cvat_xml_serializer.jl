struct CVATXMLSerializer{C <: Real} <: AbstractAnnotationSerializer end

is_filename_valid(filename::AbstractString, ::CVATXMLSerializer) = endswith(filename, ".xml")

function FileIO.load(filename::AbstractString, serializer::CVATXMLSerializer)::ImageAnnotationDataSet
    doc = parse_file(filename)
    return load_from_xml(doc, serializer)
end

function load_from_string(s::AbstractString, serializer::CVATXMLSerializer)::ImageAnnotationDataSet
    doc = parse_string(s)
    return load_from_xml(doc, serializer)
end

function load_from_xml(doc::XMLDocument, serializer::CVATXMLSerializer)::ImageAnnotationDataSet
    root_element = root(doc)
    return deserialize_annotations(root_element, serializer)
end

function FileIO.save(filename::AbstractString, data_set::ImageAnnotationDataSet, serializer::CVATXMLSerializer)
    root_element = serialize(data_set, serializer)
    doc = XMLDocument()
    set_root(doc, root_element)
    save_file(doc, filename)
    return nothing
end

function serialize(data_set::ImageAnnotationDataSet{Label{String}}, serializer::CVATXMLSerializer)
    e = new_element("annotations")
    add_text(new_child(e, "version"), "1.1")
    for annotated_image in sort(data_set.annotated_images)
        add_child(e, serialize(annotated_image, serializer))
    end
    return e
end

function deserialize_annotations(root_element::XMLElement, serializer::CVATXMLSerializer)
    @assert name(root_element) == "annotations"
    schema = Label{String}[]
    meta = find_element(root_element, "meta")
    if meta !== nothing
        task = find_element(meta, "task")
        if task !== nothing
            labels_element = find_element(task, "labels")
            if labels_element !== nothing
                schema = deserialize_labels(labels_element, serializer)
            end
        end
    end
    annotated_images = AnnotatedImage[]
    for image_element in filter(c -> name(c) == "image", child_elements(root_element))
        annotated_image = deserialize_annotated_image(image_element, serializer)
        if annotated_image !== nothing
            push!(annotated_images, annotated_image)
        end
    end
    data_set = ImageAnnotationDataSet(schema, annotated_images)
    return data_set
end

function deserialize_labels(element::XMLElement, serializer::CVATXMLSerializer)
    labels = Label{String}[] # TODO
    for c in child_elements(element)
        if name(c) == "label"
            push!(labels, deserialize_label(c, serializer))
        else
            @warn "Unexpected child element for $(name(e)): $c"
        end
    end
    return labels
end

function deserialize_label(element::XMLElement, serializer::CVATXMLSerializer)
    name = ""
    attributes = Dict{String, Any}()
    for c in child_elements(element)
        if name(c) == "name"
            name = content(c)
        elseif name(c) == "attributes"
            for a in child_elements(c)
                if name(a) == "attribute"
                    deserialize_label_attribute(a, serializer)
                else
                    @warn "Unexpected child element for $(name(c)): $a"
                end
            end
        else
            @warn "Unexpected child element for $(name(e)): $c"
        end
    end
    return Label{String}(name, attributes) # TODO
end

function deserialize_label_attribute(element::XMLElement, serializer::CVATXMLSerializer)
    name = ""
    default_value = ""
    values = String[]
    for c in child_elements(element)
        if name(c) == "name"
            name = content(c)
        elseif name(c) == "default_value"
            default_value = content(c)
        elseif name(c) == "values"
            for v in child_elements(c)
                if name(v) == "value"
                    push!(values, content(v))
                else
                    @warn "Unexpected child element for $(name(c)): $v"
                end
            end
        else
            @warn "Unexpected child element for $(name(element)): $c"
        end
    end
    return Attribute(name, default_value, values) # TODO
end

function serialize(annotated_image::AnnotatedImage, serializer::CVATXMLSerializer)
    e = new_element("image")
    set_attribute(e, "name", annotated_image.image_file_path)
    if annotated_image.image_width !== nothing
        set_attribute(e, "width", string(annotated_image.image_width))
    end
    if annotated_image.image_height !== nothing
        set_attribute(e, "height", string(annotated_image.image_height))
    end
    for annotation in sort(annotated_image.annotations)
        add_child(e, serialize(annotation, serializer))
    end
    return e
end

function serialize(
    annotation::AbstractObjectAnnotation{Label{String}, TCoordinate}, serializer::CVATXMLSerializer{TCoordinate}
) where {TCoordinate}
    attributes = deepcopy(get_label(annotation).attributes)
    if annotation isa BoundingBoxAnnotation
        e = new_element("box")
        set_attribute(e, "xtl", string(annotation.rect.origin[1]))
        set_attribute(e, "ytl", string(annotation.rect.origin[2]))
        set_attribute(e, "xbr", string(annotation.rect.origin[1] + annotation.rect.widths[1]))
        set_attribute(e, "ybr", string(annotation.rect.origin[2] + annotation.rect.widths[2]))
    elseif annotation isa PolygonAnnotation
        e = new_element("polygon")
        set_attribute(e, "points", join(map(v -> "$(v[1]),$(v[2])", annotation.vertices), ';'))
    else
        @error "Unsupported annotation type: $(typeof(annotation))"
    end
    set_attribute(e, "label", get_label(annotation).value)
    if haskey(attributes, "occluded")
        set_attribute(e, "occluded", string(attributes["occluded"]))
        pop!(attributes, "occluded")
    end
    if haskey(attributes, "z_order")
        set_attribute(e, "z_order", string(attributes["z_order"]))
        pop!(attributes, "z_order")
    end
    for (key, value) in sort(attributes)
        attribute_element = new_child(e, "attribute")
        set_attribute(attribute_element, "name", key)
        add_text(attribute_element, string(value))
    end
    return e
end
