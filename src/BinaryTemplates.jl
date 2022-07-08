module BinaryTemplates

using Printf
using CRC32c

export offsets, chunks, expected_file_size
export create_template, apply_template

include("types.jl")
include("util.jl")
include("convert.jl")
include("io.jl")

end # module BinaryTemplates