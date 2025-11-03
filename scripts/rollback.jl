include("../src/main.jl")

# remove the previous day from the database
for sc in STUDY_CENTERS
    city = sc.name

    # connection to database
    db = DuckDB.DB(joinpath("data", city * ".db"))

    df_participants = read_dataframe(db, "participants")

    df_data = @chain begin
        read_dataframe(db, "queries")
        subset(:DateTime => ByRow(x -> x < floor(now(), Day) - Day(1) + Hour(5) + Minute(30)))
        sort([:Participant, :DateTime])
    end

    # remove database
    rm(joinpath("data", city * ".db"); force = true)
    rm(joinpath("data", city * ".db.wal"); force = true)

    # connection to database
    db = DuckDB.DB(joinpath("data", city * ".db"))

    create_or_replace_participants_database(db)
    create_or_replace_queries_database(db)

    # fill database again
    append_dataframe(db, df_participants, "participants")
    append_dataframe(db, df_data, "queries")
end