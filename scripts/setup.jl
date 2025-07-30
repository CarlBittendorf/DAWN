include("../src/main.jl")

for sc in STUDY_CENTERS
    city, username, password, clientsecret, studyuuid = sc.name,
    sc.username, sc.password, sc.client_secret, sc.studyuuid

    # remove database if it exists
    rm(joinpath("data", city * ".db"); force = true)
    rm(joinpath("data", city * ".db.wal"); force = true)

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

    # fill database
    df = download_interaction_designer_dataframe(
        username, password, clientsecret, studyuuid)

    append_dataframe(db, process_interaction_designer_participants(df), "participants")

    append_dataframe(
        db,
        process_interaction_designer_data(
            df, INTERACTION_DESIGNER_VARIABLES,
            DATABASE_VARIABLES
        ),
        "data"
    )
end