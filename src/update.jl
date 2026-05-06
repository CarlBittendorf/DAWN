
function update_database(
        ::Type{DatabaseParticipants}, db, username, password, clientsecret, studyuuid, groups)
    bearer_token = download_interaction_designer_token(username, password, clientsecret)

    # all current participant uuids in the InteractionDesigner
    participantuuids = download_interaction_designer_participants(bearer_token, studyuuid)

    # participants in the database
    df_participants = @chain begin
        # contains :Participant, :InteractionDesignerParticipantUUID, :InteractionDesignerGroup and :StudyCenter columns
        read_database(DatabaseParticipants, db)

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
            bearer_token,
            studyuuid,
            participantuuid
        )
        participant = json["pseudonym"]
        group = groups[json["groupId"]]

        # add a new row to the dataframe
        push!(df_participants, [participant, participantuuid, group])
    end

    # account for group changes
    df_group = @chain begin
        download_interaction_designer_variable_values(
            bearer_token,
            studyuuid,
            participantuuids,
            [VARIABLE_GROUP];
            cutofftime = floor(now(), Day) + Hour(3) + Minute(30),
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

    participants = unique(df_participants.Participant)

    df_movisensxs = download_and_process_redcap(REDCapMovisensXS, participants)

    df_centers = @chain df_movisensxs begin
        groupby(:Participant)
        transform(:StudyCenter => (x -> coalesce(reverse(x)...)); renamecols = false)

        dropmissing(:StudyCenter)

        # consider only the most recent entry for each participant
        groupby(:Participant)
        subset(:Instance => (x -> x .== maximum(x)))

        select(:Participant, :StudyCenter)
    end

    df_participants = @chain df_participants begin
        # replace participants that belong to another group now
        subset(:Participant => ByRow(x -> !(x in df_group.Participant)))
        vcat(df_group)
        sort(:Participant)

        # add :StudyCenter column
        leftjoin(df_centers; on = :Participant)
    end

    create_or_replace_database(DatabaseParticipants, db, df_participants)
end

function update_database(
        ::Type{DatabaseQueries}, db, username, password, clientsecret, studyuuid)
    df_participants = read_database(DatabaseParticipants, db)
    participantuuids = unique(df_participants.InteractionDesignerParticipantUUID)

    bearer_token = download_interaction_designer_token(username, password, clientsecret)

    df_queries = @chain begin
        download_interaction_designer_variable_values(
            bearer_token,
            studyuuid,
            participantuuids,
            VARIABLES_DATABASE;
            cutofftime = floor(now(), Day) + Hour(5) + Minute(30),
            hoursinpast = 24
        )

        vcat(read_dataframe(DatabaseQueries, db), _)
        unique
    end

    create_or_replace_database(DatabaseQueries, db, df_queries)
end

function update_database(::Type{DatabaseMovisensXS}, db)
    df_participants = read_database(DatabaseParticipants, db)
    participants = unique(df_participants.Participant)

    df_movisensxs = download_and_process_redcap(REDCapMovisensXS, participants)

    df_movisensxs = select(
        df_movisensxs,
        :Participant, :MovisensXSParticipantID, :Instance, :AssignmentDate
    )

    create_or_replace_database(DatabaseMovisensXS, db, df_movisensxs)
end

function update_database(::Type{DatabaseSensingRunning}, db, movisensxs_id, movisensxs_key)
    df_movisensxs = read_database(DatabaseMovisensXS, db)

    df_running = download_movisensxs_running(df_movisensxs, movisensxs_id, movisensxs_key)

    create_or_replace_database(DatabaseSensingRunning, db, df_running)
end

function update_database(::Type{DatabaseDiagnoses}, db)
    df_participants = read_database(DatabaseParticipants, db)
    participants = unique(df_participants.Participant)

    df_baseline = download_and_process_redcap(REDCapS02Baseline, participants)
    df_followup = download_and_process_redcap(REDCapS02FollowUp, participants)
    df_a04 = download_and_process_redcap(REDCapA04, participants)

    df_clarification = @chain begin
        download_and_process_redcap(REDCapClarification, participants)

        transform(All() => ByRow((x...) -> "Clarification") => :DIPSOrigin)

        select(:Participant, :DIPSDate, :DIPSOrigin, :DepressiveEpisode, :ManicEpisode)
        dropmissing
    end

    df_diagnoses = vcat(df_baseline, df_followup, df_a04, df_clarification)

    create_or_replace_database(DatabaseDiagnoses, db, df_diagnoses)
end

function update_database(::Type{DatabaseSubprojects}, db)
    df_participants = read_database(DatabaseParticipants, db)
    participants = unique(df_participants.Participant)

    df_subprojects = @chain begin
        download_and_process_redcap(REDCapSubprojects, participants)

        transform(
            [:A06Included, :A06Finalized] => ByRow((i, f) -> i && !f) => :A06,
            [:B01Included, :B01Finalized] => ByRow((i, f) -> i && !f) => :B01,
            [:B03Included, :B03Finalized] => ByRow((i, f) -> i && !f) => :B03,
            [:B05Included, :B05Finalized] => ByRow((i, f) -> i && !f) => :B05,
            [:B07Included, :B07Finalized] => ByRow((i, f) -> i && !f) => :B07,
            [:C01Included, :C01Finalized] => ByRow((i, f) -> i && !f) => :C01,
            [:C02Included, :C02Finalized] => ByRow((i, f) -> i && !f) => :C02,
            [:C03Included, :C03Finalized] => ByRow((i, f) -> i && !f) => :C03,
            [:C04Included, :C04Finalized] => ByRow((i, f) -> i && !f) => :C04
        )

        select(:Participant, :A06, :B01, :B03, :B05, :B07, :C01, :C02, :C03, :C04)
    end

    create_or_replace_database(DatabaseSubprojects, db, df_subprojects)
end

function update_database(::Type{DatabaseRemissions}, db, signals)
    df_remission = DataFrame(:Participant => String[], :SymptomRemissionDate => Date[])

    for signal in signals
        if signal isa Signal{SymptomRemission}
            push!(df_remission, [signal.participant.id, last(only(signal.data))])
        end
    end

    df_remission = @chain df_remission begin
        vcat(read_dataframe(DatabaseRemissions, db), _)
        unique
    end

    create_or_replace_database(DatabaseRemissions, db, df_remission)
end