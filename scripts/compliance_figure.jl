include("../src/main.jl")

function script()
    df = DataFrame()

    for sc in STUDY_CENTERS
        city = sc.name

        # connection to database
        db = DuckDB.DB(joinpath("data", city * ".db"))

        df_participants = read_dataframe(db, "participants")

        df_center = @chain begin
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

        df = vcat(df, df_center)
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

    html = make_html(
        "Compliance",
        [
            make_title("Compliance"),
            make_paragraph("This is the weekly compliance report for CRC393. The solid lines show the average percentage of ChronoRecord items completed by participants per week, broken down by study center. We selected the ChronoRecord item for calculating compliance because it is crucial for detecting inflection signals, which are fundamental to our study. The dashed line represents the minimum target of 70% compliance."),
            span(style = "padding-top: 60px;"),
            img(
                src = "cid:0",
                style = "max-height: 100%; object-fit: contain; display: block; margin: auto auto;"
            )
        ]
    )

    send_email(EMAIL_CREDENTIALS, EMAIL_COMPLIANCE, "CRC393 Compliance Overview", html, [filename])
end

run_script(script, EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER)