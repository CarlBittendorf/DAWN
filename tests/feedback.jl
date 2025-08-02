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
        :Date => (x -> x .> cutoff - Day(14)),
        :EventNegative => ByRow(!ismissing);
        ungroup = false
    )
    subset(:EventNegative => (x -> length(x) in [7, 14]))

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
        cutofftime = make_cutoff(hour = 7, minute = 0),
        hoursinpast = 168
    )
    make_feedback_strings(df_participants, city)
end

send_feedback_email(EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER, feedback)