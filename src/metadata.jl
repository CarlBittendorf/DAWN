
# 1. Interface Documentation
# 2. Generic Definitions
# 3. Concrete Implementations

####################################################################################################
# INTERFACE DOCUMENTATION
####################################################################################################

# This code provides a metadata-enrichment interface for `Signal`s.

# Metadata is represented as a vector of `Pair{String, Any}` and appended to the signal's
# existing `data` field. Concrete metadata rules depend on the type of signal and are implemented
# via multiple dispatch. The core interface is:

# attach_metadata(signal::Signal{<:AbstractSignal}, study_center::StudyCenter)

####################################################################################################
# GENERIC DEFINITIONS
####################################################################################################

"""
    attach_metadata(signal::Signal{<:AbstractSignal}, study_center::StudyCenter) -> Signal

Attach derived metadata to a signal.

This function enriches a `Signal` with additional metadata derived from participant information
and external study data (e.g. REDCap). The fallback implementation returns the input signal
unchanged. Concrete signal types may override this behavior to inject signal-specific metadata.
"""
function attach_metadata end

# fallback: no additional metadata
attach_metadata(signal::Signal{<:AbstractSignal}, _::StudyCenter) = signal

function attach_metadata(signal::Signal{T}, metadata::Vector{Pair{String, Any}}) where {T}
    Signal{T}(signal.participant, signal.intense_sampling, vcat(signal.data, metadata))
end

####################################################################################################
# CONCRETE IMPLEMENTATIONS
####################################################################################################

function attach_metadata(signal::Signal{InflectionDepression}, study_center::StudyCenter)
    participant = signal.participant

    metadata = Pair{String, Any}[]

    "A04" in participant.subprojects && push!(metadata, "ParticipatingInA04" => true)

    # find the most recent diagnosis
    _, index = findmax(x -> x.date, participant.diagnoses)
    diagnosis = participant.diagnoses[index]

    if !isnothing(diagnosis) &&
       diagnosis.depressive_episode &&
       !any(x -> x >= diagnosis.date, participant.remissions)
        push!(
            metadata,
            "DepressiveEpisode" => true,
            "DIPSOrigin" => diagnosis.origin,
            "DIPSDate" => diagnosis.date
        )
    end

    df = @chain begin
        prepare_participant_ids(study_center)
        download_and_process_redcap(REDCapClarification, _)

        subset(:Participant => ByRow(isequal(participant.id)))
    end

    if nrow(df) > 0
        exclusion = any(df.Exclusion)

        !ismissing(exclusion) && exclusion &&
            push!(metadata, "ExcludedByStudyStaff" => true)

        open = !last(df.CloseInstanceDepression)

        if ismissing(open) || open
            push!(
                metadata,
                "OpenInstance" => true,
                "Instance" => last(df.Instance)
            )
        end

        hamd = last(df.HAMD)
        dips = last(df.DIPSReached)

        if !ismissing(hamd) && hamd > 8 && (ismissing(dips) || !dips)
            push!(
                metadata,
                "WaitingForDIPS" => true,
                "TelephoneDate" => last(df.TelephoneDate),
                "HAMDValue" => last(df.HAMD)
            )
        end
    end

    attach_metadata(signal, metadata)
end

function attach_metadata(signal::Signal{InflectionMania}, study_center::StudyCenter)
    participant = signal.participant

    metadata = Pair{String, Any}[]

    df = @chain begin
        prepare_participant_ids(study_center)
        download_and_process_redcap(REDCapClarification, _)

        subset(:Participant => ByRow(isequal(participant.id)))
    end

    if nrow(df) > 0
        exclusion = any(df.Exclusion)

        !ismissing(exclusion) && exclusion &&
            push!(metadata, "ExcludedByStudyStaff" => true)

        open = !last(df.CloseInstanceMania)

        if ismissing(open) || open
            push!(
                metadata,
                "OpenInstance" => true,
                "Instance" => last(df.Instance)
            )
        end

        ymrs = last(df.YMRS)
        dips = last(df.DIPSReached)

        if !ismissing(ymrs) && ymrs > 8 && (ismissing(dips) || !dips)
            push!(
                metadata,
                "WaitingForDIPS" => true,
                "TelephoneDate" => last(df.TelephoneDate),
                "YMRSValue" => last(df.YMRS)
            )
        end
    end

    attach_metadata(signal, metadata)
end