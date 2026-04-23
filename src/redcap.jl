
####################################################################################################
# INTERFACE DOCUMENTATION
####################################################################################################

# This code provides a typed interface to multiple REDCap projects, allowing project-specific
# configuration (API token, exported fields, and post‑processing) while sharing a common API
# request mechanism.

# Each project is represented by a concrete Julia type and should implement the following functions:

# token(::Type{<:AbstractREDCapProject})
# fields(::Type{<:AbstractREDCapProject})
# process(::Type{<:AbstractREDCapProject}, json)

####################################################################################################
# GENERIC DEFINITIONS
####################################################################################################

abstract type AbstractREDCapProject end

"""
    token(::Type{<:AbstractREDCapProject}) -> String

Return the REDCap API token for a given project type.
"""
function token end

"""
    fields(::Type{<:AbstractREDCapProject}) -> Vector{String}

Return the list of REDCap field names to be exported for a given project type.
"""
function fields end

"""
    process(::Type{<:AbstractREDCapProject}, json) -> DataFrame

Transform raw JSON records returned by the REDCap API into a cleaned `DataFrame`.

Each concrete project implements its own processing logic.
"""
function process end

process(T::Type{<:AbstractREDCapProject}) = json -> process(T, json)

####################################################################################################
# CONCRETE IMPLEMENTATIONS
####################################################################################################

struct REDCapSignals <: AbstractREDCapProject end
struct REDCapS02Baseline <: AbstractREDCapProject end
struct REDCapMovisensXS <: AbstractREDCapProject end
struct REDCapSubprojects <: AbstractREDCapProject end
struct REDCapClarification <: AbstractREDCapProject end

token(::Type{REDCapSignals}) = REDCAP_API_TOKEN_1308
token(::Type{REDCapS02Baseline}) = REDCAP_API_TOKEN_1362
token(::Type{REDCapMovisensXS}) = REDCAP_API_TOKEN_1376
token(::Type{REDCapSubprojects}) = REDCAP_API_TOKEN_1401
token(::Type{REDCapClarification}) = REDCAP_API_TOKEN_1553

function fields(::Type{REDCapS02Baseline})
    [
        "participant_id",
        "date",
        "dsm_diagnosecodierung_1",
        "dsm_diagnosecodierung_2",
        "dsm_diagnosecodierung_3",
        "dsm_diagnosecodierung_4",
        "dsm_diagnosecodierung_5",
        "dips_03a",
        "dips_03b",
        "dips_03c",
        "dips_03d",
        "dips_03e"
    ]
end

function fields(::Type{REDCapMovisensXS})
    [
        "participant_id",
        "movisensid",
        "standort",
        "standort_dd",
        "date_movisense_id"
    ]
end

function fields(::Type{REDCapSubprojects})
    [
        "participant_id",
        "a06_eingeschlossen",
        "a06_eingeschlossen_date",
        "a06_finalisiert",
        "a06_finalisiert_date",
        "b01_eingeschlossen",
        "b01_finalisiert",
        "b01_finalisiert_date",
        "b03_eingeschlossen",
        "b03_finalisiert",
        "b03_finalisiert_date",
        "b05_eingeschlossen",
        "b05_finalisiert",
        "b05_finalisiert_date",
        "b07_eingeschlossen",
        "b07_finalisiert",
        "b07_finalisiert_date",
        "c01_eingeschlossen",
        "c01_finalisiert",
        "c01_finalisiert_date",
        "c02_eingeschlossen",
        "c02_finalisiert",
        "c02_finalisiert_date",
        "c04_eingeschlossen",
        "c04_finalisiert",
        "c04_finalisiert_date"
    ]
end

function fields(::Type{REDCapClarification})
    [
        "participant_id",
        "is_typ",
        "inflection_depression_first_value",
        "inflection_depression_second_value",
        "inflection_depression_first_date",
        "inflection_depression_second_date",
        "inflection_mania_first_value",
        "inflection_mania_second_value",
        "inflection_mania_first_date",
        "inflection_mania_second_date",
        "is_abklaerung_date",
        "interviewerin",
        "prb_erreicht",
        "is_telefonkontakt",
        "is_kein_telefonkontakt",
        "prb_teilnahme",
        "instanz_schliessen",
        "datum_instanz_schliessen_depression",
        "instanz_schliessen_manie",
        "datum_instanz_schliessen_manie",
        "is_ausschluss",
        "date02",
        "hamd_sum17",
        "sighads_hamd_complete",
        "date03",
        "ymrs_sum",
        "ymrs_complete",
        "dips_erreicht_is",
        "date_diagnosis_is",
        "dsm_diagnosecodierung_1_is",
        "dsm_diagnosecodierung_2_is",
        "dsm_diagnosecodierung_3_is",
        "dsm_diagnosecodierung_4_is",
        "dsm_diagnosecodierung_5_is",
        "dips_03a_is",
        "dips_03b_is",
        "dips_03c_is",
        "dips_03d_is",
        "dips_03e_is",
        "dips_psychstoerung_is",
        "episode_is"
    ]
end

function process(::Type{REDCapS02Baseline}, json)
    @chain json begin
        DataFrame
        rename(
            :participant_id => :Participant,
            :date => :DIPSDate
        )

        subset(:DIPSDate => ByRow(!isequal("")))
        transform(
            :DIPSDate => ByRow(x -> Date(x[1:10])),
            [
                [:dsm_diagnosecodierung_1, :dips_03a],
                [:dsm_diagnosecodierung_2, :dips_03b],
                [:dsm_diagnosecodierung_3, :dips_03c],
                [:dsm_diagnosecodierung_4, :dips_03d],
                [:dsm_diagnosecodierung_5, :dips_03e]
            ] .=> ByRow(is_depressive_episode) .=> [:DE1, :DE2, :DE3, :DE4, :DE5],
            [
                [:dsm_diagnosecodierung_1, :dips_03a],
                [:dsm_diagnosecodierung_2, :dips_03b],
                [:dsm_diagnosecodierung_3, :dips_03c],
                [:dsm_diagnosecodierung_4, :dips_03d],
                [:dsm_diagnosecodierung_5, :dips_03e]
            ] .=> ByRow(is_manic_episode) .=> [:ME1, :ME2, :ME3, :ME4, :ME5];
            renamecols = false
        )
        transform(
            [:DE1, :DE2, :DE3, :DE4, :DE5] => ByRow((x...) -> any(x)) => :DepressiveEpisode,
            [:ME1, :ME2, :ME3, :ME4, :ME5] => ByRow((x...) -> any(x)) => :ManicEpisode
        )

        select(:Participant, :DIPSDate, :DepressiveEpisode, :ManicEpisode)
    end
end

function process(::Type{REDCapMovisensXS}, json)
    @chain json begin
        DataFrame
        rename(
            :participant_id => :Participant,
            :movisensid => :MovisensXSParticipantID,
            :standort => :Location,
            :standort_dd => :LocationDresden,
            :redcap_repeat_instance => :Instance,
            :movisensid_timestamp => :EntryCreatedDateTime,
            :date_movisense_id => :AssignmentDate
        )

        transform(
            :EntryCreatedDateTime => ByRow(x -> x == "[not completed]" ? "" : x);
            renamecols = false
        )
        transform(
            :Participant => ByRow(x -> x isa Int ? lpad(x, 4, "0") : string(x)),
            :MovisensXSParticipantID => ByRow(clean_movisensxs_id),
            [:Location, :LocationDresden] => ByRow(clean_study_center) => :StudyCenter,
            :EntryCreatedDateTime => ByRow(x -> x == "" ? missing : Date(x[1:10])),
            :AssignmentDate => ByRow(x -> x == "" ? missing : Date(x));
            renamecols = false
        )
        transform([:EntryCreatedDateTime, :AssignmentDate] => ByRow((x, y) -> coalesce(x, y)) => :AssignmentDate)

        select(:Participant, :MovisensXSParticipantID,
            :Instance, :AssignmentDate, :StudyCenter)
    end
end

function process(::Type{REDCapSubprojects}, json)
    names = [
        :Participant,
        :A06Included, :A06IncludedDate, :A06Finalized, :A06FinalizedDate,
        :B01Included, :B01Finalized, :B01FinalizedDate,
        :B03Included, :B03Finalized, :B03FinalizedDate,
        :B05Included, :B05Finalized, :B05FinalizedDate,
        :B07Included, :B07Finalized, :B07FinalizedDate,
        :C01Included, :C01Finalized, :C01FinalizedDate,
        :C02Included, :C02Finalized, :C02FinalizedDate,
        :C03Included, :C03Finalized, :C03FinalizedDate,
        :C04Included, :C04Finalized, :C04FinalizedDate
    ]

    @chain json begin
        DataFrame
        rename(fields(REDCapSubprojects) .=>
            filter(x -> !contains(string(x), "C03"), names))

        transform(
            :B05Included => identity => :C03Included,
            :B05Finalized => identity => :C03Finalized,
            :B05FinalizedDate => identity => :C03FinalizedDate
        )
        transform(
            Cols(x -> endswith(x, r"Included|Finalized")) .=> ByRow(isequal("1")),
            Cols(endswith("Date")) .=> ByRow(x -> x != "" ? Date(x[1:10]) : missing);
            renamecols = false
        )

        select(names)
    end
end

function process(::Type{REDCapClarification}, json)
    @chain json begin
        DataFrame
        rename(
            :participant_id => :Participant,
            :redcap_repeat_instance => :Instance,
            :inflection_depression_first_value => :InflectionDepressionFirstValue,
            :inflection_depression_second_value => :InflectionDepressionSecondValue,
            :inflection_depression_first_date => :InflectionDepressionFirstDate,
            :inflection_depression_second_date => :InflectionDepressionSecondDate,
            :inflection_mania_first_value => :InflectionManiaFirstValue,
            :inflection_mania_second_value => :InflectionManiaSecondValue,
            :inflection_mania_first_date => :InflectionManiaFirstDate,
            :inflection_mania_second_date => :InflectionManiaSecondDate,
            :is_abklaerung_date => :TelephoneDate,
            :interviewerin => :TelephoneInterviewer,
            :prb_erreicht => :TelephoneReached,
            :is_telefonkontakt => :TelephoneNotes,
            :prb_teilnahme => :Participation,
            :is_ausschluss => :Exclusion,
            :instanz_schliessen => :CloseInstanceDepression,
            :datum_instanz_schliessen_depression => :CloseInstanceDepressionDate,
            :instanz_schliessen_manie => :CloseInstanceMania,
            :datum_instanz_schliessen_manie => :CloseInstanceManiaDate,
            :hamd_sum17 => :HAMD,
            :date02 => :HAMDDate,
            :ymrs_sum => :YMRS,
            :date03 => :YMRSDate,
            :dips_erreicht_is => :DIPSReached,
            :date_diagnosis_is => :DIPSDate,
            :dips_psychstoerung_is => :PsychiatricDisorder,
            :episode_is => :Episode
        )
        transform(All() .=> ByRow(x -> x == "" ? missing : x); renamecols = false)

        groupby([:Participant, :Instance])
        combine(All() .=> (x -> coalesce(x...)); renamecols = false)

        transform(
            [
                :InflectionDepressionFirstDate, :InflectionDepressionSecondDate,
                :InflectionManiaFirstDate, :InflectionManiaSecondDate,
                :CloseInstanceDepressionDate, :CloseInstanceManiaDate,
                :TelephoneDate, :HAMDDate, :YMRSDate, :DIPSDate
            ] .=> ByRow(x -> ismissing(x) ? x : Date(x[1:10])),
            [
                :InflectionDepressionFirstValue, :InflectionDepressionSecondValue,
                :InflectionManiaFirstValue, :InflectionManiaSecondValue,
                :HAMD, :YMRS
            ] .=> ByRow(x -> ismissing(x) ? x : parse(Int, x)),
            [
                :TelephoneReached, :Participation, :Exclusion,
                :CloseInstanceDepression, :CloseInstanceMania,
                :DIPSReached, :PsychiatricDisorder, :Episode
            ] .=> ByRow(x -> ismissing(x) ? x : x == "1"),
            [
                [:dsm_diagnosecodierung_1_is, :dips_03a_is],
                [:dsm_diagnosecodierung_2_is, :dips_03b_is],
                [:dsm_diagnosecodierung_3_is, :dips_03c_is],
                [:dsm_diagnosecodierung_4_is, :dips_03d_is],
                [:dsm_diagnosecodierung_5_is, :dips_03e_is]
            ] .=>
                ByRow((c, x) -> ismissing(c) ? c : is_depressive_episode(c, x)) .=>
                    [:DE1, :DE2, :DE3, :DE4, :DE5],
            [
                [:dsm_diagnosecodierung_1_is, :dips_03a_is],
                [:dsm_diagnosecodierung_2_is, :dips_03b_is],
                [:dsm_diagnosecodierung_3_is, :dips_03c_is],
                [:dsm_diagnosecodierung_4_is, :dips_03d_is],
                [:dsm_diagnosecodierung_5_is, :dips_03e_is]
            ] .=>
                ByRow((c, x) -> ismissing(c) ? c : is_dysthymia(c, x)) .=>
                    [:DY1, :DY2, :DY3, :DY4, :DY5],
            [
                [:dsm_diagnosecodierung_1_is, :dips_03a_is],
                [:dsm_diagnosecodierung_2_is, :dips_03b_is],
                [:dsm_diagnosecodierung_3_is, :dips_03c_is],
                [:dsm_diagnosecodierung_4_is, :dips_03d_is],
                [:dsm_diagnosecodierung_5_is, :dips_03e_is]
            ] .=>
                ByRow((c, x) -> ismissing(c) ? c : is_manic_episode(c, x)) .=>
                    [:ME1, :ME2, :ME3, :ME4, :ME5];
            renamecols = false
        )
        transform(
            [:DE1, :DE2, :DE3, :DE4, :DE5] => ByRow((x...) -> any(x)) => :DepressiveEpisode,
            [:DY1, :DY2, :DY3, :DY4, :DY5] => ByRow((x...) -> any(x)) => :Dysthymia,
            [:ME1, :ME2, :ME3, :ME4, :ME5] => ByRow((x...) -> any(x)) => :ManicEpisode
        )
        transform(
            [
            [:DepressiveEpisode, :PsychiatricDisorder],
            [:Dysthymia, :PsychiatricDisorder],
            [:ManicEpisode, :PsychiatricDisorder]
        ] .=>
            ByRow((x, d) -> !ismissing(d) && ismissing(x) ? false : x) .=>
                [:DepressiveEpisode, :Dysthymia, :ManicEpisode]
        )

        select(
            :Participant, :Instance,
            :InflectionDepressionFirstValue, :InflectionDepressionSecondValue,
            :InflectionDepressionFirstDate, :InflectionDepressionSecondDate,
            :InflectionManiaFirstValue, :InflectionManiaSecondValue,
            :InflectionManiaFirstDate, :InflectionManiaSecondDate,
            :TelephoneDate, :TelephoneReached, :TelephoneInterviewer, :TelephoneNotes,
            :Participation, :Exclusion,
            :CloseInstanceDepression, :CloseInstanceDepressionDate, :CloseInstanceMania, :CloseInstanceManiaDate,
            :HAMD, :HAMDDate, :YMRS, :YMRSDate,
            :DIPSDate, :DIPSReached, :PsychiatricDisorder, :Episode,
            :DepressiveEpisode, :Dysthymia, :ManicEpisode
        )
    end
end

####################################################################################################
# HIGH-LEVEL FUNCTIONS
####################################################################################################

"""
    redcap_api_request(token, parameters)

Send a raw POST request to the REDCap API.

Returns parsed JSON on success, or `nothing` if the request fails.
"""
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

"""
    download_redcap(T::Type{<:AbstractREDCapProject}, participants)

Request REDCap records for a given project `T` and list of participant IDs.

Automatically:
- selects project-specific fields
- applies the correct API token

Returns parsed JSON suitable for `process`.
"""
function download_redcap(T::Type{<:AbstractREDCapProject}, participants)
    parameters = [
        "exportSurveyFields" => "true",
        "records" => join(participants, ","),
        format_fields(fields(T))...
    ]

    return redcap_api_request(token(T), parameters)
end

function download_and_process_redcap(T::Type{<:AbstractREDCapProject}, participants)
    return process(T, download_redcap(T, participants))
end

function upload_redcap(project::Type{REDCapSignals}, signals)
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

        if signalname in ["inflection_depression", "inflection_mania"]
            forms = [
                "forms[1]" => "inflection_depression", "forms[2]" => "inflection_mania"]
            instruments = ["inflection_depression", "inflection_mania"]
        else
            forms = ["forms[1]" => signalname]
            instruments = [signalname]
        end

        participant = signal.participant

        # determine the last instance of the signal
        # for the two inflection signals, the highest overall is taken
        instance = @chain begin
            redcap_api_request(
                token(project),
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

        logdate = Dates.format(now(tz"Europe/Berlin"), "yyyy-mm-dd HH:MM:SS")

        # upload the signal
        data = Dict(
            "participant_id" => participant,
            "redcap_repeat_instrument" => signalname,
            "redcap_repeat_instance" => string(instance + 1),
            parameters...,
            signalname * "_log_date" => logdate,
            signalname * "_complete" => "2"
        )

        response = redcap_api_request(
            token(project),
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
end