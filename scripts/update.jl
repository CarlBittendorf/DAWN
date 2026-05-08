include("../src/main.jl")

function script()
    # read the study center index from command-line arguments
    index = parse(Int, only(ARGS))

    # select the study center based on the provided index
    study_center = STUDY_CENTERS[index]

    # extract the city name from the study center metadata
    city = study_center.name

    # connection to database
    db = DuckDB.DB(joinpath("data", city * ".db"))

    update_database(DatabaseParticipants, db, study_center)
    update_database(DatabaseMovisensXS, db)
    update_database(DatabaseSensingRunning, db, study_center)
    update_database(DatabaseDiagnoses, db)
    update_database(DatabaseSubprojects, db)
    update_database(DatabaseQueries, db, study_center)
end

run_script(script, EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER)