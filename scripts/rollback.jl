include("../src/main.jl")

# remove the previous day from the database
for sc in STUDY_CENTERS
    city = sc.name

    # connection to database
    db = DuckDB.DB(joinpath("data", city * ".db"))

    df_participants = read_dataframe(db, "participants")

    df_data = @chain db begin
        read_dataframe("data")
        subset(:Date => ByRow(x -> x < Date(now()) - Day(1)))
        transform(
            [:EventNegative, :SocialInteractions] .=>
                ByRow(x -> ismissing(x) ? x : collect(skipmissing(x)));
            renamecols = false
        )
        sort([:Participant, :Date])
    end

    # remove database
    rm(joinpath("data", city * ".db"); force = true)
    rm(joinpath("data", city * ".db.wal"); force = true)

    # connection to database
    db = DuckDB.DB(joinpath("data", city * ".db"))

    DBInterface.execute(
        db,
        """
        CREATE TABLE IF NOT EXISTS participants (
            Participant STRING,
            InteractionDesignerParticipantUUID STRING,
            InteractionDesignerGroup STRING
        )
        """
    )

    DBInterface.execute(
        db,
        """
        CREATE TABLE IF NOT EXISTS data (
            Participant STRING,
            Date DATE,
            ChronoRecord INTEGER,
            PHQ9TotalScore INTEGER,
            ASRM5TotalScore INTEGER,
            FallAsleep TIME,
            WakeUp TIME,
            SleepQuality INTEGER,
            SocialInteractionMore INTEGER,
            Influence INTEGER,
            Medication STRING,
            SubstanceMore INTEGER,
            Expectation INTEGER,
            IsA04 BOOLEAN,
            EventNegative INTEGER[],
            TrainingProblems BOOLEAN,
            TrainingQuestions BOOLEAN,
            SocialInteractions INTEGER[],
            SocialContact BOOLEAN,
            ExerciseSuccessful INTEGER
        )
        """
    )

    # fill database again
    append_dataframe(db, df_participants, "participants")
    append_dataframe(db, df_data, "data")
end