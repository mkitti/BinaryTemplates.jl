function Base.convert(::Type{BinaryTemplate}, t::AbstractBinaryTemplate)
    return BinaryTemplate(
        expected_file_size(t),
        offsets(t),
        chunks(t)
    )
end

function Base.convert(::Type{HeaderOnlyBinaryTemplate}, t::AbstractBinaryTemplate)
    @assert offsets(t) == [0] "Template does not have only one chunk at offset 0. Cannot convert to HeaderOnlyBinaryTemplate"
    return HeaderOnlyBinaryTemplate(
        expected_file_size(t),
        first(chunks(t))
    )
end

