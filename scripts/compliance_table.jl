include("../src/main.jl")

function script()
    index = parse(Int, only(ARGS))
    sc = STUDY_CENTERS[index]

    city = sc.name

    cutoff = Date(now()) - Day(7)

    # connection to database
    db = DuckDB.DB(joinpath("data", city * ".db"))

    # contains :Participant, :MovisensXSParticipantID, :Instance and :AssignmentDate columns
    df_movisensxs = read_dataframe(db, "movisensxs")

    df_sensing = DataFrame(
        :Participant => get_mobile_sensing_participants(df_movisensxs),
        :HasMobileSensing => true
    )

    df_running = @chain begin
        # contains :Participant and :Date columns
        read_dataframe(db, "running")

        transform(All() => ByRow((x...) -> true) => :MobileSensingRunning)
    end

    projects = ["A04", "A06", "B01", "B03", "B05", "B07", "C01", "C02", "C03", "C04"]

    df = @chain begin
        # contains :Participant, :DateTime, :Variable and :Value columns
        read_dataframe(db, "queries")

        # remove test accounts
        subset(:Participant => ByRow(x -> !(x in TEST_ACCOUNTS)))

        subset(:Variable => ByRow(x -> x in ["ChronoRecord", "IsA04"]))

        # replace missing with nothing to distinguish unanswered queries from those that were not asked
        transform(All() .=> ByRow(x -> ismissing(x) ? nothing : x); renamecols = false)

        unstack(:Variable, :Value; combine = first)

        # entries before 05:30 are considered to belong to the previous day
        transform(:DateTime => ByRow(x -> Time(x) <= Time("05:30") ? Date(x) - Day(1) : Date(x)) => :Date)
        select(Not(:DateTime))

        # parse the values of each variable as its corresponding type
        transform(
            (name => ByRow(x -> !isvalid(x) || typeof(x) == type ? x : parse(type, x))
            for (name, type) in ["ChronoRecord" => Int, "IsA04" => Bool])...;
            renamecols = false
        )

        # reduce to one row per participant per day
        groupby([:Participant, :Date])
        combine(All() .=> (x -> coalesce(x...)); renamecols = false)

        # use only participants who are still active
        groupby(:Participant)
        subset(:Date => (x -> any(isequal(cutoff + Day(6)), x)); ungroup = false)
        transform(:Date => (x -> Dates.value.(x .- minimum(x; init = cutoff + Day(6))) .+ 1) => :Day)

        # add :HasMobileSensing and :MobileSensingRunning columns
        leftjoin(df_sensing; on = :Participant)
        leftjoin(df_running; on = [:Participant, :Date])
        transform(
            [:HasMobileSensing, :MobileSensingRunning] .=> ByRow(!ismissing);
            renamecols = false
        )

        sort([:Participant, :Date])

        groupby(:Participant)
        combine(
            [:ChronoRecord, :Date] => ((x, d) -> mean(isvalid.(x[d .>= cutoff]))) => :S01,
            :ChronoRecord => (x -> mean(isvalid.(x))) => :S01Total,
            [:HasMobileSensing, :MobileSensingRunning, :Date] => ((s, r, d) -> last(s) ? mean(r[d .>= cutoff]) : missing) => :Sensing,
            [:HasMobileSensing, :MobileSensingRunning] => ((s, r) -> last(s) ? mean(r) : missing) => :SensingTotal,
            :IsA04 => (x -> coalesce(reverse(x)...));
            renamecols = false
        )

        # add :InteractionDesignerParticipantUUID, :InteractionDesignerGroup and :StudyCenter columns
        leftjoin(read_dataframe(db, "participants"); on = :Participant)
        dropmissing(:InteractionDesignerGroup)

        # add :IsA06, :IsB01, :IsB03, :IsB05, :IsB07, :IsC01, :IsC02, :IsC03 and :IsC04 columns
        leftjoin(read_dataframe(db, "subprojects"); on = :Participant)
        transform(
            [:IsA06, :IsB01, :IsB03, :IsB05, :IsB07, :IsC01, :IsC02, :IsC03, :IsC04] .=>
                ByRow(x -> !ismissing(x) && x);
            renamecols = false
        )

        subset(:InteractionDesignerGroup => ByRow(x -> !contains(x, "Partner")))

        transform(:IsA04 => ByRow(x -> isvalid(x) ? x : false); renamecols = false)
        transform("Is" .* projects => ByRow((x...) -> join(projects[[x...]], ", ")) => :Projects)

        sort([:S01, :S01Total])

        transform(
            [:S01, :S01Total, :Sensing, :SensingTotal] .=>
                ByRow(x -> ismissing(x) ? "-" : format_compliance(x));
            renamecols = false
        )

        select(:Participant, :S01, :S01Total, :Sensing, :SensingTotal, :Projects)
    end

    html = make_html(
        "Compliance",
        [
            make_title("Compliance"),
            make_paragraph(""),
            make_table(df)
        ]
    )

    send_email(EMAIL_CREDENTIALS, EMAIL_FEEDBACK_S01[city], "CRC393 Compliance $city", html)
end

run_script(script, EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER)