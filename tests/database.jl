include("../src/main.jl")

study_center = STUDY_CENTERS[1]

city = study_center.name

# connection to database
db = DuckDB.DB(joinpath("data", city * ".db"))

df_participants = read_database(DatabaseParticipants, db)
df_data = read_database(DatabaseQueries, db)
df_diagnoses = read_database(DatabaseDiagnoses, db)