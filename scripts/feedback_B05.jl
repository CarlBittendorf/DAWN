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

    # determine participant uuids that are in B05
    participantuuids = @chain begin
        # contains :Participant, :InteractionDesignerParticipantUUID, :InteractionDesignerGroup and :StudyCenter columns
        read_dataframe(db, "participants")

        # remove inactive uuids
        subset(:InteractionDesignerParticipantUUID => ByRow(x -> x in participantuuids))

        subset(:InteractionDesignerGroup => ByRow(x -> contains(x, "B05")))

        getproperty(:InteractionDesignerParticipantUUID)
        unique
    end

    if !isempty(participantuuids)
        df = @chain begin
            download_interaction_designer_variable_values(
                token,
                studyuuid,
                participantuuids,
                VARIABLES_B05_INTENSE_SAMPLING;
                cutofftime = DateTime(cutoff) + Hour(5) + Minute(30),
                hoursinpast = 14 * 24
            )

            # entries before 05:30 are considered to belong to the previous day
            transform(:DateTime => ByRow(x -> Time(x) <= Time("05:30") ? Date(x) - Day(1) : Date(x)) => :Date)

            # filter participants who finished 5, 7, or 14 days of B05 intense sampling two days ago
            groupby([:Participant, :Date])
            subset(:Variable => (x -> count(isequal("PercentSocialInteractions"), x) >= 6))

            groupby(:Participant)
            subset(
                :Date => (x -> any(isequal(cutoff - Day(1)), x)),
                :Date => (x -> Dates.value(cutoff - minimum(x; init = cutoff)) in [5, 7, 14]);
                ungroup = false
            )
            transform(:Value => (x -> count(!ismissing, x)) => :Items)

            subset(:Variable => ByRow(isequal("PercentSocialInteractions")))

            groupby([:Participant, :Date])
            combine(
                :Value => (x -> count(!ismissing, x)) => :Responded,
                :Items => (x -> length(x) > 0 ? first(x) : x);
                renamecols = false
            )
        end

        if nrow(df) > 0
            html = Hyperscript.Node[]

            for participant in unique(df.Participant)
                df_participant = subset(df, :Participant => ByRow(isequal(participant)))

                items = first(df_participant.Items)

                df_feedback = @chain df_participant begin
                    select(:Date, :Responded)

                    push!(
                        _,
                        ["Total", sum(_.Responded)];
                        promote = true
                    )
                end

                push!(
                    html,
                    make_paragraph(
                        """$participant
                        Number of completed B01 items: $items"""
                    ),
                    make_table(df_feedback)
                )
            end

            send_feedback_email(
                EMAIL_CREDENTIALS,
                EMAIL_FEEDBACK_B05_C03[city],
                "B05",
                html
            )
        end
    end
end

run_script(script, EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER)