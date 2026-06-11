
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

    if !isempty(participant.diagnoses)
        # find the most recent diagnosis
        _, index = findmax(x -> x.date, participant.diagnoses)
        diagnosis = participant.diagnoses[index]

        if diagnosis.depressive_episode &&
           !any(x -> x >= diagnosis.date, participant.remissions)
            push!(
                metadata,
                "DepressiveEpisode" => true,
                "DIPSOrigin" => diagnosis.origin,
                "DIPSDate" => diagnosis.date
            )
        end
    end

    df = @chain begin
        prepare_participant_ids(study_center)
        download_and_process_redcap(REDCapClarification, _)

        subset(:Participant => ByRow(isequal(participant.id)))
        sort(:Instance)
    end

    if nrow(df) > 0
        dropout = any(.!df.Participation)

        !ismissing(dropout) && dropout &&
            push!(metadata, "NotParticipating" => true)

        exclusion = any(df.Exclusion)

        !ismissing(exclusion) && exclusion &&
            push!(metadata, "ExcludedByStudyStaff" => true)

        df_depression = subset(
            df,
            :InflectionSignalType => ByRow(isequal("InflectionDepression"))
        )

        if nrow(df_depression) > 0
            open = !last(df_depression.CloseInstanceDepression)

            if ismissing(open) || open
                push!(
                    metadata,
                    "OpenInstance" => true,
                    "Instance" => last(df_depression.Instance)
                )
            end

            hamd = last(df_depression.HAMD)
            dips = last(df_depression.DIPSReached)

            if !ismissing(hamd) && hamd > 8 && (ismissing(dips) || !dips)
                push!(
                    metadata,
                    "WaitingForDIPS" => true,
                    "TelephoneDate" => last(df_depression.TelephoneDate),
                    "HAMDValue" => last(df_depression.HAMD)
                )
            end
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
        sort(:Instance)
    end

    if nrow(df) > 0
        dropout = any(.!df.Participation)

        !ismissing(dropout) && dropout &&
            push!(metadata, "NotParticipating" => true)

        exclusion = any(df.Exclusion)

        !ismissing(exclusion) && exclusion &&
            push!(metadata, "ExcludedByStudyStaff" => true)

        df_mania = subset(df, :InflectionSignalType => ByRow(isequal("InflectionMania")))

        if nrow(df_mania) > 0
            open = !last(df_mania.CloseInstanceMania)

            if ismissing(open) || open
                push!(
                    metadata,
                    "OpenInstance" => true,
                    "Instance" => last(df_mania.Instance)
                )
            end

            ymrs = last(df_mania.YMRS)
            dips = last(df_mania.DIPSReached)

            if !ismissing(ymrs) && ymrs > 8 && (ismissing(dips) || !dips)
                push!(
                    metadata,
                    "WaitingForDIPS" => true,
                    "TelephoneDate" => last(df_mania.TelephoneDate),
                    "YMRSValue" => last(df_mania.YMRS)
                )
            end
        end
    end

    attach_metadata(signal, metadata)
end