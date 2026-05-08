
# 1. Interface Documentation
# 2. Generic Definitions
# 3. Concrete Implementations
# 4. High-level Functions

####################################################################################################
# INTERFACE DOCUMENTATION
####################################################################################################

# This code provides a typed interface to multiple local databases backed by DuckDB.

# Each logical database is represented by a concrete Julia type that is a subtype of
# `AbstractDatabase` and must implement the following function:

# columns(::Type{<:AbstractDatabase})

####################################################################################################
# GENERIC DEFINITIONS
####################################################################################################

abstract type AbstractDatabase end

"""
    columns(::Type{<:AbstractDatabase}) -> Vector{String}


Return the SQL column definitions for a database table.

This function defines the schema associated with a concrete subtype of `AbstractDatabase`.
Each element of the returned vector must be a valid SQL column definition of the form:

    "ColumnName TYPE"


For example:

    [
        "Participant STRING",
        "Date DATE",
        "Value FLOAT"
    ]


The order of columns determines the table layout in DuckDB and the order in which values are
appended when inserting rows. Column names must match the column names of DataFrames used with
`append_database`.
"""
function columns end

####################################################################################################
# CONCRETE IMPLEMENTATIONS
####################################################################################################

struct DatabaseParticipants <: AbstractDatabase end
struct DatabaseQueries <: AbstractDatabase end
struct DatabaseMovisensXS <: AbstractDatabase end
struct DatabaseSensingRunning <: AbstractDatabase end
struct DatabaseDiagnoses <: AbstractDatabase end
struct DatabaseSubprojects <: AbstractDatabase end
struct DatabaseRemissions <: AbstractDatabase end

function columns(::Type{DatabaseParticipants})
    [
        "Participant STRING",
        "InteractionDesignerParticipantUUID STRING",
        "InteractionDesignerGroup STRING",
        "StudyCenter STRING"
    ]
end

function columns(::Type{DatabaseQueries})
    [
        "Participant STRING",
        "DateTime DATETIME",
        "Variable STRING",
        "Value STRING"
    ]
end

function columns(::Type{DatabaseMovisensXS})
    [
        "Participant STRING",
        "MovisensXSParticipantID STRING",
        "Instance INTEGER",
        "AssignmentDate DATE"
    ]
end

function columns(::Type{DatabaseSensingRunning})
    [
        "Participant STRING",
        "Date DATE"
    ]
end

function columns(::Type{DatabaseDiagnoses})
    [
        "Participant STRING",
        "DIPSDate DATE",
        "DIPSOrigin STRING",
        "DepressiveEpisode BOOLEAN",
        "ManicEpisode BOOLEAN"
    ]
end

function columns(::Type{DatabaseSubprojects})
    [
        "Participant STRING",
        "A06 BOOLEAN",
        "B01 BOOLEAN",
        "B03 BOOLEAN",
        "B05 BOOLEAN",
        "B07 BOOLEAN",
        "C01 BOOLEAN",
        "C02 BOOLEAN",
        "C03 BOOLEAN",
        "C04 BOOLEAN"
    ]
end

function columns(::Type{DatabaseRemissions})
    [
        "Participant STRING",
        "SymptomRemissionDate DATE"
    ]
end

####################################################################################################
# HIGH-LEVEL FUNCTIONS
####################################################################################################

"""
    append_database(T::Type{<:AbstractDatabase}, db, df)

Append the contents of a DataFrame to an existing database table.

Rows from `df` are appended sequentially to the DuckDB table identified by `T`.
The column order of `df` must exactly match the order returned by `columns(T)`.
"""
function append_database(T::Type{<:AbstractDatabase}, db, df)
    appender = DuckDB.Appender(db, string(T))

    for row in eachrow(df)
        for value in row
            DuckDB.append(appender, value)
        end

        DuckDB.end_row(appender)
    end

    DuckDB.close(appender)
end

"""
    read_database(T::Type{<:AbstractDatabase}, db) -> DataFrame

Read an entire database table into a Julia `DataFrame`.
"""
function read_database(T::Type{<:AbstractDatabase}, db)
    @chain begin
        DBInterface.connect(db)
        DBInterface.execute("SELECT * FROM " * string(T))
        DataFrame
    end
end

"""
    create_or_replace_database(T::Type{<:AbstractDatabase}, db)
    create_or_replace_database(T::Type{<:AbstractDatabase}, db, df)

Create or replace a database table associated with the database type `T`.

The table schema is derived from `columns(T)`. If a table with the same name already exists,
it will be dropped and recreated. If provided, appends the contents of the data frame `df`.
"""
function create_or_replace_database(T::Type{<:AbstractDatabase}, db)
    DBInterface.execute(
        db,
        """
        CREATE OR REPLACE TABLE $(string(T)) (
            $(join(columns(T), ",\n"))
        )
        """
    )
end

function create_or_replace_database(T::Type{<:AbstractDatabase}, db, df)
    create_or_replace_database(T, db)
    append_database(T, db, df)
end