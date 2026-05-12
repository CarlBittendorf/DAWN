include("../src/main.jl")

for study_center in STUDY_CENTERS
    city, username, password, clientsecret, studyuuid = study_center.name,
    study_center.username, study_center.password, study_center.client_secret,
    study_center.studyuuid

    db = DuckDB.DB(joinpath("data", city * ".db"))

    df = download_interaction_designer_dataframe(
        username, password, clientsecret, studyuuid)

    names, uuids, types = [getproperty.(VARIABLES_DATABASE, x)
                           for x in [:name, :uuid, :type]]

    df_movisensxs = download_and_process_redcap(REDCapMovisensXS, unique(df.pseudonym))

    df_centers = @chain df_movisensxs begin
        groupby(:Participant)
        transform(:StudyCenter => (x -> coalesce(reverse(x)...)); renamecols = false)

        dropmissing(:StudyCenter)

        # consider only the most recent entry for each participant
        groupby(:Participant)
        subset(:Instance => (x -> x .== maximum(x)))

        select(:Participant, :StudyCenter)
    end

    @chain df begin
        rename(
            :pseudonym => :Participant,
            :participantId => :InteractionDesignerParticipantUUID,
            :group => :InteractionDesignerGroup
        )

        groupby(:Participant)
        combine(
            [:InteractionDesignerParticipantUUID, :InteractionDesignerGroup] .=> first;
            renamecols = false
        )

        # clean participant ids
        transform(:Participant => ByRow(lstrip); renamecols = false)

        # add :StudyCenter column
        leftjoin(df_centers; on = :Participant)

        create_or_replace_database(DatabaseParticipants, db, _)
    end

    @chain df begin
        # some variable uuids changed since the first deployment, use the new uuids
        transform(
            :pseudonym => ByRow(lstrip),
            :variableId => (x -> replace(
                x,
                "6aaf1f9f-d035-4cef-afdc-9fb97dca6670" => "68e88276-e419-49d5-b86f-d12210fec164",
                "70d0ced8-2ef1-4670-8503-43b69cdb0677" => "b0791d6c-a53a-4432-8dda-3f257829b76e",
                "47986a13-5939-4f2d-8be9-6517314e1b03" => "64698771-ebf8-4685-9056-e620f7b22f38",
                "72873f71-6f23-45b2-ae6e-238587867a16" => "aa028d22-45f5-4c3e-b57f-92c8a10485fe"
            ));
            renamecols = false
        )

        # select only the needed variables
        subset(:variableId => ByRow(x -> x in uuids))

        # replace the variable uuids with their corresponding names
        transform(:variableId => (x -> replace(x, (uuids .=> names)...)) => :Variable)

        rename(
            :pseudonym => :Participant,
            :group => :InteractionDesignerGroup,
            :triggerCount => :Trigger,
            :triggerName => :TriggerName,
            :triggerDateTime => :FormTrigger,
            :variableValue => :Value
        )

        dropmissing(:Trigger)

        # parse datetime
        transform(
            :FormTrigger .=> ByRow(parse_created_at) => :DateTime;
            renamecols = false
        )

        subset(
            :DateTime => ByRow(x -> x <= floor(now(), Day) + Hour(5) + Minute(30)),
            :TriggerName => ByRow(x -> !(x in ["Initialization", "ConfigurationUpdate"]))
        )

        # convert inline strings to regular strings and remove quotation marks
        transform(
            :Value => ByRow(x -> ismissing(x) ? x : strip(convert(String, x), '\"'));
            renamecols = false
        )

        select(:Participant, :DateTime, :Variable, :Value)

        create_or_replace_database(DatabaseQueries, db, _)
    end
end