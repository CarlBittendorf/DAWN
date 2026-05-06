include("../src/main.jl")

# remove the previous day from the database
for sc in STUDY_CENTERS
    city = sc.name

    # connection to database
    db = DuckDB.DB(joinpath("data", city * ".db"))

    df_participants = read_database(DatabaseParticipants, db)

    df_data = @chain begin
        read_database(DatabaseQueries, db)

        subset(:DateTime => ByRow(x -> x < floor(now(), Day) - Day(1) + Hour(5) + Minute(30)))
        sort([:Participant, :DateTime])
    end

    # remove database
    rm(joinpath("data", city * ".db"); force = true)
    rm(joinpath("data", city * ".db.wal"); force = true)

    # connection to database
    db = DuckDB.DB(joinpath("data", city * ".db"))

    # fill database again
    create_or_replace_database(DatabaseParticipants, db, df_participants)
    create_or_replace_database(DatabaseQueries, db, df_data)
end