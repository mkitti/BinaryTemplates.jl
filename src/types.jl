abstract type AbstractBinaryTemplate end

struct HeaderOnlyBinaryTemplate <: AbstractBinaryTemplate
    expected_file_size::Int
    header::Vector{UInt8}
end
offsets(::HeaderOnlyBinaryTemplate) = [0]
chunks(t::HeaderOnlyBinaryTemplate) = [t.header]
expected_file_size(t::HeaderOnlyBinaryTemplate) = t.expected_file_size

struct BinaryTemplate <: AbstractBinaryTemplate
    expected_file_size::Int
    offsets::Vector{Int}
    chunks::Vector{Vector{UInt8}}
end
offsets(t::BinaryTemplate) = t.offsets
chunks(t::BinaryTemplate) = t.chunks
expected_file_size(t::BinaryTemplate) = t.expected_file_size

struct ZeroTemplate <: AbstractBinaryTemplate
    expected_file_size::Int
    offsets::Vector{Int}
    chunk_lengths::Vector{Int}
end
offsets(t::ZeroTemplate) = t.offsets
chunks(t::ZeroTemplate) = map(t.chunk_lengths) do l
    zeros(UInt8, l)
end
expected_file_size(t::ZeroTemplate) = t.expected_file_size
ZeroTemplate(t::AbstractBinaryTemplate) = ZeroTemplate(
    expected_file_size(t), offsets(t), length.(chunks(t))
)

struct EmptyTemplate <: AbstractBinaryTemplate
end
offsets(t::EmptyTemplate) = Int[]
chunks(t::EmptyTemplate) = Vector{Vector{UInt8}}()
expected_file_size(t::EmptyTemplate) = 0
