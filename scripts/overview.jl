include("../src/main.jl")

function script()
    df = DataFrame()

    for study_center in STUDY_CENTERS
        city = study_center.name

        # connection to database
        db = DuckDB.DB(joinpath("data", city * ".db"))

        df_participants = read_dataframe(db, "participants")

        df_compliance = @chain begin
            # contains :Participant, :DateTime, :Variable and :Value columns
            read_dataframe(db, "queries")

            # remove test accounts
            subset(:Participant => ByRow(x -> !(x in TEST_ACCOUNTS)))

            subset(:Variable => ByRow(isequal("ChronoRecord")))

            # remove data from inactive participants
            leftjoin(df_participants; on = :Participant)
            dropmissing(:InteractionDesignerParticipantUUID)

            # entries before 05:30 are considered to belong to the previous day
            transform(:DateTime => ByRow(x -> Time(x) <= Time("05:30") ? Date(x) - Day(1) : Date(x)) => :Date)

            groupby([:Participant, :Date])
            combine(
                :Value => (x -> coalesce(x...)),
                All() => ((x...) -> city) => :City,
                :StudyCenter => first;
                renamecols = false
            )
        end

        df = vcat(df, df_compliance)
    end

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

    df_figure = @chain df begin
        transform([:City, :StudyCenter] => ByRow((c, sc) -> coalesce(sc, c)) => :StudyCenter)
        dropmissing(:StudyCenter)
        subset(:StudyCenter => ByRow(!isequal("Dresden")))

        groupby([:StudyCenter, :Date])
        combine(
            nrow => :Total,
            :Value => (x -> count(!ismissing, x)) => :Responded
        )

        transform([:Total, :Responded] => ByRow((t, x) -> x / t * 100) => :Compliance)

        subset(:Date => ByRow(x -> x >= Date(now() - Week(10))))
        sort([:StudyCenter, :Date])
    end

    folder = mktempdir()
    filename = joinpath(folder, "Compliance.png")

    figure = draw(
        mapping([70]) * visual(HLines; linestyle = :dash) +
        data(df_figure) *
        mapping(
            :Date,
            :Compliance => "Compliance [%]";
            color = :StudyCenter => "Study Center"
        ) *
        visual(Lines),
        scales(Color = (; palette = PALETTE));
        figure = (; title = "S01 Compliance"),
        axis = (; limits = (nothing, (0, 100)))
    )

    save(filename, figure; px_per_unit = 3)

    tables = Hyperscript.Node[]

    function add_table!(tables, paragraph, df)
        nrow(df) > 0 && push!(tables, make_paragraph(paragraph), make_table(df))
    end

    @chain df_clarification begin
        leftjoin(df_center; on = :Participant)

        dropmissing(:HAMDDate)
        sort([:HAMDDate, :StudyCenter])
        subset(
            :HAMDDate => ByRow(x -> x >= floor(Date(now()) - Month(6), Month)),
            :HAMDDate => ByRow(x -> x <= Date(now()) - Week(2))
        )
        transform(
            :HAMDDate => ByRow(monthname) => :Month,
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
            :StudyCenter => (x -> indexin(x, ["Marburg", "Münster", "Dresden (UKD)", "Dresden (FAL)"])) => :StudyCenterIndex
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

    html = make_html(
        "Overview",
        [
            make_title("Overview"),
            make_paragraph("This is the weekly compliance report for CRC393. The solid lines show the average percentage of ChronoRecord items completed by participants per week, broken down by study center. We selected the ChronoRecord item for calculating compliance because it is crucial for detecting inflection signals, which are fundamental to our study. The dashed line represents the minimum target of 70% compliance."),
            span(style = "padding-top: 60px;"),
            img(
                src = "cid:0",
                style = "max-height: 100%; object-fit: contain; display: block; margin: auto auto;"
            ),
            make_paragraph(""),
            tables...
        ]
    )

    send_email(
        EMAIL_CREDENTIALS,
        EMAIL_OVERVIEW,
        "CRC393 Overview",
        html,
        [filename]
    )
end

run_script(script, EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER)