include("../src/main.jl")

function script()
    index = parse(Int, only(ARGS))
    sc = STUDY_CENTERS[index]

    city, username, password, clientsecret, studyuuid = sc.name,
    sc.username, sc.password, sc.client_secret, sc.studyuuid

    # connection to database
    db = DuckDB.DB(joinpath("data", city * ".db"))

    df_participants = read_dataframe(db, "participants")

    cutoff = Date(now()) - Day(2)

    # determine all participants who finished one or two weeks of B01 intense sampling two days ago
    participantuuids = @chain db begin
        read_dataframe("data")
        leftjoin(df_participants; on = :Participant)
        dropmissing(:InteractionDesignerParticipantUUID)

        groupby(:Participant)
        subset(
            :Date => (x -> x .> cutoff - Day(14) .&& x .<= cutoff),
            :EventNegative => ByRow(!ismissing);
            ungroup = false
        )
        subset(
            :Date => (x -> maximum(x; init = cutoff - Day(1)) == cutoff),
            :EventNegative => (x -> length(x) in [5, 7, 14])
        )

        getproperty(:InteractionDesignerParticipantUUID)
        unique
    end

    if !isempty(participantuuids)
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

        send_feedback_email(EMAIL_CREDENTIALS, EMAIL_FEEDBACK_B01_RECEIVERS[city], feedback)
    end
end

run_script(script, EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER)