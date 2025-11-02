
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
    connection = DBInterface.connect(db)

    DBInterface.execute(connection, "SELECT * FROM " * table) |> DataFrame
end