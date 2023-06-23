abstract type AbstractAnnotationSerializer end

const default_image_filename_extensions = collect(
    Iterators.flatten(map(v -> v isa String ? [v] : v, map(s -> FileIO.sym2info[s][2], [:BMP, :EXR, :JPEG, :PNG, :QOI, :TIFF])))
)

function is_image_filename(filename::AbstractString, filename_extensions::Vector{String})
    return any(map(ext -> endswith(filename, ext), filename_extensions))
end

function load_dataset_dir(
    dir_path::AbstractString,
    serializer::AbstractAnnotationSerializer;
    images_dir_path::AbstractString = dir_path,
    base_path::Union{AbstractString, Nothing} = nothing,
    image_base_path::Union{AbstractString, Nothing} = nothing,
    ensure_image_file_exists::Bool = true,
    include_images_without_annotations::Bool = true,
    image_filename_extensions_to_include::Vector{String} = default_image_filename_extensions,
    image_should_be_loaded::Bool = true,
)::ImageAnnotationDataSet
    if base_path !== nothing
        dir_path = joinpath(base_path, dir_path)
    end
    if image_base_path === nothing
        image_base_path = images_dir_path
    end
    dir_contents = readdir(dir_path; join = true)
    annotated_images = AnnotatedImage[]
    image_filepaths_handled = String[]
    for file_path in filter(p -> isfile(p) && is_filename_valid(p, serializer), dir_contents)
        annotated_image = load(file_path, serializer)
        if ensure_image_file_exists
            image_file_path = joinpath(image_base_path, annotated_image.image_file_path)
            if !isfile(image_file_path)
                @warn "Image file $(annotated_image.image_file_path) does not exist @ $image_file_path"
            end
        end
        push!(annotated_images, annotated_image)
        push!(image_filepaths_handled, annotated_image.image_file_path)
    end
    if include_images_without_annotations
        image_filepaths_without_annotations = filter(
            p ->
                is_image_filename(p, image_filename_extensions_to_include) &&
                    chopprefix(p, image_base_path * "/") ∉ image_filepaths_handled,
            readdir(images_dir_path; join = true),
        )
        for image_filepath in image_filepaths_without_annotations
            rel_image_filepath = chopprefix(image_filepath, image_base_path * "/")
            kwargs = (image_file_path = rel_image_filepath,)
            if image_should_be_loaded
                image = load(image_filepath)
                image_height, image_width = size(image)
                kwargs = (kwargs..., image_height = image_height, image_width = image_width)
            end
            push!(annotated_images, AnnotatedImage(; kwargs...))
        end
    end
    schema = get_labels(annotated_images) # HACK should be only if kwarg/serializer schema === nothing
    return ImageAnnotationDataSet(schema, annotated_images)
end
