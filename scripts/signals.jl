include("../src/main.jl")

function script()
    index = parse(Int, only(ARGS))
    sc = STUDY_CENTERS[index]

    city, username, password, clientsecret, studyuuid, groups, movisens_id, movisens_key = sc.name,
    sc.username, sc.password, sc.client_secret, sc.studyuuid,
    sc.groups, sc.movisens_id, sc.movisens_key

    # connection to database
    db = DuckDB.DB(joinpath("data", city * ".db"))

    # participants in the database
    df_participants = read_dataframe(db, "participants")

    # bearer token, which is valid for five minutes
    token = download_interaction_designer_token(username, password, clientsecret)

    # all current participant uuids
    participantuuids = download_interaction_designer_participants(token, studyuuid)

    # uuids of participants that are not yet in the database
    participantuuids_new = filter(
        x -> !(x in df_participants.InteractionDesignerParticipantUUID), participantuuids)

    # download information about new participants
    df_new = DataFrame(
        :Participant => String[],
        :InteractionDesignerParticipantUUID => String[],
        :InteractionDesignerGroup => String[]
    )

    for participantuuid in participantuuids_new
        json = download_interaction_designer_participant_data(
            token,
            studyuuid,
            participantuuid
        )
        participant = json["pseudonym"]
        groupuuid = groups[json["groupId"]]

        # add a new row to the dataframe
        push!(df_new, [participant, participantuuid, groupuuid])
    end

    # add new participants to the database
    append_dataframe(db, df_new, "participants")

    df_participants = read_dataframe(db, "participants")

    # download data for the previous day, 100 participants at a time
    chunks = chunk(length(participantuuids), 100)

    df = @chain begin
        vcat((
            @chain token begin
                download_interaction_designer_variable_values(
                    studyuuid,
                    participantuuids[range],
                    getfield.(INTERACTION_DESIGNER_VARIABLES, :uuid)
                )
                variable_values_to_dataframe(INTERACTION_DESIGNER_VARIABLES)
            end
        for range in chunks
        )...)

        transform(
            [:PHQ2_1, :PHQ2_2, :PHQ9_3, :PHQ9_4, :PHQ9_5, :PHQ9_6, :PHQ9_7, :PHQ9_8, :PHQ9_9] => ByRow(+) => :PHQ9TotalScore,
            [:ASRM1, :ASRM2, :ASRM3, :ASRM4, :ASRM5] => ByRow(+) => :ASRM5TotalScore,
            [:TrainingSuccess, :CoupleDialogSuccessful, :BodyScanSuccessful, :BreathingExerciseSuccessful, :CompassionMeditationSuccessful] => ByRow(coalesce) => :ExerciseSuccessful,
            :TrainingProblems => ByRow(x -> x != 0),
            :TrainingQuestions => ByRow(x -> x == 1);
            renamecols = false
        )

        # set PHQ-9 and ASRM-5 sum scores to 0 for all rows where ChronoRecord is not missing
        transform(
            [:ChronoRecord, :PHQ9TotalScore] => ByRow((c, s) -> !ismissing(c) && ismissing(s) ? 0 : s) => :PHQ9TotalScore,
            [:ChronoRecord, :ASRM5TotalScore] => ByRow((c, s) -> !ismissing(c) && ismissing(s) ? 0 : s) => :ASRM5TotalScore
        )
        select(DATABASE_VARIABLES)
    end

    # add new data to the database
    append_dataframe(db, df, "data")

    df_participants = read_dataframe(db, "participants")

    # interaction designer ids
    participants = unique(df_participants.Participant)

    # mapping from interaction designer ids to movisensxs ids
    df_movisensxs = download_redcap_participants(REDCAP_API_TOKEN_1376, participants)

    # determine which participants have the movisensxs app currently installed
    participants_sensing = @chain df_movisensxs begin
        # consider only the most recent entry for each participant
        groupby(:Participant)
        subset(:Instance => (x -> x .== maximum(x)))

        # select only participants with a movisensxs id
        subset(:MovisensXSParticipantID => ByRow(!isequal("")))
        getproperty(:Participant)
    end

    # check if mobile sensing is running
    df_running = vcat((
        begin
            ids = @chain df_movisensxs begin
                subset(
                    :Participant => ByRow(isequal(participant)),
                    :MovisensXSParticipantID => ByRow(!isequal(""))
                )
                getproperty(:MovisensXSParticipantID)
            end

            df = DataFrame()

            for id in ids
                result = download_movisensxs_unisens(movisens_id, movisens_key, id)

                if !isnothing(result)
                    df = vcat(
                        df,
                        DataFrame(
                            :Participant => participant,
                            :Date => get_mobile_sensing_dates(result),
                            :MobileSensingRunning => true
                        )
                    )
                end
            end

            if nrow(df) > 0
                # remove duplicate dates
                @chain df begin
                    groupby([:Participant, :Date])
                    combine(All() .=> first; renamecols = false)
                end
            else
                df
            end
        end
    for participant in participants_sensing
    )...)

    df_diagnoses = @chain REDCAP_API_TOKEN_1365 begin
        download_redcap_diagnoses(participants)
        sort([:Participant, :DIPSDate])
        transform(:DIPSDate => ByRow(identity) => :Date)
        fill_dates
        transform(
            [:DIPSDate, :DepressiveEpisode, :ManicEpisode] .=> fill_down;
            renamecols = false
        )
    end

    # workaround to avoid SSL errors
    sleep(10)

    df_a06 = @chain REDCAP_API_TOKEN_1401 begin
        download_redcap_a06(participants)
        select(:Participant, :IsA06)
    end

    df_data = @chain db begin
        read_dataframe("data")

        # add :HasMobileSensing and :MobileSensingRunning columns
        leftjoin(
            DataFrame(
                :Participant => participants_sensing,
                :HasMobileSensing => true
            );
            on = :Participant
        )
        leftjoin(df_running; on = [:Participant, :Date])
        transform(
            [:HasMobileSensing, :MobileSensingRunning] .=> ByRow(!ismissing);
            renamecols = false
        )

        # add :DIPSDate, :DepressiveEpisode and :ManicEpisode columns
        leftjoin(df_diagnoses; on = [:Participant, :Date])
        transform(
            [:DepressiveEpisode, :ManicEpisode] .=> ByRow(x -> !ismissing(x) && x);
            renamecols = false
        )

        # add :IsA06 column
        leftjoin(df_a06; on = :Participant)
        transform(:IsA06 => ByRow(!ismissing); renamecols = false)

        sort([:Participant, :Date])
    end

    df_signals = determine_signals(df_data, df_participants, SIGNALS)

    @chain df_movisensxs begin
        groupby(:Participant)
        combine(All() .=> (x -> coalesce(x...)); renamecols = false)

        rightjoin(df_signals; on = :Participant)
        transform(All() => ((x...) -> city) => :City)
        signals_to_strings(SIGNALS)

        send_signals_email(EMAIL_CREDENTIALS, EMAIL_SIGNALS_RECEIVERS, _)
    end

    upload_redcap_signals(df_signals, REDCAP_API_TOKEN_1308, SIGNALS)
end

run_script(script, EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER)