function Base.:(==)(x::AbstractBinaryTemplate, y::AbstractBinaryTemplate)
    expected_file_size(x) == expected_file_size(y) &&
    chunks(x) == chunks(y) &&
    offsets(x) == offsets(y)
end

"""
    backup_filename(filename)

Get the backup file name for `filename`. This function does not actually backup anything.
"""
function backup_filename(filename)
    dir = dirname(filename)
    base = splitext(basename(filename))[1]
    return joinpath(dir, "backup", base * "_backup.template")
end