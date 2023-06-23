function parse_bool(s::AbstractString)
    if s == "true" || s == "1" || s == "yes"
        return true
    elseif s == "false" || s == "0" || s == "no"
        return false
    else
        @error "Unexpected boolean value: $s"
    end
end
