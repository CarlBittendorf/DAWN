
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
            :Location => getindex.(_, "standort"),
            :LocationDresden => getindex.(_, "standort_dd"),
            :Instance => getindex.(_, "redcap_repeat_instance"),
            :FirstAssignmentDate => getindex.(_, "movisensid_timestamp"),
            :SecondAssignmentDate => getindex.(_, "date_movisense_id")
        )

        transform(
            :FirstAssignmentDate => ByRow(x -> x == "[not completed]" ? "" : x);
            renamecols = false
        )
        transform(
            :Participant => ByRow(x -> x isa Int ? lpad(x, 4, "0") : string(x)),
            :MovisensXSParticipantID => ByRow(clean_movisensxs_id),
            [:Location, :LocationDresden] => ByRow(clean_study_center) => :StudyCenter,
            :FirstAssignmentDate => ByRow(x -> x == "" ? missing : Date(x[1:10])),
            :SecondAssignmentDate => ByRow(x -> x == "" ? missing : Date(x));
            renamecols = false
        )
        transform([:FirstAssignmentDate, :SecondAssignmentDate] => ByRow((x, y) -> coalesce(x, y)) => :AssignmentDate)

        select(:Participant, :MovisensXSParticipantID,
            :Instance, :AssignmentDate, :StudyCenter)
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

function process_redcap_diagnoses(json)
    @chain json begin
        DataFrame(
            :Participant => getindex.(_, "participant_id"),
            :DIPSDate => getindex.(_, "date"),
            :FirstCode => getindex.(_, "dsm_diagnosecodierung_1"),
            :SecondCode => getindex.(_, "dsm_diagnosecodierung_2"),
            :ThirdCode => getindex.(_, "dsm_diagnosecodierung_3"),
            :FourthCode => getindex.(_, "dsm_diagnosecodierung_4"),
            :FifthCode => getindex.(_, "dsm_diagnosecodierung_5"),
            :FirstCharacteristic => getindex.(_, "dips_03a"),
            :SecondCharacteristic => getindex.(_, "dips_03b"),
            :ThirdCharacteristic => getindex.(_, "dips_03c"),
            :FourthCharacteristic => getindex.(_, "dips_03d"),
            :FifthCharacteristic => getindex.(_, "dips_03e")
        )
        subset(:DIPSDate => ByRow(!isequal("")))
        transform(
            :DIPSDate => ByRow(x -> Date(x[1:10])),
            [:FirstCode, :SecondCode, :ThirdCode, :FourthCode, :FifthCode, :FirstCharacteristic, :SecondCharacteristic, :ThirdCharacteristic, :FourthCharacteristic, :FifthCharacteristic]
            => ByRow((x...) -> any(map((code, characteristic) -> is_depressive_episode(code, characteristic), x[1:5], x[6:10]))) => :DepressiveEpisode,
            [:FirstCode, :SecondCode, :ThirdCode, :FourthCode, :FifthCode, :FirstCharacteristic, :SecondCharacteristic, :ThirdCharacteristic, :FourthCharacteristic, :FifthCharacteristic]
            => ByRow((x...) -> any(map((code, characteristic) -> is_manic_episode(code, characteristic), x[1:5], x[6:10]))) => :ManicEpisode;
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
                "fields[1]" => "date",
                "fields[2]" => "dsm_diagnosecodierung_1",
                "fields[3]" => "dsm_diagnosecodierung_2",
                "fields[4]" => "dsm_diagnosecodierung_3",
                "fields[5]" => "dsm_diagnosecodierung_4",
                "fields[6]" => "dsm_diagnosecodierung_5",
                "fields[7]" => "dips_03a",
                "fields[8]" => "dips_03b",
                "fields[9]" => "dips_03c",
                "fields[10]" => "dips_03d",
                "fields[11]" => "dips_03e"
            ]
        )

        process_redcap_dips
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
            :B03Included => getindex.(_, "b03_eingeschlossen"),
            :B03Finalized => getindex.(_, "b03_finalisiert"),
            :B03FinalizedDate => getindex.(_, "b03_finalisiert_date"),
            :B05Included => getindex.(_, "b05_eingeschlossen"),
            :B05Finalized => getindex.(_, "b05_finalisiert"),
            :B05FinalizedDate => getindex.(_, "b05_finalisiert_date"),
            :B07Included => getindex.(_, "b07_eingeschlossen"),
            :B07Finalized => getindex.(_, "b07_finalisiert"),
            :B07FinalizedDate => getindex.(_, "b07_finalisiert_date"),
            :C01Included => getindex.(_, "c01_eingeschlossen"),
            :C01Finalized => getindex.(_, "c01_finalisiert"),
            :C01FinalizedDate => getindex.(_, "c01_finalisiert_date"),
            :C02Included => getindex.(_, "c02_eingeschlossen"),
            :C02Finalized => getindex.(_, "c02_finalisiert"),
            :C02FinalizedDate => getindex.(_, "c02_finalisiert_date"),
            :C03Included => getindex.(_, "c03_eingeschlossen"),
            :C03Finalized => getindex.(_, "c03_finalisiert"),
            :C03FinalizedDate => getindex.(_, "c03_finalisiert_date"),
            :C04Included => getindex.(_, "c04_eingeschlossen"),
            :C04Finalized => getindex.(_, "c04_finalisiert"),
            :C04FinalizedDate => getindex.(_, "c04_finalisiert_date")
        )
        transform(
            Cols(x -> x != "Participant" && !endswith(x, "Date")) .=> ByRow(isequal("1")),
            Cols(endswith("Date")) .=> ByRow(x -> x != "" ? Date(x[1:10]) : missing);
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
                "fields[8]" => "b03_eingeschlossen",
                "fields[9]" => "b03_finalisiert",
                "fields[10]" => "b03_finalisiert_date",
                "fields[11]" => "b05_eingeschlossen",
                "fields[12]" => "b05_finalisiert",
                "fields[13]" => "b05_finalisiert_date",
                "fields[14]" => "b07_eingeschlossen",
                "fields[15]" => "b07_finalisiert",
                "fields[16]" => "b07_finalisiert_date",
                "fields[17]" => "c01_eingeschlossen",
                "fields[18]" => "c01_finalisiert",
                "fields[19]" => "c01_finalisiert_date",
                "fields[20]" => "c02_eingeschlossen",
                "fields[21]" => "c02_finalisiert",
                "fields[22]" => "c02_finalisiert_date",
                "fields[23]" => "c03_eingeschlossen",
                "fields[24]" => "c03_finalisiert",
                "fields[25]" => "c03_finalisiert_date",
                "fields[26]" => "c04_eingeschlossen",
                "fields[27]" => "c04_finalisiert",
                "fields[28]" => "c04_finalisiert_date"
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