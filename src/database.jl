
function create_or_replace_participants_database(db)
    DBInterface.execute(
        db,
        """
        CREATE OR REPLACE TABLE participants (
            Participant STRING,
            InteractionDesignerParticipantUUID STRING,
            InteractionDesignerGroup STRING,
            StudyCenter STRING
        )
        """
    )
end

function create_or_replace_queries_database(db)
    DBInterface.execute(
        db,
        """
        CREATE OR REPLACE TABLE queries (
            Participant STRING,
            DateTime DATETIME,
            Variable STRING,
            Value STRING
        )
        """
    )
end

function create_or_replace_movisensxs_database(db)
    DBInterface.execute(
        db,
        """
        CREATE OR REPLACE TABLE movisensxs (
            Participant STRING,
            MovisensXSParticipantID STRING,
            Instance INTEGER,
            AssignmentDate DATE
        )
        """
    )
end

function create_or_replace_running_database(db)
    DBInterface.execute(
        db,
        """
        CREATE OR REPLACE TABLE running (
            Participant STRING,
            Date DATE
        )
        """
    )
end

function create_or_replace_diagnoses_database(db)
    DBInterface.execute(
        db,
        """
        CREATE OR REPLACE TABLE diagnoses (
            Participant STRING,
            DIPSDate DATE,
            DepressiveEpisode BOOLEAN,
            ManicEpisode BOOLEAN
        )
        """
    )
end

function create_or_replace_subprojects_database(db)
    DBInterface.execute(
        db,
        """
        CREATE OR REPLACE TABLE subprojects (
            Participant STRING,
            IsA06 BOOLEAN,
            IsB01 BOOLEAN,
            IsB03 BOOLEAN,
            IsB05 BOOLEAN,
            IsB07 BOOLEAN,
            IsC01 BOOLEAN,
            IsC02 BOOLEAN,
            IsC03 BOOLEAN,
            IsC04 BOOLEAN
        )
        """
    )
end

function append_dataframe(db, df, table)
    appender = DuckDB.Appender(db, table)

    for row in eachrow(df)
        for value in row
            DuckDB.append(appender, value)
        end

        DuckDB.end_row(appender)
    end

    DuckDB.close(appender)
end

function read_dataframe(db, table)
    @chain begin
        DBInterface.connect(db)
        DBInterface.execute("SELECT * FROM " * table)
        DataFrame
    end
end