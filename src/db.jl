
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