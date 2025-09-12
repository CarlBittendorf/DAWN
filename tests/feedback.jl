include("../src/main.jl")

sc = STUDY_CENTERS[1]

city, username, password, clientsecret, studyuuid = sc.name,
sc.username, sc.password, sc.client_secret, sc.studyuuid

# connection to database
db = DuckDB.DB(joinpath("data", city * ".db"))

df_participants = read_dataframe(db, "participants")

cutoff = Date(now()) - Day(1)

# determine all participants who just finished one or two weeks of intense sampling
participantuuids = @chain db begin
    read_dataframe("data")
    leftjoin(df_participants; on = :Participant)
    dropmissing(:InteractionDesignerParticipantUUID)

    subset(:Date => (x -> x .<= cutoff))

    groupby(:Participant)
    subset(
        :Date => (x -> x .> cutoff - Day(14) .&& x .<= cutoff),
        :EventNegative => ByRow(!ismissing);
        ungroup = false
    )
    subset(
        :Date => (x -> maximum(x) == cutoff),
        :EventNegative => (x -> length(x) in [5, 7, 14])
    )

    getproperty(:InteractionDesignerParticipantUUID)
    unique
end

# bearer token, which is valid for five minutes
token = download_interaction_designer_token(username, password, clientsecret)

feedback = @chain token begin
    download_interaction_designer_variable_values(
        studyuuid,
        participantuuids,
        B01_INTENSE_SAMPLING_VARIABLE_UUIDS;
        cutofftime = make_cutoff(x = DateTime(cutoff + Day(1))),
        hoursinpast = 168
    )
    make_feedback_B01_html(df_participants, city)
end

send_feedback_email(EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER, feedback)

feedback = @chain db begin
    read_dataframe("data")
    leftjoin(df_participants; on = :Participant)
    dropmissing(:InteractionDesignerParticipantUUID)

    subset(:Date => (x -> x .<= cutoff))

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

send_feedback_email(EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER, feedback)