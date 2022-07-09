abstract type AbstractBinaryTemplate end

"""
    HeaderOnlyBinaryTemplate

AbstractBinaryTemplate that consists of a single chunk at the beginning of the file.

# Fields
* `expected_file_size::Int`: Expected size of the file
* `header::Vector{UInt8}`: Chunk of bytes to be written to the template header
"""
struct HeaderOnlyBinaryTemplate <: AbstractBinaryTemplate
    expected_file_size::Int
    header::Vector{UInt8}
end
offsets(::HeaderOnlyBinaryTemplate) = [0]
chunks(t::HeaderOnlyBinaryTemplate) = [t.header]
expected_file_size(t::HeaderOnlyBinaryTemplate) = t.expected_file_size

"""
    BinaryTemplate

General binary template with multiple chunks at various file offsets.

# Fields
* `expected_file_size::Int`: Expected size of the file
* `offsets::Vector{Int}`: Byte offsets for each chunk
* `chunks::Vector{Vector{UInt8}}`: Bytes for each chunk
"""
struct BinaryTemplate <: AbstractBinaryTemplate
    expected_file_size::Int
    offsets::Vector{Int}
    chunks::Vector{Vector{UInt8}}
end
offsets(t::BinaryTemplate) = t.offsets
chunks(t::BinaryTemplate) = t.chunks
expected_file_size(t::BinaryTemplate) = t.expected_file_size

"""
    ZeroTemplate

AbstractBinaryTemplate where all the chunks consist bytes equal to `0x00`.

# Fields
* `expected_file_size::Int`: Expected size of the file
* `offsets::Vector{Int}`: Byte offsets for each chunk
* `chunks_lengths::Vector{Int}`: Length of each chunk
"""
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

"""
    EmptyTemplate

Template containing no chunks.
# Field
* `execpted_file_size::Int = 0`: Expected size of the file
"""
struct EmptyTemplate <: AbstractBinaryTemplate
    expected_file_size::Int
    EmptyTemplate(expected_file_size=0) = new(expected_file_size)
end
offsets(::EmptyTemplate) = Int[]
chunks(::EmptyTemplate) = Vector{Vector{UInt8}}()
expected_file_size(t::EmptyTemplate) = t.expected_file_size
