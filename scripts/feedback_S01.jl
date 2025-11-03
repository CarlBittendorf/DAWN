include("../src/main.jl")

function script()
    index = parse(Int, only(ARGS))
    sc = STUDY_CENTERS[index]

    city = sc.name

    cutoff = Date(now()) - Day(1)

    # connection to database
    db = DuckDB.DB(joinpath("data", city * ".db"))

    df = @chain begin
        read_dataframe(db, "queries")
        subset(:Variable => ByRow(isequal("ChronoRecord")))

        # entries before 05:30 are considered to belong to the previous day
        transform(
            :DateTime => ByRow(x -> Time(x) <= Time("05:30") ? Date(x) - Day(1) : Date(x)) => :Date;
            renamecols = false
        )

        groupby([:Participant, :Date])
        combine(:Value => (x -> coalesce(x...)); renamecols = false)

        # determine all participants who just finished a multiple of 180 days
        # and have at least one entry within the last 180 days
        groupby(:Participant)
        subset(
            :Date => (x -> (Dates.value(cutoff - minimum(x; init = cutoff))) % 180 == 0),
            :Date => (x -> any(d -> d > cutoff - Day(180), x)),
            :Date => ByRow(x -> x < cutoff);
            ungroup = false
        )
        transform(
            :Date => (x -> Dates.value.(x .- minimum(x; init = cutoff)) .+ 1) => :Day;
            ungroup = false
        )
        lastdays(180, cutoff - Day(1))

        transform(:Day => ByRow(x -> ceil(Int, x / 30)) => :Block)

        groupby([:Participant, :Block])
        combine(
            :Date => (x -> minimum(x; init = cutoff)) => :Start,
            :Date => (x -> maximum(x; init = cutoff - Day(180))) => :End,
            :Value => (x -> format_compliance(count(!ismissing, x) / 30)) => :Compliance
        )

        select(:Participant, :Block, :Start, :End, :Compliance)
    end

    if nrow(df) > 0
        send_feedback_email(
            EMAIL_CREDENTIALS,
            EMAIL_FEEDBACK_S01[city],
            "S01",
            Hyperscript.Node[make_table(df)]
        )
    end
end

run_script(script, EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER)