
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