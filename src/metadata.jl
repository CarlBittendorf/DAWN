
attach_metadata(signal::Signal{<:AbstractSignal}, _) = signal

function attach_metadata(signal::Signal{InflectionDepression}, study_center)
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
                data,
                "WaitingForDIPS" => true,
                "TelephoneDate" => last(df.TelephoneDate),
                "HAMDValue" => last(df.HAMD)
            )
        end
    end

    return Signal{InflectionDepression}(
        signal.participant,
        signal.intense_sampling,
        vcat(signal.data, metadata)
    )
end

function attach_metadata(signal::Signal{InflectionDepression}, study_center)
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
                data,
                "WaitingForDIPS" => true,
                "TelephoneDate" => last(df.TelephoneDate),
                "YMRSValue" => last(df.YMRS)
            )
        end
    end

    return Signal{InflectionMania}(
        signal.participant,
        signal.intense_sampling,
        vcat(signal.data, metadata)
    )
end