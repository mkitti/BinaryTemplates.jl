# BinaryTemplates

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://kittisopikulm@janelia.hhmi.org.github.io/BinaryTemplates.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://kittisopikulm@janelia.hhmi.org.github.io/BinaryTemplates.jl/dev/)
[![Build Status](https://github.com/kittisopikulm@janelia.hhmi.org/BinaryTemplates.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/kittisopikulm@janelia.hhmi.org/BinaryTemplates.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/kittisopikulm@janelia.hhmi.org/BinaryTemplates.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/kittisopikulm@janelia.hhmi.org/BinaryTemplates.jl)

BinaryTemplates.jl assembles a file from chunks at byte offsets. This is useful for 

## Example Usage

Below we create a 4 mibibyte template with chunks at byte offsets 0, 4096, and 4193280. The chunks are 1024, 2048, and 512 bytes in length.

The template itself only takes up 3856 bytes. The template can applied to a file that does not yet exist. It will then create a 4 MiB file.

The `apply_template` function checks that it is only overwriting zeros in the file. If it finds non-zero values where the chunks should be,
then it will throw an exception. The function returns a `BinaryTemplate` representing the data that it overwrote with the chunks. This backup
template is also written to a backup file.

Overwriting non-zero values can be opted into with the `ensure_zeros` keyword. By applying the template a second time, we will obtain a second
backup template. This second backup template should be equal to the original template that we applied.

```julia
julia> using BinaryTemplates

julia> binary_template_4MiB = BinaryTemplate(4*1024^2, [0, 4096, 4*1024^2-1024], [rand(UInt8, 1024), rand(UInt8, 2048), rand(UInt8, 512)])
BinaryTemplate:
    expected_file_size: 4.000 MiB

    Offsets            Length     Chunk Checksum
    ------------------ ---------- --------------
    0x0000000000000000       1024     0x68028575
    0x0000000000001000       2048     0x8c68f913
    0x00000000003ffc00        512     0x1ec370e3


julia> Base.summarysize(binary_template_4MiB)
3856

julia> fn = tempname(); apply_template(fn, binary_template_4MiB)
BinaryTemplate:
    expected_file_size: 0 bytes

    Offsets            Length     Chunk Checksum
    ------------------ ---------- --------------
    0x0000000000000000          0     0x00000000
    0x0000000000001000          0     0x00000000
    0x00000000003ffc00          0     0x00000000

julia> filesize(fn)
4194304

julia> backup = apply_template(fn, binary_template_4MiB)
ERROR: Non-zero value found in C:\Users\KITTIS~1\AppData\Local\Temp\jl_vQiVuwO6WZ when applying template. Use keyword `ensure_zero = false` to override.
Stacktrace:
 [1] error(s::String)
   @ Base .\error.jl:33
 [2] apply_template(target_filename::String, t::BinaryTemplate; backup_filename::String, ensure_zero::Bool, truncate::Bool)
   @ BinaryTemplates c:\Users\kittisopikulm\.julia\dev\BinaryTemplates\src\io.jl:161
 [3] apply_template(target_filename::String, t::BinaryTemplate)
   @ BinaryTemplates c:\Users\kittisopikulm\.julia\dev\BinaryTemplates\src\io.jl:148
 [4] top-level scope
   @ REPL[211]:1

julia> backup = apply_template(fn, binary_template_4MiB; ensure_zero = false)
BinaryTemplate:
    expected_file_size: 4.000 MiB

    Offsets            Length     Chunk Checksum
    ------------------ ---------- --------------
    0x0000000000000000       1024     0x68028575
    0x0000000000001000       2048     0x8c68f913
    0x00000000003ffc00        512     0x1ec370e3


julia> backup == binary_template_4MiB
true
```

## Applications

This templating technique can be used to create large HDF5 files where the metadata is confined to a few chunks.
See the [HDF5BinaryTemplates.jl package](HDF5BinaryTemplates). The file can be written very efficiently since
`apply_template` only writes the metadata chunks. It uses `seek` to skip over regions between the chunks,
such as where the datasets might be.