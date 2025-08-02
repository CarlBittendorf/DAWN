
function interaction_designer_api_request(
        method, url; headers = [], body = UInt8[], query = nothing)
    response = HTTP.request(
        method,
        url;
        headers,
        body,
        query,
        status_exception = false,
        logerrors = true,
        retries = 10
    )

    if response.status in [200, 202, 303]
        return @chain response.body begin
            String
            JSON.parse
        end
    else
        @warn "Interaction Designer API request failed:" url response

        return nothing
    end
end

function download_interaction_designer_token(username, password, clientsecret)
    @chain begin
        interaction_designer_api_request(
            "POST", "https://id.movisens.com/auth/realms/TherapyDesigner/protocol/openid-connect/token";
            body = Dict(
                "client_id" => "td-api",
                "grant_type" => "password",
                "username" => username,
                "password" => password,
                "client_secret" => clientsecret
            )
        )
        getindex("access_token")
    end
end

function download_interaction_designer_studyuuid(token)
    @chain begin
        interaction_designer_api_request(
            "GET", "https://id.movisens.com/api/export/studies";
            headers = ["Authorization" => "Bearer " * token]
        )
        only
        getindex("id")
    end
end

function download_interaction_designer_results(token, studyuuid)
    @chain begin
        interaction_designer_api_request(
            "POST", "https://id.movisens.com/api/export/studies/" * studyuuid * "/results";
            headers = ["Authorization" => "Bearer " * token],
            query = ["exportFormat" => "CSV"]
        )
        getindex("statusId")
    end
end

function download_interaction_designer_results_status(token, studyuuid, statusid)
    interaction_designer_api_request(
        "GET", "https://id.movisens.com/api/export/studies/" * studyuuid *
               "/results/status/" * statusid;
        headers = ["Authorization" => "Bearer " * token]
    )
end

function download_interaction_designer_results_data(token, studyuuid, resultid)
    interaction_designer_api_request(
        "GET", "https://id.movisens.com/api/export/studies/" * studyuuid * "/results/" *
               resultid;
        headers = ["Authorization" => "Bearer " * token]
    )
end

function download_interaction_designer_participants(token, studyuuid)
    interaction_designer_api_request(
        "GET", "https://id.movisens.com/api/export/studies/" * studyuuid *
               "/participants";
        headers = ["Authorization" => "Bearer " * token]
    )
end

function download_interaction_designer_participant_data(token, studyuuid, participantuuid)
    interaction_designer_api_request(
        "GET", "https://id.movisens.com/api/export/studies/" * studyuuid *
               "/participants/" * participantuuid;
        headers = ["Authorization" => "Bearer " * token]
    )
end

function download_interaction_designer_groups(token, studyuuid)
    interaction_designer_api_request(
        "GET", "https://id.movisens.com/api/export/studies/" * studyuuid * "/groups";
        headers = ["Authorization" => "Bearer " * token]
    )
end

function download_interaction_designer_group_data(token, studyuuid, groupuuid)
    interaction_designer_api_request(
        "GET", "https://id.movisens.com/api/export/studies/" * studyuuid * "/groups/" *
               groupuuid;
        headers = ["Authorization" => "Bearer " * token]
    )
end

function variable_values_to_dataframe(data, variables)
    uuids = getproperty.(variables, :uuid)
    names = getproperty.(variables, :name)
    types = getproperty.(variables, :type)

    vcat((
        begin
            id = participant["pseudonym"]
            variable_values = participant["variableValues"]

            dfs_variables = DataFrame[]

            for (name, uuid, type) in zip(names, uuids, types)
                dicts = variable_values[uuid]["values"]

                dates = Date[]
                values = Union{type, Missing}[]

                if !isempty(dicts)
                    for dict in dicts
                        datetime = DateTime(dict["createdAt"][1:(end - 4)])
                        date = Date(datetime)

                        if Time(datetime) <= Time("05:30")
                            date -= Day(1)
                        end

                        if isnothing(dict["value"])
                            value = missing
                        elseif typeof(dict["value"]) == type
                            value = dict["value"]
                        elseif type <: Vector
                            if typeof(dict["value"]) == eltype(type)
                                value = [dict["value"]]
                            else
                                value = [parse(eltype(type), dict["value"])]
                            end
                        else
                            value = parse(type, dict["value"])
                        end

                        push!(dates, date)
                        push!(values, value)
                    end
                end

                df_variable = DataFrame(:Date => dates, Symbol(name) => values)

                if !isempty(values)
                    df_variable = @chain df_variable begin
                        groupby(:Date)
                        combine(
                            Symbol(name) => (x -> begin
                            if type <: Vector
                                Ref(convert(type, replace(vcat(x...), missing => typemin(Int32))))
                            else
                                last(x)
                            end
                        end) => Symbol(name)
                        )
                    end
                end

                push!(dfs_variables, df_variable)
            end

            @chain begin
                outerjoin(dfs_variables...; on = :Date)
                transform(All() => ByRow((x...) -> id) => :Participant)
                sort(:Date)
            end
        end
    for participant in data["participants"]
    )...)
end

function download_interaction_designer_variable_values(
        token,
        studyuuid,
        participantuuids,
        variableuuids;
        cutofftime = make_cutoff(),
        hoursinpast = 24
)
    interaction_designer_api_request(
        "POST", "https://id.movisens.com/api/export/studies/" * studyuuid *
                "/variable-values";
        body = JSON.json(
            Dict(
            "participants" => participantuuids,
            "variables" => variableuuids
        )
        ),
        headers = [
            "Content-Type" => "application/json",
            "Authorization" => "Bearer " * token
        ],
        query = ["cutoffTime" => cutofftime, "hoursInPast" => string(hoursinpast)]
    )
end

function download_interaction_designer_dataframe(
        username, password, clientsecret, studyuuid)
    # bearer token, which is valid for five minutes
    token = download_interaction_designer_token(username, password, clientsecret)

    # request the study results
    statusid = download_interaction_designer_results(token, studyuuid)

    result = Dict()

    # wait until the results are available
    while !haskey(result, "url")
        sleep(1)

        result = download_interaction_designer_results_status(token, studyuuid, statusid)
    end

    url = result["url"]
    filename = download(url)

    return CSV.read(filename, DataFrame)
end

function process_interaction_designer_participants(df)
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
    end
end

function process_interaction_designer_data(
        df, interaction_designer_variables, database_variables)
    uuids = getproperty.(interaction_designer_variables, :uuid)
    names = getproperty.(interaction_designer_variables, :name)
    types = getproperty.(interaction_designer_variables, :type)

    @chain df begin
        # some variable uuids changed since the first deployment, use the new uuids
        transform(
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
        subset(:variableId => ByRow(x -> x in getproperty.(
            INTERACTION_DESIGNER_VARIABLES, :uuid)))

        # replace the variable uuids with their corresponding names
        transform(:variableId => (x -> replace(x, (uuids .=> names)...)) => :VariableName)

        rename(
            :pseudonym => :Participant,
            :group => :InteractionDesignerGroup,
            :triggerCount => :Trigger,
            :triggerDateTime => :FormTrigger,
            :startDateTime => :FormStart,
            :finishDateTime => :FormFinish,
            :variableValue => :VariableValue
        )

        transform(
            :Participant => ByRow(string),
            [:VariableName, :VariableValue] => ByRow((n, x) -> n in [
            "EventNegative", "SocialInteractions"] && ismissing(x) ? string(typemin(Int32)) : x) => :VariableValue;
            renamecols = false
        )

        # change to wide format
        unstack(:VariableName, :VariableValue)

        dropmissing(:Trigger)

        # parse datetimes
        transform(
            [:FormTrigger, :FormStart, :FormFinish] .=> ByRow(x -> DateTime(x[1:19]));
            renamecols = false
        )

        # coalesce so that each row corresponds to one query
        groupby([:Participant, :Trigger])
        combine(All() .=> (x -> coalesce(x...)); renamecols = false)

        # convert inline strings to regular strings
        transform(
            names .=> ByRow(x -> ismissing(x) ? x : convert(String, x));
            renamecols = false
        )

        # remove quotation marks and parse the values of each variable as its corresponding type
        transform(
            [name => ByRow(x -> ismissing(x) || x isa T ? x : parse(T, strip(x, '\"')))
             for (name, T) in zip(names, map(x -> x <: Vector ? eltype(x) : x, types))]...;
            renamecols = false
        )

        transform(
            :FormTrigger => ByRow(Date) => :Date,
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

        subset(:Date => ByRow(!isequal(Date(now()))))

        groupby([:Participant, :Date])
        combine(
            [:EventNegative, :SocialInteractions] .=>
                (x -> length(filter(!ismissing, x)) >= 2 ? Ref(collect(skipmissing(x))) :
                      missing),
            filter(x -> !(x in [:Participant, :Date, :EventNegative, :SocialInteractions]),
                Symbol.(database_variables)) .=> (x -> coalesce(x...));
            renamecols = false
        )

        select(database_variables)
    end
end