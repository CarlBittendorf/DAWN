include("../src/main.jl")

function script()
    index = parse(Int, only(ARGS))
    sc = STUDY_CENTERS[index]

    city, username, password, clientsecret, studyuuid, groups, movisensxs_id, movisensxs_key = sc.name,
    sc.username, sc.password, sc.client_secret, sc.studyuuid,
    sc.groups, sc.movisensxs_id, sc.movisensxs_key#

    # connection to database
    db = DuckDB.DB(joinpath("data", city * ".db"))

    # bearer token, which is valid for five minutes
    token = download_interaction_designer_token(username, password, clientsecret)

    ####################################################################################################
    # UPDATE PARTICIPANTS DATABASE
    ####################################################################################################

    # all current participant uuids in the InteractionDesigner
    participantuuids = download_interaction_designer_participants(token, studyuuid)

    # participants in the database
    df_participants = @chain begin
        # contains :Participant, :InteractionDesignerParticipantUUID, :InteractionDesignerGroup and :StudyCenter columns
        read_dataframe(db, "participants")

        # remove inactive uuids
        subset(:InteractionDesignerParticipantUUID => ByRow(x -> x in participantuuids))

        select(Not(:StudyCenter))
    end

    # uuids of participants that are not yet in the database
    new = filter(
        x -> !(x in df_participants.InteractionDesignerParticipantUUID),
        participantuuids
    )

    # download information about new participants
    for participantuuid in new
        json = download_interaction_designer_participant_data(
            token,
            studyuuid,
            participantuuid
        )
        participant = json["pseudonym"]
        group = groups[json["groupId"]]

        # add a new row to the dataframe
        push!(df_participants, [participant, participantuuid, group])
    end

    df_group = @chain begin
        download_interaction_designer_variable_values(
            token,
            studyuuid,
            participantuuids,
            [VARIABLE_GROUP];
            cutofftime = floor(now(), Day) + Hour(5) + Minute(30),
            hoursinpast = 24
        )

        # get the latest group of each available participant
        groupby(:Participant)
        subset(:DateTime => (x -> x .== maximum(x; init = now() - Year(1))))

        transform(:Value => ByRow(x -> GROUPS[x + 1]) => :InteractionDesignerGroup)

        select(:Participant, :InteractionDesignerGroup)

        leftjoin(select(df_participants, Not(:InteractionDesignerGroup)); on = :Participant)
        dropmissing
    end

    df_movisensxs = download_redcap_movisensxs(
        REDCAP_API_TOKEN_1376,
        unique(df_participants.Participant)
    )

    df_participants = @chain df_participants begin
        # replace participants with new groups
        subset(:Participant => ByRow(x -> !(x in df_group.Participant)))
        vcat(df_group)
        sort(:Participant)

        # add :StudyCenter column
        leftjoin(process_redcap_centers(df_movisensxs); on = :Participant)
    end

    # update participant database
    create_or_replace_participants_database(db)

    append_dataframe(db, df_participants, "participants")

    ####################################################################################################
    # UPDATE QUERIES DATABASE
    ####################################################################################################

    df = download_interaction_designer_variable_values(
        token,
        studyuuid,
        participantuuids,
        VARIABLES_DATABASE;
        cutofftime = floor(now(), Day) + Hour(5) + Minute(30),
        hoursinpast = 24
    )

    # add new data to the database
    append_dataframe(db, df, "queries")

    ####################################################################################################
    # MOVISENSXS
    ####################################################################################################

    df_participants = read_dataframe(db, "participants")

    participants = unique(df_participants.Participant)

    df_sensing = DataFrame(
        :Participant => get_mobile_sensing_participants(df_movisensxs),
        :HasMobileSensing => true
    )

    df_running = download_movisensxs_running(df_movisensxs, movisensxs_id, movisensxs_key)

    ####################################################################################################
    # DIPS
    ####################################################################################################

    df_diagnoses = @chain begin
        download_redcap_diagnoses(REDCAP_API_TOKEN_1365, participants)
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

    ####################################################################################################
    # ASSIGNMENTS
    ####################################################################################################

    df_subprojects = @chain begin
        download_redcap_subprojects(REDCAP_API_TOKEN_1401, participants)
        transform(
            [:A06Included, :A06Finalized] => ByRow((i, f) -> i && !f) => :IsA06,
            [:B01Included, :B01Finalized] => ByRow((i, f) -> i && !f) => :IsB01,
            [:B07Included, :B07Finalized] => ByRow((i, f) -> i && !f) => :IsB07
        )
        select(:Participant, :IsA06, :IsB01, :IsB07)
    end

    ####################################################################################################
    # PREPARE DATASET
    ####################################################################################################

    df_data = @chain begin
        # contains :Participant, :DateTime, :Variable and :Value columns
        read_dataframe(db, "queries")

        # remove test accounts
        subset(:Participant => ByRow(x -> !(x in TEST_ACCOUNTS)))

        # replace missing with nothing to distinguish unanswered queries from those that were not asked
        transform(All() .=> ByRow(x -> ismissing(x) ? nothing : x); renamecols = false)

        unstack(:Variable, :Value)

        # entries before 05:30 are considered to belong to the previous day
        transform(:DateTime => ByRow(x -> Time(x) <= Time("05:30") ? Date(x) - Day(1) : Date(x)) => :Date)
        select(Not(:DateTime))

        # add variables that are not yet present in the dataframe
        transform(
            _,
            (All() => ((x...) -> missing) => name
            for name in filter(
                x -> !(x in names(_)),
                unique(getproperty.(VARIABLES_DATABASE, :name))
            ))...
        )

        # parse the values of each variable as its corresponding type
        transform(
            (name => ByRow(x -> !isvalid(x) || typeof(x) == type ? x : parse(type, x))
            for (name, type) in unique(
                getproperty.(VARIABLES_DATABASE, :name) .=>
                getproperty.(VARIABLES_DATABASE, :type)
            ))...;
            renamecols = false
        )

        # reduce to one row per participant per day
        groupby([:Participant, :Date])
        combine(
            [:NegativeEventIntensityMoment, :PercentSocialInteractions] .=>
                (x -> any(!ismissing, x) ? Ref(collect(skipmissing(x))) : missing),
            Not(:NegativeEventIntensityMoment, :PercentSocialInteractions) .=>
                (x -> coalesce(x...));
            renamecols = false
        )

        transform(
            [:PHQ1, :PHQ2, :PHQ3, :PHQ4, :PHQ5, :PHQ6, :PHQ7, :PHQ8, :PHQ9] => ByRow((x...) -> any(isnothing, x) ? missing : +(x...)) => :PHQ9SumScore,
            [:ASRM1, :ASRM2, :ASRM3, :ASRM4, :ASRM5] => ByRow((x...) -> any(isnothing, x) ? missing : +(x...)) => :ASRM5SumScore
        )

        # set missing PHQ-9 and ASRM-5 sum scores to 0 for all rows where ChronoRecord is not missing
        transform(
            [:ChronoRecord, :PHQ9SumScore] => ByRow((c, s) -> isvalid(c) && ismissing(s) ? 0 : s) => :PHQ9SumScore,
            [:ChronoRecord, :ASRM5SumScore] => ByRow((c, s) -> isvalid(c) && ismissing(s) ? 0 : s) => :ASRM5SumScore
        )

        # add :City column
        transform(All() => ((x...) -> city) => :City)

        # add :InteractionDesignerParticipantUUID, :InteractionDesignerGroup and :StudyCenter columns
        leftjoin(df_participants; on = :Participant)
        dropmissing(:InteractionDesignerGroup)

        # add :HasMobileSensing and :MobileSensingRunning columns
        leftjoin(df_sensing; on = :Participant)
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

        # add :IsA06, :IsB01 and :IsB07 columns
        leftjoin(df_subprojects; on = :Participant)
        transform(
            [:IsA06, :IsB01, :IsB07] .=> ByRow(x -> !ismissing(x) && x);
            renamecols = false
        )

        sort([:Participant, :Date])
    end

    ####################################################################################################
    # DETECT SIGNALS
    ####################################################################################################

    signals = determine_signals(df_data, SIGNALS; cutoff = Date(now()) - Day(1))
    receivers = receiver.(signals)

    for email in unique(receivers)
        strings = @chain signals begin
            filter(x -> receiver(x) == email, _)
            @. format_signal
        end

        if !isnothing(email)
            send_signals_email(
                EMAIL_CREDENTIALS, [email, EMAIL_ADDITIONAL_RECEIVERS...], city, strings)
        else
            send_signals_email(EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER, city, strings)
        end
    end

    upload_redcap_signals(REDCAP_API_TOKEN_1308, signals)
end

run_script(script, EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER)