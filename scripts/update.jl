include("../src/main.jl")

function script()
    index = parse(Int, only(ARGS))
    sc = STUDY_CENTERS[index]

    city, username, password, clientsecret, studyuuid, groups, movisensxs_id, movisensxs_key = sc.name,
    sc.username, sc.password, sc.client_secret, sc.studyuuid,
    sc.groups, sc.movisensxs_id, sc.movisensxs_key

    # connection to database
    db = DuckDB.DB(joinpath("data", city * ".db"))

    # bearer token, which is valid for five minutes
    token = download_interaction_designer_token(username, password, clientsecret)

    ####################################################################################################
    # PARTICIPANTS AND MOVISENSXS
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

    # account for group changes
    df_group = @chain begin
        download_interaction_designer_variable_values(
            token,
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

    df_movisensxs = download_redcap_movisensxs(
        REDCAP_API_TOKEN_1376,
        unique(df_participants.Participant)
    )

    df_centers = @chain df_movisensxs begin
        groupby(:Participant)
        transform(:StudyCenter => (x -> coalesce(reverse(x)...)); renamecols = false)

        dropmissing(:StudyCenter)

        # consider only the most recent entry for each participant
        groupby(:Participant)
        subset(:Instance => (x -> x .== maximum(x)))

        select(:Participant, :StudyCenter)
    end

    df_movisensxs = select(
        df_movisensxs,
        :Participant, :MovisensXSParticipantID, :Instance, :AssignmentDate
    )

    # update movisensxs database
    create_or_replace_movisensxs_database(db)

    append_dataframe(db, df_movisensxs, "movisensxs")

    df_participants = @chain df_participants begin
        # replace participants that belong to another group now
        subset(:Participant => ByRow(x -> !(x in df_group.Participant)))
        vcat(df_group)
        sort(:Participant)

        # add :StudyCenter column
        leftjoin(df_centers; on = :Participant)
    end

    # update participants database
    create_or_replace_participants_database(db)

    append_dataframe(db, df_participants, "participants")

    ####################################################################################################
    # RUNNING
    ####################################################################################################

    # contains :Participant and :Date columns
    df_running = download_movisensxs_running(df_movisensxs, movisensxs_id, movisensxs_key)

    # update running database
    create_or_replace_running_database(db)

    append_dataframe(db, df_running, "running")

    ####################################################################################################
    # DIAGNOSES
    ####################################################################################################

    participants = unique(df_participants.Participant)

    df_diagnoses = download_redcap_subprojects(REDCAP_API_TOKEN_1365, participants)

    # update diagnoses database
    create_or_replace_diagnoses_database(db)

    append_dataframe(db, df_diagnoses, "diagnoses")

    ####################################################################################################
    # SUBPROJECTS
    ####################################################################################################

    # workaround to avoid SSL errors
    sleep(10)

    df_subprojects = @chain begin
        download_redcap_subprojects(REDCAP_API_TOKEN_1401, participants)

        transform(
            [:A06Included, :A06Finalized] => ByRow((i, f) -> i && !f) => :IsA06,
            [:B01Included, :B01Finalized] => ByRow((i, f) -> i && !f) => :IsB01,
            [:B03Included, :B03Finalized] => ByRow((i, f) -> i && !f) => :IsB03,
            [:B05Included, :B05Finalized] => ByRow((i, f) -> i && !f) => :IsB05,
            [:B07Included, :B07Finalized] => ByRow((i, f) -> i && !f) => :IsB07,
            [:C01Included, :C01Finalized] => ByRow((i, f) -> i && !f) => :IsC01,
            [:C02Included, :C02Finalized] => ByRow((i, f) -> i && !f) => :IsC02,
            [:C03Included, :C03Finalized] => ByRow((i, f) -> i && !f) => :IsC03,
            [:C04Included, :C04Finalized] => ByRow((i, f) -> i && !f) => :IsC04
        )

        select(:Participant, :IsA06, :IsB01, :IsB03, :IsB05,
            :IsB07, :IsC01, :IsC02, :IsC03, :IsC04)
    end

    # update subprojects database
    create_or_replace_subprojects_database(db)

    append_dataframe(db, df_subprojects, "subprojects")

    ####################################################################################################
    # QUERIES
    ####################################################################################################

    participantuuids = unique(df_participants.InteractionDesignerParticipantUUID)

    df_queries = @chain begin
        download_interaction_designer_variable_values(
            token,
            studyuuid,
            participantuuids,
            VARIABLES_DATABASE;
            cutofftime = floor(now(), Day) + Hour(5) + Minute(30),
            hoursinpast = 24
        )

        vcat(read_dataframe(db, "queries"), _)
        unique
    end

    # update queries database
    create_or_replace_queries_database(db)

    append_dataframe(db, df_queries, "queries")
end

run_script(script, EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER)