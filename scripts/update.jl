include("../src/main.jl")

function script()
    index = parse(Int, only(ARGS))
    sc = STUDY_CENTERS[index]

    city, username, password, clientsecret, studyuuid, groups, movisensxs_id, movisensxs_key = sc.name,
    sc.username, sc.password, sc.client_secret, sc.studyuuid,
    sc.groups, sc.movisensxs_id, sc.movisensxs_key

    # connection to database
    db = DuckDB.DB(joinpath("data", city * ".db"))

    update_database(DatabaseParticipants, db, username, password, clientsecret, studyuuid)
    update_database(DatabaseMovisensXS, db)
    update_database(DatabaseSensingRunning, db, movisensxs_id, movisensxs_key)
    update_database(DatabaseDiagnoses, db)
    update_database(DatabaseSubprojects, db)
    update_database(DatabaseQueries, db, username, password, clientsecret, studyuuid)
end

run_script(script, EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER)