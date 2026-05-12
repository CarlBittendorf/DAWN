include("../src/main.jl")

function script()
    participants = prepare_participant_ids()

    df_clarification = download_and_process_redcap(REDCapClarification, participants)

    tables = Hyperscript.Node[]

    function add_table!(tables, paragraph, df)
        nrow(df) > 0 && push!(tables, make_paragraph(paragraph), make_table(df))
    end

    @chain df_clarification begin
        subset(
            [:InflectionDepressionFirstValue, :InflectionManiaFirstValue]
            => ByRow((d, m) -> ismissing(d) && ismissing(m)),
            :TelephoneNoCallNotes => ByRow(!isequal("InvalidSignal"))
        )

        select(:Participant, :Instance, :HAMD, :HAMDDate)

        add_table!(
            tables,
            "Missing information about the inflection signal due to transmission errors",
            _
        )
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

        add_table!(
            tables,
            "No information on whether the participant was reached, \
            even though the inflection signal was sent over two weeks ago \
            (please add this information)",
            _
        )
    end

    @chain df_clarification begin
        dropmissing(:CloseInstanceMania)
        subset(
            :InflectionSignalType => ByRow(isequal("InflectionDepression")),
            :CloseInstanceMania => ByRow(!ismissing)
        )

        select(:Participant, :Instance, :CloseInstanceDepression, :CloseInstanceMania)

        add_table!(
            tables,
            "Depressive inflection signal, but the instance-closing variable for mania is used \
            (please use the variable for depression instead)",
            _
        )
    end

    @chain df_clarification begin
        dropmissing(:CloseInstanceDepression)
        subset(
            :InflectionSignalType => ByRow(isequal("InflectionMania")),
            :CloseInstanceDepression => ByRow(!ismissing)
        )

        select(:Participant, :Instance, :CloseInstanceDepression, :CloseInstanceMania)

        add_table!(
            tables,
            "Manic inflection signal, but the instance-closing variable for depression is used \
            (please use the variable for mania instead)",
            _
        )
    end

    @chain df_clarification begin
        dropmissing(:CloseInstanceDepression)
        subset(
            :CloseInstanceDepression,
            :CloseInstanceDepressionDate => ByRow(ismissing)
        )

        select(:Participant, :Instance)

        add_table!(
            tables,
            "Date of instance closure missing (depressive inflection signals, please add)",
            _
        )
    end

    @chain df_clarification begin
        dropmissing(:CloseInstanceMania)
        subset(
            :CloseInstanceMania,
            :CloseInstanceManiaDate => ByRow(ismissing)
        )

        select(:Participant, :Instance)

        add_table!(
            tables,
            "Date of instance closure missing (manic inflection signals, please add)",
            _
        )
    end

    @chain df_clarification begin
        dropmissing(:CloseInstanceDepression)
        subset(:CloseInstanceDepression => ByRow(!))

        select(:Participant, :Instance, :CloseInstanceDepression, :CloseInstanceMania)

        add_table!(
            tables,
            "The instance closure variable is set to false, \
            but it should only be set to missing for open instances and to true for closed instances \
            (depressive inflection signals, please correct this)",
            _
        )
    end

    @chain df_clarification begin
        dropmissing(:CloseInstanceMania)
        subset(:CloseInstanceMania => ByRow(!))

        select(:Participant, :Instance, :CloseInstanceDepression, :CloseInstanceMania)

        add_table!(
            tables,
            "The instance closure variable is set to false, \
            but it should only be set to missing for open instances and to true for closed instances \
            (manic inflection signals, please correct this)",
            _
        )
    end

    @chain df_clarification begin
        transform([:InflectionDepressionSecondDate, :InflectionManiaSecondDate]
        => ByRow((x...) -> coalesce(x...) + Day(1)) => :SignalDate)
        dropmissing(:SignalDate)

        groupby(:Participant)
        subset(:SignalDate => (x -> map(s -> any(abs.(Dates.value.(x .- s)) .== 1), x)))

        select(:Participant, :Instance, :SignalDate, :TelephoneReached)

        add_table!(
            tables,
            "Instances on consecutive days (please check if this is correct)",
            _
        )
    end

    @chain df_clarification begin
        transform([:InflectionDepressionSecondDate, :InflectionManiaSecondDate]
        => ByRow((x...) -> coalesce(x...) + Day(1)) => :SignalDate)
        dropmissing([:SignalDate, :TelephoneDate])
        transform([:SignalDate, :TelephoneDate] => ByRow((s, t) -> t - s) => :Difference)
        subset(:Difference => ByRow(x -> x < Day(0) || x > Week(2)))

        select(:Participant, :Instance, :SignalDate, :TelephoneDate, :Difference)

        add_table!(
            tables,
            "Unusual time differences between inflection signal and telephone date \
            (please check if this is correct)",
            _
        )
    end

    @chain df_clarification begin
        subset([:HAMD, :TelephoneReached]
        => ByRow((h, t) -> !ismissing(h) && (ismissing(t) || !t)))

        select(:Participant, :Instance, :TelephoneReached, :HAMD, :HAMDDate)

        add_table!(
            tables,
            "HAM-D was conducted, but the participant was reportedly not reached \
            (please add that the participant has been reached)",
            _
        )
    end

    @chain df_clarification begin
        subset([:YMRS, :TelephoneReached]
        => ByRow((y, t) -> !ismissing(y) && (ismissing(t) || !t)))

        select(:Participant, :Instance, :TelephoneReached, :YMRS, :YMRSDate)

        add_table!(
            tables,
            "YMRS was conducted, but the participant was reportedly not reached \
            (please add that the participant has been reached)",
            _
        )
    end

    @chain df_clarification begin
        subset([:HAMD, :HAMDDate] => ByRow((h, d) -> !ismissing(h) && ismissing(d)))

        select(:Participant, :Instance, :HAMD, :HAMDDate)

        add_table!(tables, "HAM-D without date (please add)", _)
    end

    @chain df_clarification begin
        subset([:YMRS, :YMRSDate] => ByRow((y, d) -> !ismissing(y) && ismissing(d)))

        select(:Participant, :Instance, :YMRS, :YMRSDate)

        add_table!(tables, "YMRS without date (please add)", _)
    end

    @chain df_clarification begin
        subset([:HAMD, :TelephoneInterviewer]
        => ByRow((h, i) -> !ismissing(h) && (ismissing(i) || i == "-")))

        select(:Participant, :Instance, :HAMD, :HAMDDate)

        add_table!(tables, "HAM-D without interviewer (please add)", _)
    end

    @chain df_clarification begin
        subset([:YMRS, :TelephoneInterviewer]
        => ByRow((y, i) -> !ismissing(y) && (ismissing(i) || i == "-")))

        select(:Participant, :Instance, :YMRS, :YMRSDate)

        add_table!(tables, "YMRS without interviewer (please add)", _)
    end

    @chain df_clarification begin
        subset(
            :InflectionSignalType => ByRow(isequal("InflectionDepression")),
            :TelephoneReached => ByRow(x -> !ismissing(x) && x),
            [:TelephoneDate, :HAMDDate] => ByRow(!isequal)
        )

        select(:Participant, :Instance, :TelephoneDate, :HAMDDate)

        add_table!(
            tables,
            "Contradictory information regarding the date of the telephone interview \
            (depressive inflection signals, please ensure that both variables contain the correct date)",
            _
        )
    end

    @chain df_clarification begin
        subset(
            :InflectionSignalType => ByRow(isequal("InflectionMania")),
            :TelephoneReached => ByRow(x -> !ismissing(x) && x),
            [:TelephoneDate, :YMRSDate] => ByRow(!isequal)
        )

        select(:Participant, :Instance, :TelephoneDate, :YMRSDate)

        add_table!(
            tables,
            "Contradictory information regarding the date of the telephone interview \
            (manic inflection signals, please ensure that both variables contain the correct date)",
            _
        )
    end

    @chain df_clarification begin
        subset(
            :InflectionSignalType => ByRow(isequal("InflectionDepression")),
            [:DepressiveEpisode, :ManicEpisode] => ByRow((x...) -> any(!ismissing, x))
        )
        transform([:HAMDDate, :DIPSDate] => ByRow((h, d) -> d - h) => :Difference)
        subset(:Difference => ByRow(x -> x < Week(2) || x > Week(6)))

        select(:Participant, :Instance, :HAMDDate, :DIPSDate, :Difference)

        add_table!(
            tables,
            "Unusual time differences between HAM-D date and DIPS (please check if this is correct)",
            _
        )
    end

    @chain df_clarification begin
        subset(
            :InflectionSignalType => ByRow(isequal("InflectionMania")),
            [:DepressiveEpisode, :ManicEpisode] => ByRow((x...) -> any(!ismissing, x))
        )
        dropmissing(:YMRSDate)
        transform([:YMRSDate, :DIPSDate] => ByRow((h, d) -> d - h) => :Difference)
        subset(:Difference => ByRow(x -> x < Week(2) || x > Week(6)))

        select(:Participant, :Instance, :YMRSDate, :DIPSDate, :Difference)

        add_table!(
            tables,
            "Unusual time differences between YMRS date and DIPS (please check if this is correct)",
            _
        )
    end

    @chain df_clarification begin
        dropmissing(:HAMD)
        subset(
            :HAMD => ByRow(x -> x > 8),
            [:DepressiveEpisode, :ManicEpisode] => ByRow((x...) -> all(ismissing, x)),
            :HAMDDate => ByRow(x -> x < Date(now()) - Week(4)),
            :DIPSReached => ByRow(x -> ismissing(x) || x)
        )
        sort(:HAMDDate)

        select(:Participant, :Instance, :HAMD, :HAMDDate, :DIPSReached)

        add_table!(
            tables,
            "Critical HAM-D without DIPS \
            (please conduct the DIPS or mark as not reached for the on-site interview)",
            _
        )
    end

    @chain df_clarification begin
        dropmissing(:YMRS)
        subset(
            :YMRS => ByRow(x -> x > 7),
            [:DepressiveEpisode, :ManicEpisode] => ByRow((x...) -> all(ismissing, x)),
            :YMRSDate => ByRow(x -> x < Date(now()) - Week(4)),
            :DIPSReached => ByRow(x -> ismissing(x) || x)
        )
        sort(:YMRSDate)

        select(:Participant, :Instance, :YMRS, :YMRSDate, :DIPSReached)

        add_table!(
            tables,
            "Critical YMRS without DIPS \
            (please conduct the DIPS or mark as not reached for the on-site interview)",
            _
        )
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