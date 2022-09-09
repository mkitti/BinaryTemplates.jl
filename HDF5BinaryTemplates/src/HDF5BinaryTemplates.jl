module HDF5BinaryTemplates

using HDF5, BinaryTemplates
import BinaryTemplates: BinaryTemplate

"""
    simple_hdf5_template(h5_filename, dataset_name, datatype, dataspace)

Create or append a HDF5 file with a newly allocated contiguous dataset. The byte offset to the dataset
is returned.

This function is meant to quickly create a HDF5 file and have an external program fill in the data
at a specific location (offset) at a later time.

The software filling in the data does not need to load the HDF5 library. It only needs to seek to
a specific position in the file and start writing data.
"""
function simple_hdf5_template(
    h5_filename::AbstractString,
    dataset_name::AbstractString,
    dt::HDF5.Datatype,
    ds::HDF5.Dataspace
)
    header_size = h5open(h5_filename, "cw") do h5f
        d = create_dataset(h5f, dataset_name, dt, ds; layout = :contiguous, alloc_time = :early)
        HDF5.API.h5d_get_offset(d.id)
    end
    header = open(h5_filename, "r") do f
        read(f, header_size)
    end
    expected_file_size = filesize(h5_filename)
    return HeaderOnlyBinaryTemplate(expected_file_size, header)
end
function simple_hdf5_template(
    h5_filename::AbstractString,
    dataset_name::AbstractString,
    dt::Type,
    ds::Dims
)
    return simple_hdf5_template(h5_filename, dataset_name, datatype(dt), dataspace(ds))
end

function get_data_offsets(h5f::HDF5.File)
    data_offsets = HDF5.API.haddr_t[]
    data_num_bytes = HDF5.API.hsize_t[]
    for k in keys(h5f)
        h5d = h5f[k]
        if HDF5.iscontiguous(h5d)
            # Get the data_offsets for the datasets
            push!(data_offsets, HDF5.API.h5d_get_offset(h5d))
            push!(data_num_bytes, HDF5.API.h5d_get_storage_size(h5d))
        elseif HDF5.ischunked(h5d)
            num_chunks = HDF5.API.h5d_get_num_chunks(h5d)
            for c in 0:num_chunks-1
                info = HDF5.API.h5d_get_chunk_info(h5d, c)
                push!(data_offsets, info.addr)
                push!(data_num_bytes, info.size)
            end
        elseif HDF5.iscompact(h5d)
            error("Compact HDF5 datasets are not supported.")
        else
            error("Unknown HDF5 key is not a contiguous, chunked, or compact dataset.")
        end
    end
    return (; data_offsets, data_num_bytes)
end
get_data_offsets(filename::String) = h5open(get_data_offsets, filename, "r")

function get_meta_offsets(h5f::HDF5.File)
    data = get_data_offsets(h5f)
    file_sz = Ref{HDF5.API.hsize_t}()
    HDF5.API.h5f_get_filesize(h5f, file_sz)
    return get_meta_offsets(data.data_offsets, data.data_num_bytes, file_sz[])
end

function get_meta_offsets(data_offsets, data_num_bytes, file_size)
    # Look for space between datasets
    dataset_ends = data_offsets .+ data_num_bytes
    # meta_offsets are where metadata start
    meta_offsets = setdiff(dataset_ends, data_offsets)
    # keep the offsets that are not dataset_ends
    data_offsets = setdiff(data_offsets, dataset_ends)

    # Include the first header
    pushfirst!(meta_offsets, 0)
    meta_offsets = sort(meta_offsets)

    if meta_offsets[end] == file_size
        # There is no extra meta data at the end of the file
        pop!(meta_offsets)
    else
        # There is extra meta data at the end of the file
        push!(data_offsets, file_size)
    end
    meta_offsets = sort(meta_offsets)

    meta_num_bytes = data_offsets .- meta_offsets
    return (; meta_offsets, meta_num_bytes)
end
get_meta_offsets(filename::String) = h5open(get_meta_offsets, filename, "r")

function template_from_h5(h5_filename)
    #expected_length = filesize(h5_filename)

    println("Reading $h5_filename.")
    meta_offsets, meta_num_bytes = h5open(get_meta_offsets, h5_filename, "r")

    println("Reading in chunks.")
    meta_chunks = open(h5_filename, "r") do template
        meta_chunks = Vector{Vector{UInt8}}()
        for (meta_offset, meta_num_byte) in zip(meta_offsets, meta_num_bytes)
            seek(template, meta_offset)
            push!(meta_chunks, read(template, meta_num_byte))
        end
        return meta_chunks
    end
    println("Done.")

    return BinaryTemplate(filesize(h5_filename), meta_offsets, meta_chunks)
end

end # module HDF5BinaryTemplates