using Pkg, Dates

if isfile("Project.toml") && isfile("Manifest.toml")
    Pkg.activate(".")
    Pkg.instantiate()
end

include("types.jl")
include("../secrets.jl")

using Chain, DataFrames, MiniLoggers, DuckDB, PyCall, HTTP, JSON, CSV, XML, ZipFile,
      TimeZones, Hyperscript, AlgebraOfGraphics, CairoMakie
using Statistics, Printf, InteractiveUtils

@pyinclude("src/email.py")

include("utils.jl")
include("database.jl")
include("signals.jl")
include("feedback.jl")
include("constants.jl")
include("interaction_designer.jl")
include("movisensxs.jl")
include("redcap.jl")
include("preparation.jl")
include("update.jl")
include("metadata.jl")
include("email.jl")
include("logging.jl")

set_aog_theme!()