function Base.show(io::IO, ::MIME"text/plain", t::AbstractBinaryTemplate)
    println(io, typeof(t), ":")
    println(io, "    expected_file_size: $(Base.format_bytes(expected_file_size(t)))")
    println(io)
    println(io, "    Offsets            Length     Chunk Checksum")
    println(io, "    ------------------ ---------- --------------")
    for (offset, chunk) in zip(offsets(t), chunks(t))
        @printf(io, "    0x%016x % 10d     0x%08x\n", offset, length(chunk), crc32c(chunk))
    end
end

"""
    isexpectedfilesize(filename, t::AbstractBinaryTemplate)

Check to see if a file matches the expected filesize of the template.
"""
function isexpectedfilesize(filename, t::AbstractBinaryTemplate)
    return filesize(filename) == expected_file_size(t)
end

"""
    backuptemplate(filename::AbstractString, template::AbstractBinaryTemplate)
    backuptemplate(io::IO, template::AbstractBinaryTemplate)

Backup the chunks that would be overwritten by the template into a new template.
"""
function backuptemplate(filename::AbstractString, t::AbstractBinaryTemplate)
    if !isfile(filename)
        return convert(BinaryTemplate, EmptyTemplate())
    end
    offsets, chunks =  open(filename, "r") do io
        backuptemplate(io, t)
    end
    return BinaryTemplate(filesize(filename), offsets, chunks)
end
function backuptemplate(io::IO, t::AbstractBinaryTemplate)
    _offsets = offsets(t)
    lengths = length.(chunks(t))
    _chunks = map(_offsets, lengths) do offset, length
        seek(io, offset)
        read(io, length)
    end
    seek(io, expected_file_size(t))
    # If there are extra bytes at the end, backup those up
    if position(io) < filesize(io)
        push!(_offsets, position(io))
        push!(_chunks, read(io, filesize(io) - position(io)))
    end
    return _offsets, _chunks
end

"""
    save(template::AbstractBinaryTemplate, filename::AbstractString, mode="w")

Serialize an AbstractBinaryTemplate to a file. It can be reloaded as a BinaryTemplate.
"""
function save(t::AbstractBinaryTemplate, filename::AbstractString, mode="w")
    mkpath(dirname(filename))
    buffer = IOBuffer()
    let io = buffer
        write(io, expected_file_size(t))
        write(io, length(offsets(t)))
        write(io, offsets(t))
        write(io, length.(chunks(t)))
        for chunk in chunks(t)
            write(io, chunk)
        end
    end
    open(filename, mode) do io
        write(io, take!(buffer))
    end
end

"""
    load([BinaryTemplate, ]filename::AbstractString, index=1)

Load a `BinaryTemplate` from a file. By default, the first saved `BinaryTemplate` will be loaded.
Subsequent templates may be accessed via by setting a larger index.
"""
function load(type::Type{BinaryTemplate}, filename::AbstractString, index::Int = 1)
    template = nothing
    open(filename, "r") do io
        for i in 1:index
            template = load(type, io)
        end
    end
    return template
end

function load(::Type{BinaryTemplate}, io::IO)
    expected_file_size = read(io, Int)
    num = read(io, Int)
    offsets = Vector{Int}(undef, num)
    read!(io, offsets)
    lengths = Vector{Int}(undef, num)
    read!(io, lengths)
    chunks = map(lengths) do length
        read(io, length)
    end
    return BinaryTemplate(expected_file_size, offsets, chunks)
end

load_binary_template(filename::AbstractString, index::Int = 1) = load(BinaryTemplate, filename, index)

function _apply_template(
    target_filename::AbstractString,
    meta_offsets::AbstractVector{Int},
    meta_chunks::Vector{Vector{UInt8}},
    expected_file_size::Int = 0;
    truncate = false
)
    open(target_filename, "r+") do f
        # For each offset-chunk pair, seek and write
        for (offset, chunk) in zip(meta_offsets, meta_chunks)
            seek(f, offset)
            write(f, chunk)
        end
        if truncate || filesize(f) < expected_file_size
            # If the file is smaller than expected,
            # expand the file using truncate.
            # if `truncate` is true, then shrink the file.
            Base.truncate(f, expected_file_size)
        end
    end
end

"""
    apply_template(target_filename, template::AbstractBinaryTemplate; backup_filename, ensure_zero=true, truncate=false)

Apply an `AbstractBinaryTemplate` to target_filename by writing chunks to the appropriate offsets.

The file will be enlarged to `expected_file_size(template)`.

# Keywords

`backup_filename` - Name of the file to store the backup template. Default: `BinaryTemplates.backup_filename(target_filename)`.
`ensure_zero` - Throws an error if the bytes to be overwritten are not `0x00`. Default: `true`
`truncate` - Truncate the file if it is larger than expected. Default: `false`
"""
function apply_template(
    target_filename::AbstractString,
    t::AbstractBinaryTemplate;
    backup_filename::AbstractString = backup_filename(target_filename),
    ensure_zero::Bool = true,
    truncate::Bool = false
)
    if !isfile(target_filename)
        touch(target_filename)
    end
    truncate_to_filesize = 0
    if truncate
        truncate_to_filesize = expected_file_size(t)
    else
        @assert filesize(target_filename) <= expected_file_size(t) "$target_filename is not the expected size of $(expected_file_size(t))."
    end
    backup = backuptemplate(target_filename, t)
    if ensure_zero
        for chunk in chunks(backup)
            if !all(==(0), chunk)
                error("Non-zero value found in $target_filename when applying template. Use keyword `ensure_zero = false` to override.")
            end
        end
    end
    save(backup, backup_filename, "a")
    _apply_template(target_filename, offsets(t), chunks(t), expected_file_size(t); truncate)
    return backup
end