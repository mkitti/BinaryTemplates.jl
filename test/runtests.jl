using BinaryTemplates
using Test

@testset "BinaryTemplates.jl" begin
    testdir =  mktempdir()

    # Test header only template construction
    header_only_template = HeaderOnlyBinaryTemplate(4096, rand(UInt8, 2048))
    @test expected_file_size(header_only_template) == 4096
    @test offsets(header_only_template) == [0]
    @test chunks(header_only_template) == [header_only_template.header]

    # Test conversion of HeaderOnlyTemplate to BinaryTemplate
    binary_template = convert(BinaryTemplate, header_only_template)
    @test header_only_template == binary_template
    @test expected_file_size(binary_template) == 4096
    @test offsets(header_only_template) == [0]
    @test chunks(header_only_template) == [header_only_template.header]
    @test header_only_template == convert(HeaderOnlyBinaryTemplate, binary_template)

    io = IOBuffer()
    show(io, MIME"text/plain"(), header_only_template)
    output = String(take!(io))
    @test contains(output, "HeaderOnlyBinaryTemplate")
    @test contains(output, "expected_file_size: 4.000 KiB")
    @test contains(output, "0x0000000000000000")
    @test contains(output, "2048")

    show(io, MIME"text/plain"(), header_only_template)
    output = String(take!(io))
    @test contains(output, "BinaryTemplate")
    @test contains(output, "expected_file_size: 4.000 KiB")
    @test contains(output, "0x0000000000000000")
    @test contains(output, "2048")

    # Apply template to an empty file
    fn = tempname(testdir)
    empty_template = apply_template(fn, header_only_template)
    @test expected_file_size(empty_template) == 0
    @test filesize(fn) == expected_file_size(binary_template)
    # Backup template should be the same as the header only template
    check_template = BinaryTemplates.backuptemplate(fn, header_only_template)
    @test check_template == header_only_template
    @test_throws ErrorException apply_template(fn, header_only_template)

    # Test 
    backup_template = apply_template(fn, binary_template; ensure_zero = false)
    @test backup_template == header_only_template
    @test read(fn, 2048) == header_only_template.header
    @test filesize(fn) == expected_file_size(binary_template)

    binary_template_4MiB = BinaryTemplate(4*1024^2, [0, 4096, 4*1024^2-1024], [rand(UInt8, 1024), rand(UInt8, 2048), rand(UInt8, 512)])
    show(io, MIME"text/plain"(), binary_template_4MiB)
    output = String(take!(io))
    @test contains(output, "expected_file_size: 4.000 MiB")
    @test contains(output, "0x0000000000000000")
    @test contains(output, "0x0000000000001000")
    @test contains(output, "0x00000000003ffc00")
    @test contains(output, "1024")
    @test contains(output, "2048")
    @test contains(output, "512")

    fn = tempname(testdir)
    apply_template(fn, binary_template_4MiB)
    @test filesize(fn) == 4*1024^2
    open(fn) do f
        seek(f, 0)
        @test read(f, 1024) == binary_template_4MiB.chunks[1]
        seek(f, 4096)
        @test read(f, 2048) == binary_template_4MiB.chunks[2]
        seek(f, 4*1024^2-1024)
        @test read(f, 512) == binary_template_4MiB.chunks[3]
    end
    @test length(binary_template_4MiB.offsets) == 3

    zero_template = ZeroTemplate(binary_template_4MiB)
    backup_file = BinaryTemplates.backup_filename(fn)
    @test endswith(dirname(backup_file), "backup")

    # Remove backup file so that new template will be first
    rm(backup_file)
    check_template = apply_template(fn, zero_template; ensure_zero = false)
    @test check_template == binary_template_4MiB
    @test BinaryTemplates.load(BinaryTemplate, backup_file) == binary_template_4MiB
    @test length(binary_template_4MiB.offsets) == 3

    A = rand(UInt8, 4096-1024)
    B = rand(UInt8, 4*1024^2-1024-2048-1024-length(A))

    open(fn, "w") do f
        truncate(f, 4*1024^2)
        seekstart(f)
        write(f, zeros(UInt8, 1024))
        write(f, A)
        write(f, zeros(UInt8, 2048))
        write(f, B)
        write(f, zeros(UInt8, 512))
    end

    @test length(binary_template_4MiB.chunks) == 3
    check_template = apply_template(fn, binary_template_4MiB)
    @test check_template == zero_template
    @test filesize(fn) == expected_file_size(binary_template_4MiB)
    open(fn, "r") do f
        @test read(f, 1024) == binary_template_4MiB.chunks[1]
    end

    backup_template = apply_template(fn, zero_template; ensure_zero = false)
    embedded_template = BinaryTemplate(expected_file_size(binary_template_4MiB), [offsets(binary_template_4MiB)[2]], [chunks(binary_template_4MiB)[2]])
    check_template = apply_template(fn, embedded_template)
    @test length(binary_template_4MiB.chunks) == 3

    open(fn) do f
        seek(f, first(offsets(embedded_template)))
        chunk = first(chunks(embedded_template))
        @test read(f, length(chunk)) == chunk
    end
    apply_template(fn, zero_template; ensure_zero = false)

    binary_template_8MiB = BinaryTemplate(8*1024^2, offsets(binary_template_4MiB), chunks(binary_template_4MiB))
    apply_template(fn, binary_template_8MiB)
    @test filesize(fn) == 8*1024^2
    zero_template = ZeroTemplate(binary_template_8MiB)
    check_template = apply_template(fn, zero_template; ensure_zero = false)
    @test check_template == binary_template_8MiB

    open(fn, "r+") do f
        seekend(f)
        write(f, zeros(UInt8, 1024))
    end
    apply_template(fn, binary_template_8MiB, truncate = true)
    check_template = apply_template(fn, zero_template; ensure_zero = false, truncate = true)
    @test check_template == binary_template_8MiB
    @test length(binary_template_4MiB.offsets) == 3

    open(fn, "r+") do f
        seekend(f)
        write(f, rand(UInt8, 1024))
    end
    apply_template(fn, binary_template_8MiB, truncate = true, ensure_zero = false)
    check_template = apply_template(fn, zero_template; ensure_zero = false, truncate = true)
    @test check_template == binary_template_8MiB

    @test length(binary_template_4MiB.offsets) == 3
    template_file = tempname(testdir)
    BinaryTemplates.save(binary_template_8MiB, template_file)
    @test BinaryTemplates.load(BinaryTemplate, template_file) == binary_template_8MiB

    open(fn, "r+") do f
        truncate(f, 4096)
    end
    alt_backup_filename = tempname(testdir)
    apply_template(fn, binary_template_8MiB)
    check_template = apply_template(fn, zero_template; ensure_zero = false, backup_filename = alt_backup_filename)
    @test check_template == binary_template_8MiB
    @test binary_template_8MiB == BinaryTemplates.load(BinaryTemplate, alt_backup_filename)

    empty_template = EmptyTemplate()
    @test chunks(empty_template) == Vector{Vector{UInt8}}()
    @test offsets(empty_template) == Int[]
    @test expected_file_size(empty_template) == 0

    check_template = apply_template(fn, empty_template; truncate = true, ensure_zero = false)
    @test filesize(fn) == 0
    @test BinaryTemplates.load_binary_template(BinaryTemplates.backup_filename(fn)) == binary_template_4MiB

    no_chunk_template = EmptyTemplate(1024)
    @test chunks(no_chunk_template) == Vector{Vector{UInt8}}()
    @test offsets(empty_template) == Int[]
    @test expected_file_size(no_chunk_template) == 1024

    check_template = apply_template(fn, no_chunk_template)
    @test filesize(fn) == 1024
    @test BinaryTemplates.isexpectedfilesize(fn, no_chunk_template)

    @test BinaryTemplates.backuptemplate(tempname(testdir), no_chunk_template) == EmptyTemplate()

    # Clean up backup file
    rm(BinaryTemplates.backup_filename(fn))

end
