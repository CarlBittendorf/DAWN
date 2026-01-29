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

const CODES_DEPRESSION = [
    # schizoaffective (depressive)
    "F25.1", "295.70",

    # bipolar (depressive)
    "31.3", "31.4", "31.5", "31.6", "296.5",

    # depression (first time)
    "32.0", "32.1", "32.2", "32.3", "32.8", "32.9", "296.21", "296.22", "296.23", "296.24",

    # depression (recurrent)
    "33.0", "33.1", "33.2", "33.3", "33.8", "33.9", "296.31", "296.32", "296.33", "296.34"
]

const CODES_MANIA = [
    # schizoaffective (manic)
    "25.0", "295.70",

    # mania
    "30.0", "30.1", "30.2", "30.8", "30.9",

    # bipolar (manic)
    "31.0", "31.1", "31.2", "296.0"
]