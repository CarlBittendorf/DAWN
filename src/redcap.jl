
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

function process_redcap_movisensxs(json)
    @chain json begin
        DataFrame(
            :Participant => getindex.(_, "participant_id"),
            :MovisensXSParticipantID => getindex.(_, "movisensid"),
            :StudyCenter => getindex.(_, "standort"),
            :LocationDresden => getindex.(_, "standort_dd"),
            :Instance => getindex.(_, "redcap_repeat_instance"),
            :FirstAssignmentDate => getindex.(_, "movisensid_timestamp"),
            :SecondAssignmentDate => getindex.(_, "date_movisense_id")
        )

        groupby(:Participant)
        transform(
            [:StudyCenter, :LocationDresden] .=> (x -> coalesce(reverse(x)...));
            renamecols = false
        )

        transform(
            :FirstAssignmentDate => ByRow(x -> x == "[not completed]" ? "" : x);
            renamecols = false
        )
        transform(
            :MovisensXSParticipantID => ByRow(clean_movisensxs_id),
            :StudyCenter => ByRow(x -> x == "1" ? 3 : x == "2" ? 2 : x == "3" ? 1 : missing),
            :LocationDresden => ByRow(x -> x == "1" ? "UKD" : x == "2" ? "FAL" : missing),
            :FirstAssignmentDate => ByRow(x -> x == "" ? missing : Date(DateTime(x[1:10]))),
            :SecondAssignmentDate => ByRow(x -> x == "" ? missing : Date(x));
            renamecols = false
        )
        transform([:FirstAssignmentDate, :SecondAssignmentDate] => ByRow((x, y) -> coalesce(x, y)) => :AssignmentDate)
        select(Not([:FirstAssignmentDate, :SecondAssignmentDate]))
    end
end

function download_redcap_movisensxs(token, participants)
    @chain begin
        redcap_api_request(
            token,
            [
                "records" => join(participants, ","),
                "fields[0]" => "participant_id",
                "fields[1]" => "movisensid",
                "fields[2]" => "standort",
                "fields[3]" => "standort_dd",
                "fields[4]" => "date_movisense_id",
                "exportSurveyFields" => "true"
            ]
        )

        process_redcap_movisensxs
    end
end

function process_redcap_centers(df)
    @chain df begin
        dropmissing(:StudyCenter)

        # consider only the most recent entry for each participant
        groupby(:Participant)
        subset(:Instance => (x -> x .== maximum(x)))

        subset([:StudyCenter, :LocationDresden]
        => ByRow((sc, ld) -> sc != 3 || ld in ["UKD", "FAL"]))
        transform(
            :Participant => ByRow(x -> x isa Int ? lpad(x, 4, "0") : string(x)),
            [:StudyCenter, :LocationDresden] => ByRow((sc, ld) -> sc == 1 ? "Marburg" : sc == 2 ? "Münster" : "Dresden ($ld)") => :StudyCenter;
            renamecols = false
        )

        select(:Participant, :StudyCenter)
    end
end

function process_redcap_diagnoses(json)
    @chain json begin
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

        select(:Participant, :DIPSDate, :DepressiveEpisode, :ManicEpisode)
    end
end

function download_redcap_diagnoses(token, participants)
    @chain begin
        redcap_api_request(
            token,
            [
                "records" => join(participants, ","),
                "fields[0]" => "participant_id",
                "fields[1]" => "dips_date",
                "fields[2]" => "hinweis_md_16",
                "fields[3]" => "hinweis_me_6",
                "fields[4]" => "aaca2_major_depression_complete",
                "fields[5]" => "bipolare_und_verwandte_strungen_complete"
            ]
        )

        process_redcap_diagnoses
    end
end

function process_redcap_subprojects(json)
    @chain json begin
        DataFrame(
            :Participant => getindex.(_, "participant_id"),
            :A06Included => getindex.(_, "a06_eingeschlossen"),
            :A06IncludedDate => getindex.(_, "a06_eingeschlossen_date"),
            :A06Finalized => getindex.(_, "a06_finalisiert"),
            :A06FinalizedDate => getindex.(_, "a06_finalisiert_date"),
            :B01Included => getindex.(_, "b01_eingeschlossen"),
            :B01Finalized => getindex.(_, "b01_finalisiert"),
            :B01FinalizedDate => getindex.(_, "b01_finalisiert_date"),
            :B07Included => getindex.(_, "b07_eingeschlossen"),
            :B07Finalized => getindex.(_, "b07_finalisiert"),
            :B07FinalizedDate => getindex.(_, "b07_finalisiert_date")
        )
        transform(
            [:A06Included, :A06Finalized, :B01Included,
                :B01Finalized, :B07Included, :B07Finalized] .=> ByRow(isequal("1")),
            [:A06IncludedDate, :A06FinalizedDate, :B01FinalizedDate, :B07FinalizedDate] .=>
                ByRow(x -> x != "" ? Date(x[1:10]) : missing);
            renamecols = false
        )
    end
end

function download_redcap_subprojects(token, participants)
    @chain begin
        redcap_api_request(
            token,
            [
                "records" => join(participants, ","),
                "fields[0]" => "participant_id",
                "fields[1]" => "a06_eingeschlossen",
                "fields[2]" => "a06_eingeschlossen_date",
                "fields[3]" => "a06_finalisiert",
                "fields[4]" => "a06_finalisiert_date",
                "fields[5]" => "b01_eingeschlossen",
                "fields[6]" => "b01_finalisiert",
                "fields[7]" => "b01_finalisiert_date",
                "fields[8]" => "b07_eingeschlossen",
                "fields[9]" => "b07_finalisiert",
                "fields[10]" => "b07_finalisiert_date"
            ]
        )

        process_redcap_subprojects
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
    instance = @chain begin
        redcap_api_request(
            token,
            [
                "records" => participant,
                "forms[0]" => "initial",
                forms...
            ]
        )
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

function upload_redcap_signals(token, signals)
    function preprocess(value)
        x = string(value)

        x == "missing" && return ""
        x == "true" && return "1"
        x == "false" && return "0"

        return x
    end

    # upload each signal
    for signal in signals
        signalname = camel2snakecase(typeof(signal))
        variablenames = camel2snakecase.(first.(signal.data))
        variablevalues = preprocess.(last.(signal.data))
        parameters = [name => value for (name, value) in zip(variablenames, variablevalues)]

        upload_redcap_signal(token, signal.participant, signalname, parameters)
    end
end