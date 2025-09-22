include("../src/main.jl")

using AlgebraOfGraphics, CairoMakie

set_aog_theme!()

function script()
    df = @chain begin
        vcat((
            begin
                city = sc.name

                # connection to database
                db = DuckDB.DB(joinpath("data", city * ".db"))

                df_participants = read_dataframe(db, "participants")

                # interaction designer ids
                participants = unique(df_participants.Participant)

                df_participants = @chain REDCAP_API_TOKEN_1376 begin
                    download_redcap_participants(participants)

                    # consider only the most recent entry for each participant
                    groupby(:Participant)
                    subset(:Instance => (x -> x .== maximum(x)))

                    rightjoin(df_participants; on = :Participant)

                    transform(:LocationDresden => ByRow(x -> ismissing(x) ? city : "Dresden ($x)") => :StudyCenter)
                end

                @chain db begin
                    read_dataframe("data")

                    leftjoin(df_participants; on = :Participant)

                    subset(
                        :InteractionDesignerGroup => ByRow(x -> x in ["S01", "B01",
                            "C01 Cognition", "C01 Emotion", "B05/C03 Mindfulness", "B05/C03 PSAT"]),

                        # remove test accounts
                        :Participant => ByRow(x -> !(x in TEST_ACCOUNTS))
                    )
                    transform(
                        :Date => ByRow(x -> floor(x, Week));
                        renamecols = false
                    )
                    dropmissing(:StudyCenter)
                    subset(:StudyCenter => ByRow(!isequal("Dresden")))

                    groupby([:StudyCenter, :Date])
                    combine(
                        nrow => :Total,
                        :ChronoRecord => (x -> count(ismissing, x)) => :Missing
                    )

                    transform([:Total, :Missing] => ByRow((t, m) -> (t - m) / t * 100) => :Compliance)
                end
            end
        for sc in STUDY_CENTERS
        )...)

        subset(:Date => ByRow(x -> x >= Date("2025-07-21")))
        sort([:StudyCenter, :Date])
    end

    folder = mktempdir()
    filename = joinpath(folder, "Compliance.png")

    figure = draw(
        mapping([70]) * visual(HLines; linestyle = :dash) +
        data(df) *
        mapping(
            :Date,
            :Compliance => "Compliance [%]";
            color = :StudyCenter => "Study Center"
        ) *
        visual(Lines),
        scales(Color = (; palette = PALETTE));
        axis = (title = "S01 Compliance", limits = (nothing, (0, 100)))
    )

    save(filename, figure; px_per_unit = 3)

    send_compliance_email(EMAIL_CREDENTIALS, EMAIL_COMPLIANCE_RECEIVERS, [filename])
end

run_script(script, EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER)