include("../src/main.jl")

function script()
    participants = prepare_participant_ids()

    df_clarification = download_and_process_redcap(REDCapClarification, participants)

    df_center = @chain begin
        download_and_process_redcap(REDCapMovisensXS, participants)

        groupby(:Participant)
        transform(:StudyCenter => (x -> coalesce(reverse(x)...)); renamecols = false)

        dropmissing(:StudyCenter)

        # consider only the most recent entry for each participant
        groupby(:Participant)
        subset(:Instance => (x -> x .== maximum(x)))

        select(:Participant, :StudyCenter)
    end

    tables = Hyperscript.Node[]

    function add_table!(tables, paragraph, df)
        nrow(df) > 0 && push!(tables, make_paragraph(paragraph), make_table(df))
    end

    @chain df_clarification begin
        dropmissing(:HAMD)

        leftjoin(df_center; on = :Participant)

        groupby(:StudyCenter)
        combine(
            nrow => :Total,
            :HAMD => (x -> count(x .> 8)) => :Critical
        )

        push!(
            _,
            ["Total", map(sum, eachcol(_)[2:end])...];
            promote = true
        )

        transform([:Total, :Critical] => ByRow((n, c) -> format_compliance(c / n)) => :Percentage)

        add_table!(tables, "HAM-D", _)
    end

    @chain df_clarification begin
        dropmissing(:YMRS)

        leftjoin(df_center; on = :Participant)

        groupby(:StudyCenter)
        combine(
            nrow => :Total,
            :YMRS => (x -> count(x .> 7)) => :Critical
        )

        push!(
            _,
            ["Total", map(sum, eachcol(_)[2:end])...];
            promote = true
        )

        transform([:Total, :Critical] => ByRow((n, c) -> format_compliance(c / n)) => :Percentage)

        add_table!(tables, "YMRS", _)
    end

    @chain df_clarification begin
        dropmissing(:HAMD)
        subset(:HAMD => ByRow(x -> x > 8))

        leftjoin(df_center; on = :Participant)

        groupby(:StudyCenter)
        combine(
            nrow => :CriticalHAMD,
            :DepressiveEpisode => (x -> count(!ismissing, x)) => :Completed,
            [:HAMDDate, :DepressiveEpisode] => ((h, e) -> count((h .< Date(now()) - Week(4)) .& ismissing.(e))) => :NotCompleted,
            [:HAMDDate, :DepressiveEpisode] => ((h, e) -> count((h .>= Date(now()) - Week(4)) .& ismissing.(e))) => :Pending
        )

        push!(
            _,
            ["Total", map(sum, eachcol(_)[2:end])...];
            promote = true
        )

        add_table!(tables, "DIPS (Inflection Depression)", _)
    end

    @chain df_clarification begin
        dropmissing(:YMRS)
        subset(:YMRS => ByRow(x -> x > 7))

        leftjoin(df_center; on = :Participant)

        groupby(:StudyCenter)
        combine(
            nrow => :CriticalYMRS,
            :ManicEpisode => (x -> count(!ismissing, x)) => :Completed,
            [:YMRSDate, :ManicEpisode] => ((y, e) -> count((y .< Date(now()) - Week(4)) .& ismissing.(e))) => :NotCompleted,
            [:YMRSDate, :ManicEpisode] => ((y, e) -> count((y .>= Date(now()) - Week(4)) .& ismissing.(e))) => :Pending
        )

        push!(
            _,
            ["Total", map(sum, eachcol(_)[2:end])...];
            promote = true
        )

        add_table!(tables, "DIPS (Inflection Mania)", _)
    end

    @chain df_clarification begin
        dropmissing([:DepressiveEpisode, :HAMD])
        subset(:HAMD => ByRow(x -> x > 8))

        leftjoin(df_center; on = :Participant)

        groupby(:StudyCenter)
        combine(
            nrow => :Interviews,
            [:DepressiveEpisode, :Dysthymia, :ManicEpisode] .=> count,
            [:DepressiveEpisode, :Dysthymia] => ((de, dy) -> count(de .& dy)) => :DoubleDepression;
            renamecols = false
        )

        push!(
            _,
            ["Total", map(sum, eachcol(_)[2:end])...];
            promote = true
        )

        add_table!(tables, "Diagnoses (Inflection Depression)", _)
    end

    @chain df_clarification begin
        dropmissing([:DepressiveEpisode, :YMRS])
        subset(:YMRS => ByRow(x -> x > 7))

        leftjoin(df_center; on = :Participant)

        groupby(:StudyCenter)
        combine(
            nrow => :Interviews,
            [:DepressiveEpisode, :Dysthymia, :ManicEpisode] .=> count,
            [:DepressiveEpisode, :Dysthymia] => ((de, dy) -> count(de .& dy)) => :DoubleDepression;
            renamecols = false
        )

        push!(
            _,
            ["Total", map(sum, eachcol(_)[2:end])...];
            promote = true
        )

        add_table!(tables, "Diagnoses (Inflection Mania)", _)
    end

    html = make_html(
        "Clarification",
        [
            make_title("Clarification"),
            make_paragraph(""),
            tables...
        ]
    )

    send_email(
        EMAIL_CREDENTIALS,
        EMAIL_ERROR_RECEIVER,
        "CRC393 Clarification",
        html
    )
end

run_script(script, EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER)