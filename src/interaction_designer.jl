
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
            "POST",
            "https://id.movisens.com/auth/realms/TherapyDesigner/protocol/openid-connect/token";
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
            "GET",
            "https://id.movisens.com/api/export/studies";
            headers = ["Authorization" => "Bearer " * token]
        )
        only
        getindex("id")
    end
end

function download_interaction_designer_results(token, studyuuid)
    @chain begin
        interaction_designer_api_request(
            "POST",
            "https://id.movisens.com/api/export/studies/" * studyuuid * "/results";
            headers = ["Authorization" => "Bearer " * token],
            query = ["exportFormat" => "CSV", "until" => string(now()) * "Z"]
        )
        getindex("statusId")
    end
end

function download_interaction_designer_results_status(token, studyuuid, statusid)
    interaction_designer_api_request(
        "GET",
        "https://id.movisens.com/api/export/studies/" * studyuuid * "/results/status/" *
        statusid;
        headers = ["Authorization" => "Bearer " * token]
    )
end

function download_interaction_designer_results_data(token, studyuuid, resultid)
    interaction_designer_api_request(
        "GET",
        "https://id.movisens.com/api/export/studies/" * studyuuid * "/results/" * resultid;
        headers = ["Authorization" => "Bearer " * token]
    )
end

function download_interaction_designer_participants(token, studyuuid)
    interaction_designer_api_request(
        "GET",
        "https://id.movisens.com/api/export/studies/" * studyuuid * "/participants";
        headers = ["Authorization" => "Bearer " * token]
    )
end

function download_interaction_designer_participant_data(token, studyuuid, participantuuid)
    interaction_designer_api_request(
        "GET",
        "https://id.movisens.com/api/export/studies/" * studyuuid * "/participants/" *
        participantuuid;
        headers = ["Authorization" => "Bearer " * token]
    )
end

function download_interaction_designer_groups(token, studyuuid)
    interaction_designer_api_request(
        "GET",
        "https://id.movisens.com/api/export/studies/" * studyuuid * "/groups";
        headers = ["Authorization" => "Bearer " * token]
    )
end

function download_interaction_designer_group_data(token, studyuuid, groupuuid)
    interaction_designer_api_request(
        "GET",
        "https://id.movisens.com/api/export/studies/" * studyuuid * "/groups/" * groupuuid;
        headers = ["Authorization" => "Bearer " * token]
    )
end

function download_interaction_designer_variable_values(
        token,
        studyuuid,
        participantuuids,
        variables;
        cutofftime,
        hoursinpast
)
    df = DataFrame(
        :Participant => String[],
        :DateTime => DateTime[],
        :Variable => String[],
        :Value => []
    )

    names, variableuuids, types = [getproperty.(variables, x)
                                   for x in [:name, :uuid, :type]]

    chunks = chunk(length(participantuuids), 100)

    # download data, up to 100 participants at a time
    for range in chunks
        # download data, up to 168 hours at a time
        for i in 0:(ceil(Int, hoursinpast / 168) - 1)
            result = interaction_designer_api_request(
                "POST",
                "https://id.movisens.com/api/export/studies/" * studyuuid *
                "/variable-values";
                body = JSON.json(
                    Dict(
                    "participants" => participantuuids[range],
                    "variables" => variableuuids
                )
                ),
                headers = [
                    "Content-Type" => "application/json",
                    "Authorization" => "Bearer " * token
                ],
                query = [
                    "cutoffTime" => format_cutoff_time(cutofftime - Week(i)),
                    "hoursInPast" => string(min(hoursinpast - i * 168, 168))
                ]
            )

            for participant in result["participants"]
                pseudonym = participant["pseudonym"]
                variable_values = participant["variableValues"]

                # loop through the variables
                for (name, uuid, type) in zip(names, variableuuids, types)
                    values = variable_values[uuid]["values"]

                    # if entries exist, add them to the dataframe
                    if !isempty(values)
                        df = vcat(
                            df,
                            DataFrame(
                                :Participant => pseudonym,
                                :DateTime => map(
                                    x -> parse_created_at(x["createdAt"]), values),
                                :Variable => name,
                                :Value => map(x -> parse_value(type, x["value"]), values))
                        )
                    end
                end
            end
        end
    end

    return df
end

function download_interaction_designer_dataframe(
        username, password, clientsecret, studyuuid)
    # bearer token, which is valid for five minutes
    token = download_interaction_designer_token(username, password, clientsecret)

    # request the study results
    statusid = download_interaction_designer_results(token, studyuuid)

    result = Dict()
    i = 1

    # wait until the results are available
    while !haskey(result, "url")
        sleep(1)

        i += 1

        if i % 240 == 0
            # bearer token, which is valid for five minutes
            token = download_interaction_designer_token(username, password, clientsecret)
        end

        result = download_interaction_designer_results_status(token, studyuuid, statusid)
    end

    url = result["url"]
    filename = download(url)

    return CSV.read(filename, DataFrame)
end