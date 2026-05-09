include("../src/main.jl")

function script()
    # read the study center index from command-line arguments
    index = parse(Int, ARGS[1])

    # select the study center based on the provided index
    study_center = STUDY_CENTERS[index]

    # extract the city name from the study center metadata
    city = study_center.name

    # define a cutoff date (7 days ago) for compliance
    cutoff = Date(now()) - Day(7)

    # connection to database
    db = DuckDB.DB(joinpath("data", city * ".db"))

    # contains :Participant, :MovisensXSParticipantID, :Instance and :AssignmentDate columns
    df_movisensxs = read_database(DatabaseMovisensXS, db)

    df_sensing = DataFrame(
        :Participant => get_mobile_sensing_participants(df_movisensxs),
        :HasMobileSensing => true
    )

    df_running = @chain begin
        # contains :Participant and :Date columns
        read_database(DatabaseSensingRunning, db)

        transform(All() => ByRow((x...) -> true) => :MobileSensingRunning)
    end

    projects = ["A04", "A06", "B01", "B03", "B05", "B07", "C01", "C02", "C03", "C04"]

    df = @chain begin
        # contains :Participant, :DateTime, :Variable and :Value columns
        read_database(DatabaseQueries, db)

        # remove test accounts
        subset(:Participant => ByRow(x -> !(x in TEST_ACCOUNTS)))

        subset(:Variable => ByRow(x -> x in ["ChronoRecord", "IsA04"]))

        # remove leading white space
        transform(:Participant => ByRow(lstrip); renamecols = false)

        # entries before 05:30 are considered to belong to the previous day
        transform(:DateTime => ByRow(x -> Time(x) <= Time("05:30") ? Date(x) - Day(1) : Date(x)) => :Date)
        select(Not(:DateTime))

        # reduce to one row per participant per day per variable
        groupby([:Participant, :Date, :Variable])
        combine(All() .=> (x -> coalesce(x...)); renamecols = false)

        # replace missing with nothing to distinguish unanswered queries from those that were not asked
        transform(All() .=> ByRow(x -> ismissing(x) ? nothing : x); renamecols = false)

        unstack(:Variable, :Value; combine = first)

        # parse the values of each variable as its corresponding type
        transform(
            (name => ByRow(x -> !isvalid(x) || typeof(x) == type ? x : parse(type, x))
            for (name, type) in ["ChronoRecord" => Int, "IsA04" => Bool])...;
            renamecols = false
        )

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
        leftjoin(read_database(DatabaseParticipants, db); on = :Participant)
        dropmissing(:InteractionDesignerGroup)

        # add :A06, :B01, :B03, :B05, :B07, :C01, :C02, :C03 and :C04 columns
        leftjoin(read_database(DatabaseSubprojects, db); on = :Participant)
        transform(
            [:A06, :B01, :B03, :B05, :B07, :C01, :C02, :C03, :C04] .=>
                ByRow(x -> !ismissing(x) && x);
            renamecols = false
        )

        subset(:InteractionDesignerGroup => ByRow(x -> !contains(x, "Partner")))

        rename(:IsA04 => :A04)
        transform(:A04 => ByRow(x -> isvalid(x) ? x : false); renamecols = false)
        transform(projects => ByRow((x...) -> projects[[x...]]) => :Projects)
    end

    for (selection, email) in EMAIL_COMPLIANCE_TABLE[city]
        df_project = @chain df begin
            subset(:Projects => ByRow(x -> isempty(selection) || any(p -> p in selection, x)))
            transform(:Projects => ByRow(x -> join(x, ", ")); renamecols = false)

            sort([:S01, :S01Total])

            transform(
                [:S01, :S01Total, :Sensing, :SensingTotal] .=>
                    ByRow(x -> ismissing(x) ? "-" : format_compliance(x));
                renamecols = false
            )

            select(:Participant, :S01, :S01Total, :Sensing, :SensingTotal, :Projects)
        end

        if nrow(df_project) > 0
            html = make_html(
                "Compliance",
                [
                    make_title("Compliance"),
                    make_paragraph(""),
                    make_table(df_project)
                ]
            )

            send_email(
                EMAIL_CREDENTIALS,
                [email, EMAIL_ADDITIONAL_RECEIVERS...],
                "CRC393 Compliance $city",
                html
            )
        end
    end
end

run_script(script, EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER)