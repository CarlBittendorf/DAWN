include("../src/main.jl")

function script()
    index = parse(Int, only(ARGS))
    sc = STUDY_CENTERS[index]

    city, username, password, clientsecret, studyuuid = sc.name,
    sc.username, sc.password, sc.client_secret, sc.studyuuid

    cutoff = Date(now()) - Day(1)

    # connection to database
    db = DuckDB.DB(joinpath("data", city * ".db"))

    # bearer token, which is valid for five minutes
    token = download_interaction_designer_token(username, password, clientsecret)

    # all current participant uuids in the InteractionDesigner
    participantuuids = download_interaction_designer_participants(token, studyuuid)

    # determine participant uuids that are in B01
    participantuuids = @chain begin
        # contains :Participant, :InteractionDesignerParticipantUUID, :InteractionDesignerGroup and :StudyCenter columns
        read_dataframe(db, "participants")

        # remove inactive uuids
        subset(:InteractionDesignerParticipantUUID => ByRow(x -> x in participantuuids))

        subset(:InteractionDesignerGroup => ByRow(isequal("B01")))

        getproperty(:InteractionDesignerParticipantUUID)
        unique
    end

    if !isempty(participantuuids)
        # intense sampling feedback
        df = @chain begin
            download_interaction_designer_variable_values(
                token,
                studyuuid,
                participantuuids,
                VARIABLES_B01_INTENSE_SAMPLING;
                cutofftime = DateTime(cutoff) + Hour(5) + Minute(30),
                hoursinpast = 14 * 24
            )

            # entries before 05:30 are considered to belong to the previous day
            transform(:DateTime => ByRow(x -> Time(x) <= Time("05:30") ? Date(x) - Day(1) : Date(x)) => :Date)

            # filter participants who finished 5, 7, or 14 days of B01 intense sampling two days ago
            groupby(:Participant)
            subset(
                :Date => (x -> Dates.value(cutoff - minimum(x; init = cutoff)) in [5, 7, 14]);
                ungroup = false
            )
            transform(:Value => (x -> count(!ismissing, x)) => :Items)

            subset(:Variable => ByRow(isequal("NegativeEventIntensityMoment")))

            groupby([:Participant, :Date])
            combine(
                :Value => (x -> count(!ismissing, x)) => :Responded,
                :Items => (x -> length(x) > 0 ? first(x) : x);
                renamecols = false
            )

            transform(:Responded => ByRow(x -> COMPENSATION_B01[min(x, 5)]) => :Compensation)
        end

        if nrow(df) > 0
            html = Hyperscript.Node[]

            for participant in unique(df.Participant)
                df_participant = subset(df, :Participant => ByRow(isequal(participant)))

                items = first(df_participant.Items)
                percentage = format_compliance(items / (73 * nrow(df_participant)))

                df_feedback = @chain df_participant begin
                    select(:Date, :Responded, :Compensation)

                    push!(
                        _,
                        ["Total", sum(_.Responded), sum(_.Compensation)];
                        promote = true
                    )

                    transform(
                        :Compensation => ByRow(format_compensation);
                        renamecols = false
                    )
                end

                push!(
                    html,
                    make_paragraph(
                        """$participant
                        Number of completed B01 items: $items ($percentage%)"""
                    ),
                    make_table(df_feedback)
                )
            end

            send_feedback_email(
                EMAIL_CREDENTIALS,
                EMAIL_FEEDBACK_B01[city],
                "B01",
                html
            )
        end
    end
end

run_script(script, EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER)