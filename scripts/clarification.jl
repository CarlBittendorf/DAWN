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

    centers = ["Marburg", "Münster", "Dresden (UKD)", "Dresden (FAL)"]

    tables = Hyperscript.Node[]

    function add_table!(tables, paragraph, df)
        nrow(df) > 0 && push!(tables, make_paragraph(paragraph), make_table(df))
    end

    @chain df_clarification begin
        leftjoin(df_center; on = :Participant)

        dropmissing(:TelephoneDate)
        sort([:TelephoneDate, :StudyCenter])
        subset(
            :TelephoneDate => ByRow(x -> x >= floor(Date(now()) - Month(6), Month)),
            :TelephoneDate => ByRow(x -> x <= Date(now()) - Week(2)),
            :TelephoneNoCallNotes => ByRow(
                x -> ismissing(x) || x in ["SignalMissed", "StaffShortage"]
            )
        )
        transform(
            :TelephoneDate => ByRow(monthname) => :Month,
            :TelephoneReached => ByRow(x -> ismissing(x) ? false : x);
            renamecols = false
        )

        groupby([:StudyCenter, :Month])
        combine(
            nrow => :InflectionSignals,
            :TelephoneReached => count => :Reached
        )

        groupby(:Month)
        transform(
            groupindices => :MonthIndex,
            :StudyCenter => (x -> indexin(x, centers)) => :StudyCenterIndex
        )

        sort([:MonthIndex, :StudyCenterIndex])
        select(Not(:MonthIndex, :StudyCenterIndex))

        push!(
            _,
            ["Total", "", map(sum, eachcol(_)[3:end])...];
            promote = true
        )

        transform([:InflectionSignals, :Reached] => ByRow((t, c) -> format_compliance(c / t)) => :Percentage)

        add_table!(tables, "Phone Calls", _)
    end

    @chain df_clarification begin
        dropmissing(:HAMD)

        leftjoin(df_center; on = :Participant)

        groupby(:StudyCenter)
        combine(
            nrow => :PhoneCalls,
            :HAMD => (x -> count(x .> 8)) => :CriticalHAMD
        )

        push!(
            _,
            ["Total", map(sum, eachcol(_)[2:end])...];
            promote = true
        )

        transform([:PhoneCalls, :CriticalHAMD] => ByRow((n, c) -> format_compliance(c / n)) => :Percentage)

        add_table!(tables, "HAM-D", _)
    end

    @chain df_clarification begin
        dropmissing(:YMRS)

        leftjoin(df_center; on = :Participant)

        groupby(:StudyCenter)
        combine(
            nrow => :PhoneCalls,
            :YMRS => (x -> count(x .> 7)) => :CriticalYMRS
        )

        push!(
            _,
            ["Total", map(sum, eachcol(_)[2:end])...];
            promote = true
        )

        transform([:PhoneCalls, :CriticalYMRS] => ByRow((n, c) -> format_compliance(c / n)) => :Percentage)

        add_table!(tables, "YMRS", _)
    end

    @chain df_clarification begin
        dropmissing(:HAMD)
        subset(:HAMD => ByRow(x -> x > 8))

        leftjoin(df_center; on = :Participant)

        groupby(:StudyCenter)
        combine(
            nrow => :CriticalHAMD,
            :DepressiveEpisode => (x -> count(!ismissing, x)) => :Interviews,
            [:HAMDDate, :DepressiveEpisode] => ((h, e) -> count((h .< Date(now()) - Week(4)) .& ismissing.(e))) => :NoInterviews,
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
            :ManicEpisode => (x -> count(!ismissing, x)) => :Interviews,
            [:YMRSDate, :ManicEpisode] => ((y, e) -> count((y .< Date(now()) - Week(4)) .& ismissing.(e))) => :NoInterviews,
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
            [:DepressiveEpisode, :Dysthymia] => ((de, dy) -> count(de .& .!dy)) => :DepressiveEpisode,
            [:DepressiveEpisode, :Dysthymia] => ((de, dy) -> count(.!de .& dy)) => :Dysthymia,
            [:DepressiveEpisode, :Dysthymia] => ((de, dy) -> count(de .& dy)) => :DoubleDepression,
            :ManicEpisode .=> count;
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
            [:DepressiveEpisode, :Dysthymia] => ((de, dy) -> count(de .& .!dy)) => :DepressiveEpisode,
            [:DepressiveEpisode, :Dysthymia] => ((de, dy) -> count(.!de .& dy)) => :Dysthymia,
            [:DepressiveEpisode, :Dysthymia] => ((de, dy) -> count(de .& dy)) => :DoubleDepression,
            :ManicEpisode .=> count;
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
        EMAIL_CLARIFICATION,
        "CRC393 Clarification",
        html
    )
end

run_script(script, EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER)