function parse_bool(s::AbstractString)
    if s == "true" || s == "1" || s == "yes"
        return true
    elseif s == "false" || s == "0" || s == "no"
        return false
    else
        @error "Unexpected boolean value: $s"
    end
end

function parse_simple(s::AbstractString)
    s_ = tryparse(Bool, s)
    if isnothing(s_)
        s_ = tryparse(Int, s)
        if isnothing(s_)
            s_ = tryparse(Float32, s)
            if isnothing(s_)
                s_ = tryparse(Float64, s)
            end
        end
    end
    if !isnothing(s_)
        s = s_
    else
        s = string(s)
    end
    return s
end

function unescape_unicode(s::AbstractString)
    i = firstindex(s)
    while (m = match(r"&#(x)(\w{2,4});", s, i)) !== nothing
        s = replace(s, m.match => unescape_string("\\u$(m.captures[2])"))
        i = m.offset + 1
    end
    return s
end

function to_string(x::Real, rounding_config::RoundingConfig)
    if rounding_config.enabled
        return string(round(x, rounding_config.mode; digits = rounding_config.digits))
    else
        return string(x)
    end
end
