
function movisensxs_api_request(url, key; headers = [])
    response = HTTP.get(
        url,
        [
            "Authorization" => "ApiKey " * key,
            "User-Agent" => "Julia API",
            headers...
        ];
        status_exception = false,
        logerrors = true,
        retries = 10
    )

    if response.status == 200
        return response.body
    else
        @warn "MovisensXS API request failed:" url response

        return nothing
    end
end

function download_movisensxs_unisens(studyid, key, participantid)
    body = movisensxs_api_request(
        "https://xs.movisens.com/api/v2/studies/" * studyid * "/probands/" * participantid *
        "/unisens", key
    )

    if body !== nothing
        return body |> IOBuffer
    else
        return nothing
    end
end

function get_mobile_sensing_participants(df_movisensxs)
    # determine which participants have the movisensxs app currently installed
    @chain df_movisensxs begin
        # consider only the most recent entry for each participant
        groupby(:Participant)
        subset(:Instance => (x -> x .== maximum(x)))

        # select only participants with a movisensxs id
        subset(:MovisensXSParticipantID => ByRow(!isequal("")))
        getproperty(:Participant)
    end
end

function get_mobile_sensing_dates(result)
    folder = ZipFile.Reader(result)

    # read the starting datetime from the unisens.xml file
    start = @chain folder.files begin
        findfirst(x -> x.name == "unisens.xml", _)
        folder.files[_]
        XML.read(XML.Node)
        _[2]["timestampStart"]
        DateTime
    end

    @chain folder.files begin
        # find and read the DeviceRunning.csv file
        findfirst(x -> x.name == "DeviceRunning.csv", _)
        folder.files[_]
        CSV.read(DataFrame; header = ["SecondsSinceStart", "DeviceRunning"])

        # calculate the datetime of each entry
        getproperty(:SecondsSinceStart)
        start .+ Second.(_)

        # determine the dates with at least one entry
        Date.(_)
        unique
    end
end

function download_movisensxs_running(df_movisensxs, studyid, key)
    participants = get_mobile_sensing_participants(df_movisensxs)

    df_running = DataFrame()

    # check if mobile sensing is running
    for participant in participants
        ids = @chain df_movisensxs begin
            subset(
                :Participant => ByRow(isequal(participant)),
                :MovisensXSParticipantID => ByRow(!isequal(""))
            )
            getproperty(:MovisensXSParticipantID)
        end

        df = DataFrame()

        for id in ids
            result = download_movisensxs_unisens(studyid, key, id)

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
            df = @chain df begin
                groupby([:Participant, :Date])
                combine(All() .=> first; renamecols = false)
            end

            df_running = vcat(df_running, df)
        end
    end

    return df_running
end