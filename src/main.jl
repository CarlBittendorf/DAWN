using Pkg

if isfile("Project.toml") && isfile("Manifest.toml")
    Pkg.activate(".")
    Pkg.instantiate()
end

include("types.jl")
include("../secrets.jl")

using Chain, DataFrames, MiniLoggers, DuckDB, PyCall, HTTP, JSON, CSV, XML, ZipFile,
      Hyperscript
using Dates, Statistics

@pyinclude("src/email.py")

include("utils.jl")
include("db.jl")
include("spc.jl")
include("signals.jl")
include("constants.jl")
include("interaction_designer.jl")
include("movisensxs.jl")
include("redcap.jl")
include("email.jl")
include("logging.jl")