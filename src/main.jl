using Pkg

if isfile("Project.toml") && isfile("Manifest.toml")
    Pkg.activate(".")
    Pkg.instantiate()
end

include("types.jl")
include("../secrets.jl")

using Chain, DataFrames, MiniLoggers, DuckDB, PyCall, HTTP, JSON, CSV, XML, ZipFile,
      Hyperscript, AlgebraOfGraphics, CairoMakie
using Dates, Statistics, Printf

@pyinclude("src/email.py")

include("utils.jl")
include("database.jl")
include("signals.jl")
include("variables.jl")
include("interaction_designer.jl")
include("movisensxs.jl")
include("redcap.jl")
include("email.jl")
include("logging.jl")

set_aog_theme!()

const PATIENT_GROUPS = [
    "S01", "B01", "C01 Emotion", "C01 Cognition", "B05/C03 PSAT", "B05/C03 Mindfulness"]

const GROUPS = [PATIENT_GROUPS..., "Partner B05/C03 PSAT", "Partner B05/C03 Mindfulness"]

const PRIMARY_COLOR = colorant"#4C90B5"
const SECONDARY_COLOR = colorant"#A4C6D9"
const CENTRAL_PROJECTS_COLOR = colorant"#878786"
const DOMAIN_A_COLOR = colorant"#CFB23F"
const DOMAIN_B_COLOR = colorant"#BF3E39"
const DOMAIN_C_COLOR = colorant"#02738D"

const PALETTE = [PRIMARY_COLOR, SECONDARY_COLOR, DOMAIN_A_COLOR, DOMAIN_B_COLOR]