include("../src/main.jl")

sc = STUDY_CENTERS[1]

city = sc.name

# connection to database
db = DuckDB.DB(joinpath("data", city * ".db"))

df_participants = read_dataframe(db, "participants")
df_data = read_dataframe(db, "data")