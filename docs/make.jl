using BinaryTemplates
using Documenter

DocMeta.setdocmeta!(BinaryTemplates, :DocTestSetup, :(using BinaryTemplates); recursive=true)

makedocs(;
    modules=[BinaryTemplates],
    authors="Mark Kittisopikul <kittisopikulm@janelia.hhmi.org> and contributors",
    repo="https://github.com/mkitti/BinaryTemplates.jl/blob/{commit}{path}#{line}",
    sitename="BinaryTemplates.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://mkitti.github.io/BinaryTemplates.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/mkitti/BinaryTemplates.jl",
    devbranch="main",
)
