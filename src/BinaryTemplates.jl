module BinaryTemplates

using Printf
using CRC32c

export offsets, chunks, expected_file_size
export apply_template
export BinaryTemplate, HeaderOnlyBinaryTemplate, EmptyTemplate, ZeroTemplate

include("types.jl")
include("util.jl")
include("convert.jl")
include("io.jl")

end # module BinaryTemplates