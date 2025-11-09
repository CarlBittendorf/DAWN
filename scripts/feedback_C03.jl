include("../src/main.jl")

function script()
    index = parse(Int, only(ARGS))
    sc = STUDY_CENTERS[index]

    city, username, password, clientsecret, studyuuid = sc.name,
    sc.username, sc.password, sc.client_secret, sc.studyuuid

    cutoff = Date(now()) - Day(1)

    # connection to database
    db = DuckDB.DB(joinpath("data", city * ".db"))

    # determine participant uuids that are in C03
    participantuuids = @chain begin
        read_dataframe(db, "participants")
        subset(:InteractionDesignerGroup => ByRow(x -> contains(x, "C03")))
        getproperty(:InteractionDesignerParticipantUUID)
        unique
    end

    if !isempty(participantuuids)
        # bearer token, which is valid for five minutes
        token = download_interaction_designer_token(username, password, clientsecret)

        # intense sampling feedback
        df = @chain begin
            download_interaction_designer_variable_values(
                token,
                studyuuid,
                participantuuids,
                VARIABLES_C03_INTERVENTION;
                cutofftime = DateTime(cutoff) + Hour(5) + Minute(30),
                hoursinpast = 56 * 24
            )

            # entries before 05:30 are considered to belong to the previous day
            transform(:DateTime => ByRow(x -> Time(x) <= Time("05:30") ? Date(x) - Day(1) : Date(x)) => :Date)
        end

        participants = @chain df begin
            subset(:Variable => ByRow(isequal("ExerciseSuccessful")))

            # filter participants who finished a multiple of seven days of training
            groupby(:Participant)
            subset(:Date => (x -> Dates.value(cutoff - minimum(x; init = cutoff)) in 7:7:56))

            getproperty(:Participant)
            unique
        end

        if !isempty(participants)
            html = Hyperscript.Node[]

            for participant in participants
                df_feedback = @chain begin
                    subset(df, :Participant => ByRow(isequal(participant)))

                    transform(:Date => (x -> floor.(Int, Dates.value.(x .- minimum(x; init = cutoff)) ./ 7) .+ 1) => :Week)

                    groupby(:Date)
                    combine(
                        [:Variable, :Value] => ((v, x) -> any(v .== "ExerciseSuccessful" .& x .== "1")) => :Exercise,
                        [:Variable, :Value] => ((v, x) -> count(v .== "MDMQContentMoment" .& .!ismissing.(x))) => :EMA;
                        renamecols = false
                    )

                    transform(
                        [:Exercise, :EMA] => ByRow((x, ema) -> x && ema >= 1) => :Compensation,
                        [:Exercise, :EMA] => ByRow((x, ema) -> x && ema >= 3) => :Complete
                    )

                    groupby(:Week)
                    transform(
                        :Complete => (x -> COMPENSATION_C03_EXERCISE[sum(x)]) => :Bonus,
                        :Date => (x -> x .== maximum(x; init = cutoff - Year(1))) => :LastDay
                    )

                    # add the bonus to the last day of the week
                    transform([:Compensation, :Bonus, :LastDay] => ByRow((c, b, l) -> l ? c + b : c) => :Compensation)

                    select(:Week, :Date, :Exercise, :EMA, :Compensation)

                    push!(
                        _,
                        ["Total", "", sum(_.Exercise), sum(_.EMA), sum(_.Compensation)];
                        promote = true
                    )

                    transform(
                        :Compensation => ByRow(format_compensation);
                        renamecols = false
                    )
                end

                push!(
                    html,
                    make_paragraph(participant),
                    make_table(df_feedback)
                )
            end

            send_feedback_email(
                EMAIL_CREDENTIALS,
                EMAIL_FEEDBACK_B05_C03[city],
                "C03",
                html
            )
        end
    end
end

run_script(script, EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER)