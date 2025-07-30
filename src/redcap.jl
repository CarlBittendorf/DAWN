
function redcap_api_request(token, parameters)
    response = HTTP.post(
        "https://redcap.zih.tu-dresden.de/redcap/api/";
        body = Dict(
            "token" => token,
            "content" => "record",
            "format" => "json",
            "type" => "flat",
            "returnFormat" => "json",
            parameters...
        ),
        status_exception = false,
        logerrors = true,
        retries = 10
    )

    if response.status == 200
        return @chain response.body begin
            String
            JSON.parse
        end
    else
        @warn "REDCap API request failed:" response

        return nothing
    end
end

function download_redcap_participants(token, participants)
    @chain token begin
        redcap_api_request([
            "records" => join(participants, ","),
            "fields[0]" => "participant_id",
            "fields[1]" => "movisensid",
            "fields[2]" => "standort_dd"
        ])
        DataFrame(
            :Participant => getindex.(_, "participant_id"),
            :MovisensXSParticipantID => getindex.(_, "movisensid"),
            :LocationDresden => getindex.(_, "standort_dd"),
            :Instance => getindex.(_, "redcap_repeat_instance")
        )
        transform(
            :MovisensXSParticipantID => ByRow(clean_movisensxs_id),
            :LocationDresden => ByRow(x -> x == "1" ? "UKD" : x == "2" ? "FAL" : missing);
            renamecols = false
        )
    end
end

function download_redcap_diagnoses(token, participants)
    @chain token begin
        redcap_api_request([
            "records" => join(participants, ","),
            "fields[0]" => "participant_id",
            "fields[1]" => "dips_date",
            "fields[2]" => "hinweis_md_16",
            "fields[3]" => "hinweis_me_6",
            "fields[4]" => "aaca2_major_depression_complete",
            "fields[5]" => "bipolare_und_verwandte_strungen_complete"
        ])
        DataFrame(
            :Participant => getindex.(_, "participant_id"),
            :DIPSDate => getindex.(_, "dips_date"),
            :DepressiveEpisode => getindex.(_, "hinweis_md_16"),
            :ManicEpisode => getindex.(_, "hinweis_me_6"),
            :DepressiveEpisodeValid => getindex.(_, "aaca2_major_depression_complete"),
            :ManicEpisodeValid => getindex.(_, "bipolare_und_verwandte_strungen_complete")
        )
        subset(
            :DIPSDate => ByRow(!isequal("")),
            [:DepressiveEpisodeValid, :ManicEpisodeValid] .=> ByRow(isequal("2"))
        )
        transform(
            :DIPSDate => ByRow(x -> Date(x[1:10])),
            [:DepressiveEpisode, :ManicEpisode] .=> ByRow(isequal("1"));
            renamecols = false
        )
    end
end

function upload_redcap_signal(token, participant, signalname, parameters)
    if signalname in ["inflection_depression", "inflection_mania"]
        forms = ["forms[1]" => "inflection_depression", "forms[2]" => "inflection_mania"]
        instruments = ["inflection_depression", "inflection_mania"]
    else
        forms = ["forms[1]" => signalname]
        instruments = [signalname]
    end

    # determine the last instance of the signal
    # for the two inflection signals, the highest overall is taken
    instance = @chain token begin
        redcap_api_request([
            "records" => participant,
            "forms[0]" => "initial",
            forms...
        ])
        filter(x -> x["redcap_repeat_instrument"] in instruments, _)
        getindex.("redcap_repeat_instance")
        maximum(; init = 0)
    end

    # upload the signal
    data = Dict(
        "participant_id" => participant,
        "redcap_repeat_instrument" => signalname,
        "redcap_repeat_instance" => string(instance + 1),
        parameters...,
        signalname * "_log_date" => Dates.format(now(), "yyyy-mm-dd HH:MM:SS"),
        signalname * "_complete" => "2"
    )

    response = redcap_api_request(
        token,
        [
            "overwriteBehavior" => "overwrite",
            "data" => JSON.json([data]),
            "returnContent" => "ids"
        ]
    )

    if only(response) == participant
        @info "Uploaded $(snake2camelcase(signalname)) signal for participant $participant." data
    else
        @error "An error occured when trying to upload a signal for participant $participant." data response
    end
end

function upload_redcap_signals(df, token, signals)
    participants = df.Participant

    function preprocess(value)
        x = string(value)

        x == "missing" && return ""
        x == "true" && return "1"
        x == "false" && return "0"

        return x
    end

    for (i, participant) in enumerate(participants)
        alarms = Int[]

        # check which signals are present
        for (j, signal) in enumerate(signals)
            variables = getfield(signal, :variables)
            name = string(first(variables))
            alarm = df[i, name]

            if !ismissing(alarm) && alarm
                push!(alarms, j)
            end
        end

        # upload each signal
        for signal in signals[alarms]
            signalname = camel2snakecase(first(signal.variables))
            variablenames = map(camel2snakecase, signal.variables[2:end])
            variablevalues = map(x -> preprocess(df[i, x]), signal.variables[2:end])
            parameters = [name => value
                          for (name, value) in zip(variablenames, variablevalues)]

            upload_redcap_signal(token, participant, signalname, parameters)
        end
    end
end