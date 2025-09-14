include("../src/main.jl")

function script()
    index = parse(Int, only(ARGS))
    sc = STUDY_CENTERS[index]

    city = sc.name

    # connection to database
    db = DuckDB.DB(joinpath("data", city * ".db"))

    df_participants = read_dataframe(db, "participants")

    cutoff = Date(now()) - Day(1)

    feedback = @chain db begin
        read_dataframe("data")
        leftjoin(df_participants; on = :Participant)
        dropmissing(:InteractionDesignerParticipantUUID)

        # determine all participants who just finished a multiple of 180 days
        # and have at least one entry within the last 180 days
        groupby(:Participant)
        subset(
            :Date => (x -> (Dates.value(cutoff - minimum(x)) + 1) % 180 == 0),
            :Date => (x -> any(d -> d > cutoff - Day(180), x));
            ungroup = false
        )
        transform(
            :Date => (x -> Dates.value.(x .- minimum(x; init = cutoff)) .+ 1) => :Day;
            ungroup = false
        )
        lastdays(180, cutoff)

        transform(:Day => ByRow(x -> ceil(Int, x / 30)) => :Block)

        groupby([:Participant, :Block])
        combine(
            :Date => (x -> minimum(x; init = cutoff)) => :Start,
            :Date => (x -> maximum(x; init = cutoff - Day(180))) => :End,
            :ChronoRecord => (x -> round(count(!ismissing, x) / 30 * 100; digits = 2)) => :Compliance
        )

        make_feedback_S01_html(df_participants, city)
    end

    if !isempty(feedback)
        send_feedback_email(EMAIL_CREDENTIALS, EMAIL_FEEDBACK_S01_RECEIVERS[city], feedback)
    end
end

run_script(script, EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER)