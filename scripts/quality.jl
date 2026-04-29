include("../src/main.jl")

function script()
    participants = prepare_participant_ids()

    df_clarification = download_and_process_redcap(REDCapClarification, participants)

    tables = Hyperscript.Node[]

    function add_table!(tables, paragraph, df)
        nrow(df) > 0 && push!(tables, make_paragraph(paragraph), make_table(df))
    end

    @chain df_clarification begin
        subset([:InflectionDepressionFirstValue, :InflectionManiaFirstValue]
        => ByRow((d, m) -> ismissing(d) && ismissing(m)))

        select(:Participant, :Instance, :HAMD, :HAMDDate)

        add_table!(tables, "Missing information on the inflection signal", _)
    end

    @chain df_clarification begin
        transform([:InflectionDepressionSecondDate, :InflectionManiaSecondDate]
        => ByRow((x...) -> coalesce(x...) + Day(1)) => :SignalDate)
        dropmissing(:SignalDate)

        subset(
            :SignalDate => ByRow(x -> x < Date(now()) - Week(2)),
            :TelephoneReached => ByRow(ismissing)
        )

        select(:Participant, :Instance, :SignalDate)

        add_table!(tables, "No information on whether the participant was reached", _)
    end

    @chain df_clarification begin
        subset([:HAMD, :TelephoneReached]
        => ByRow((h, t) -> !ismissing(h) && (ismissing(t) || !t)))

        select(:Participant, :Instance, :TelephoneReached, :HAMD, :HAMDDate)

        add_table!(tables, "HAM-D without reaching the participant", _)
    end

    @chain df_clarification begin
        subset([:YMRS, :TelephoneReached]
        => ByRow((y, t) -> !ismissing(y) && (ismissing(t) || !t)))

        select(:Participant, :Instance, :TelephoneReached, :YMRS, :YMRSDate)

        add_table!(tables, "YMRS without reaching the participant", _)
    end

    @chain df_clarification begin
        subset([:HAMD, :HAMDDate] => ByRow((h, d) -> !ismissing(h) && ismissing(d)))

        select(:Participant, :Instance, :HAMD, :HAMDDate)

        add_table!(tables, "HAM-D without date", _)
    end

    @chain df_clarification begin
        subset([:YMRS, :YMRSDate] => ByRow((y, d) -> !ismissing(y) && ismissing(d)))

        select(:Participant, :Instance, :YMRS, :YMRSDate)

        add_table!(tables, "YMRS without date", _)
    end

    @chain df_clarification begin
        subset([:HAMD, :TelephoneInterviewer]
        => ByRow((h, i) -> !ismissing(h) && (ismissing(i) || i == "-")))

        select(:Participant, :Instance, :HAMD, :HAMDDate)

        add_table!(tables, "HAM-D without interviewer", _)
    end

    @chain df_clarification begin
        subset([:YMRS, :TelephoneInterviewer]
        => ByRow((y, i) -> !ismissing(y) && (ismissing(i) || i == "-")))

        select(:Participant, :Instance, :YMRS, :YMRSDate)

        add_table!(tables, "YMRS without interviewer", _)
    end

    @chain df_clarification begin
        subset([:DepressiveEpisode, :ManicEpisode] => ByRow((x...) -> any(!ismissing, x)))
        dropmissing([:HAMDDate, :YMRSDate])
        transform([:HAMDDate, :YMRSDate] => ByRow((h, d) -> d - h) => :Difference)
        subset(:Difference => ByRow(x -> x > Day(0)))

        select(:Participant, :Instance, :HAMDDate, :YMRSDate, :Difference, :DIPSDate)

        add_table!(
            tables, "Contradictory information regarding the date of the telephone interview", _)
    end

    @chain df_clarification begin
        subset([:DepressiveEpisode, :ManicEpisode] => ByRow((x...) -> any(!ismissing, x)))
        transform([:HAMDDate, :DIPSDate] => ByRow((h, d) -> d - h) => :Difference)
        subset(:Difference => ByRow(x -> x < Week(2) || x > Week(6)))

        select(:Participant, :Instance, :HAMDDate, :DIPSDate, :Difference)

        add_table!(
            tables, "Unusual time differences between HAM-D date and DIPS", _)
    end

    @chain df_clarification begin
        subset([:DepressiveEpisode, :ManicEpisode] => ByRow((x...) -> any(!ismissing, x)))
        dropmissing(:YMRSDate)
        transform([:YMRSDate, :DIPSDate] => ByRow((h, d) -> d - h) => :Difference)
        subset(:Difference => ByRow(x -> x < Week(2) || x > Week(6)))

        select(:Participant, :Instance, :YMRSDate, :DIPSDate, :Difference)

        add_table!(
            tables, "Unusual time differences between YMRS date and DIPS", _)
    end

    @chain df_clarification begin
        dropmissing(:HAMD)
        subset(
            :HAMD => ByRow(x -> x > 8),
            [:DepressiveEpisode, :ManicEpisode] => ByRow((x...) -> all(ismissing, x)),
            :HAMDDate => ByRow(x -> x < Date(now()) - Week(4))
        )
        sort(:HAMDDate)

        select(:Participant, :Instance, :HAMD, :HAMDDate, :DIPSReached)

        add_table!(tables, "Critical HAM-D without DIPS", _)
    end

    @chain df_clarification begin
        dropmissing(:YMRS)
        subset(
            :YMRS => ByRow(x -> x > 7),
            [:DepressiveEpisode, :ManicEpisode] => ByRow((x...) -> all(ismissing, x)),
            :YMRSDate => ByRow(x -> x < Date(now()) - Week(4))
        )
        sort(:YMRSDate)

        select(:Participant, :Instance, :YMRS, :YMRSDate, :DIPSReached)

        add_table!(tables, "Critical YMRS without DIPS", _)
    end

    html = make_html(
        "Data Quality",
        [
            make_title("Data Quality"),
            make_paragraph(""),
            tables...
        ]
    )

    send_email(
        EMAIL_CREDENTIALS,
        EMAIL_ERROR_RECEIVER,
        "CRC393 Data Quality",
        html
    )
end

run_script(script, EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER)