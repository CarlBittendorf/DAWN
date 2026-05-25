include("../src/main.jl")

function script()
    # read the study center index from command-line arguments
    index = parse(Int, only(ARGS))

    # select the study center based on the provided index
    study_center = STUDY_CENTERS[index]

    # extract the city name from the study center metadata
    city = study_center.name

    # prepare the dataset containing the results from the queries
    df = prepare_queries_dataset(study_center)

    ids = @chain df begin
        subset(:IsA04 => ByRow(x -> !ismissing(x) && x))
        getproperty(:Participant)
        unique
    end

    df_phq = @chain df begin
        subset(:Participant => ByRow(x -> x in ids))
        transform(:IsA04 => ByRow(x -> ismissing(x) ? false : x); renamecols = false)

        groupby(:Participant)
        transform(:Date => enumerate_days => :Day)
    end

    df_start = @chain df_phq begin
        groupby(:Participant)
        subset(:Date => (x -> x .== minimum(x)))

        rename(:Date => :StartDate)

        select(:Participant, :StartDate)
    end

    # connection to database
    db = DuckDB.DB(joinpath("data", city * ".db"))

    df_diagnoses = @chain begin
        read_database(DatabaseDiagnoses, db)

        leftjoin(df_start; on = :Participant)
        dropmissing(:StartDate)

        transform([:StartDate, :DIPSDate] => ByRow((s, x) -> Dates.value(x - s) + 1) => :Day)

        select(:Participant, :DIPSDate, :DepressiveEpisode, :Day)
        dropmissing
    end

    df_episodes = subset(df_diagnoses, :DepressiveEpisode)
    df_no_episodes = subset(df_diagnoses, :DepressiveEpisode => ByRow(!))

    df_remissions = @chain begin
        read_database(DatabaseRemissions, db)

        leftjoin(df_start; on = :Participant)
        dropmissing(:StartDate)

        transform([:StartDate, :SymptomRemissionDate] => ByRow((s, x) -> Dates.value(x - s) + 1) => :Day)

        select(:Participant, :SymptomRemissionDate, :Day)
        dropmissing
    end

    folder = mktempdir()
    filename = joinpath(folder, "CRC393 PHQ-9.png")

    figure = draw(
        mapping([10]) * visual(HLines; color = :darkgray, linestyle = :dot) +
        mapping(:Day; layout = :Participant) *
        (
            visual(VLines; linestyle = :dash) *
            (
            data(df_episodes) * visual(; color = RED) +
            data(df_no_episodes) * visual(; color = :darkgray) +
            data(df_remissions) * visual(; color = GREEN)
        )
        ) +
        data(df_phq) * mapping(:Day, :PHQ9SumScore; layout = :Participant) * visual(Lines);
        axis = (; width = 800, height = 400)
    )

    save(filename, figure; px_per_unit = 1)

    title = "PHQ-9 Export"
    html = make_html(
        title,
        [
            make_title(title),
            span(style = "padding-top: 60px;"),
            img(
                src = "cid:0",
                style = "max-height: 100%; object-fit: contain; display: block; margin: auto auto;"
            ),
            make_paragraph("")
        ]
    )

    send_email(EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER, title, html, [filename])
end

run_script(script, EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER)