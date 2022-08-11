module LabelMe

using Dates

import Base.==

export Annotation, Source, Object, Polygon, XML

mutable struct Polygon
    username::AbstractString
    points::Vector{Tuple{Float32,Float32}}

    Polygon() = new("", Vector())
    Polygon(username, points) = new(username, points)
end

==(a::Polygon, b::Polygon) = a.username == b.username && a.points == b.points

mutable struct Object
    id::Union{Integer, Nothing}
    name::AbstractString
    deleted::Union{Bool, Nothing}
    verified::Union{Bool, Nothing}
    occluded::Union{Bool, Nothing}
    attributes::AbstractString
    parts_parent::Union{Integer, Nothing}
    parts_children::Vector{Integer}
    date::DateTime
    polygon::Polygon

    Object() = new(nothing, "", nothing, nothing, nothing, "", nothing,
        Vector(), DateTime(0), Polygon())
    Object(id, name, deleted, verified, occluded, attributes, parts_parent, parts_children, date, polygon) =
        new(id, name, deleted, verified, occluded, attributes, parts_parent, parts_children, date, polygon)
    Object(polygon::Polygon) = new(nothing, "", nothing, nothing, nothing, "", nothing,
        Vector(), DateTime(0), polygon)
end

function ==(a::Object, b::Object)
    return isequal(a.id, b.id) &&
        a.name == b.name &&
        isequal(a.deleted, b.deleted) &&
        isequal(a.verified, b.verified) &&
        isequal(a.occluded, b.occluded) &&
        a.attributes == b.attributes &&
        isequal(a.parts_parent, b.parts_parent) &&
        a.parts_children == b.parts_children &&
        a.date == b.date &&
        a.polygon == b.polygon
end

mutable struct Source
    sourceImage::AbstractString
    sourceAnnotation::AbstractString

    Source() = new("", "")
    Source(sourceImage, sourceAnnotation) = new(sourceImage, sourceAnnotation)
end

==(a::Source, b::Source) = a.sourceImage == b.sourceImage && a.sourceAnnotation == b.sourceAnnotation

mutable struct Annotation
    filename::AbstractString
    folder::AbstractString
    source::Source
    image_size::Union{Tuple{Integer,Integer}, Nothing}
    objects::Vector{Object}

    Annotation() = new("", "", Source(), nothing, Vector())
    Annotation(filename, folder, source, image_size, objects) = new(filename, folder, source, image_size, objects)
end

function ==(a::Annotation, b::Annotation)
    return a.filename == b.filename &&
        a.folder == b.folder &&
        isequal(a.source, b.source) &&
        isequal(a.image_size, b.image_size) &&
        a.objects == b.objects
end

include("XML.jl")

end # module
