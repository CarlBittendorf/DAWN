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

    # determine participant uuids that are in C01
    participantuuids = @chain begin
        # contains :Participant, :InteractionDesignerParticipantUUID, :InteractionDesignerGroup and :StudyCenter columns
        read_dataframe(db, "participants")

        # remove inactive uuids
        subset(:InteractionDesignerParticipantUUID => ByRow(x -> x in participantuuids))

        subset(:InteractionDesignerGroup => ByRow(startswith("C01")))

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
                [VARIABLE_C01_INTENSE_SAMPLING];
                cutofftime = DateTime(cutoff) + Hour(5) + Minute(30),
                hoursinpast = 14 * 24
            )

            # entries before 05:30 are considered to belong to the previous day
            transform(:DateTime => ByRow(x -> Time(x) <= Time("05:30") ? Date(x) - Day(1) : Date(x)) => :Date)

            # filter participants who finished one or two weeks of intense sampling
            groupby(:Participant)
            subset(
                :Date => (x -> any(isequal(cutoff - Day(1)), x)),
                :Date => (x -> Dates.value(cutoff - minimum(x; init = cutoff)) in [7, 14])
            )

            groupby([:Participant, :Date])
            combine(:Value => (x -> count(!missing, x)) => :Responded)

            groupby(:Participant)
            combine(
                nrow => :Days,
                :Responded => sum;
                renamecols = false
            )

            transform([:Days, :Responded] => ByRow((d, x) -> format_compliance(x / (d * 5))) => :Compliance)
            transform([:Days, :Responded] => ByRow((d, x) -> format_compensation(COMPENSATION_C01_INTENSE_SAMPLING[floor(Int, x / (d * 5) * 100)])) => :Compensation)
        end

        if nrow(df) > 0
            send_feedback_email(
                EMAIL_CREDENTIALS,
                EMAIL_FEEDBACK_C01[city],
                "C01",
                Hyperscript.Node[make_table(df)]
            )
        end

        # training feedback
        df = @chain begin
            download_interaction_designer_variable_values(
                token,
                studyuuid,
                participantuuids,
                [VARIABLE_C01_TRAINING];
                cutofftime = DateTime(cutoff) + Day(1) + Hour(5) + Minute(30),
                hoursinpast = 56 * 24
            )

            # entries before 05:30 are considered to belong to the previous day
            transform(
                :DateTime => ByRow(x -> Time(x) <= Time("05:30") ? Date(x) - Day(1) : Date(x)) => :Date;
                renamecols = false
            )

            # coalesce in case a variable was created multiple times in one day
            groupby([:Participant, :Date])
            combine(All() .=> (x -> coalesce(x...)); renamecols = false)

            # filter participants who finished two, four, six or eight weeks of training
            groupby(:Participant)
            subset(:Date => (x -> Dates.value(cutoff - minimum(x; init = cutoff)) in [
                14, 28, 42, 56]))

            groupby(:Participant)
            transform(:Date => (x -> floor.(Int, Dates.value.(x .- minimum(x; init = cutoff)) ./ 7) .+ 1) => :Week)

            # for each week, calculate the number of days the participant trained
            groupby([:Participant, :Week])
            combine(:Value => (x -> count(!ismissing, x)) => :Responded)

            transform(:Responded => ByRow(x -> COMPENSATION_C01_TRAINING[x]) => :Compensation)

            # calculate the compensation across all weeks so far
            groupby(:Participant)
            transform(:Compensation => sum => :TotalCompensation)

            sort([:Participant, :Week])

            # select the last two weeks of each participant
            groupby([:Participant, :Week])
            subset(:Week => (x -> x .>= maximum(x; init = 8) - 1))
        end

        if nrow(df) > 0
            feedback = @chain df begin
                groupby(:Participant)
                combine(
                    :Week => format_weeks => :Weeks,
                    :Compensation => (x -> format_compensation(first(x))) => :FirstWeek,
                    :Compensation => (x -> format_compensation(last(x))) => :SecondWeek,
                    :Compensation => (x -> format_compensation(sum(x))) => :Sum,
                    :Responded => (x -> format_compliance(sum(x) / 14)) => :Compliance,
                    :TotalCompensation => first;
                    renamecols = false
                )

                make_table
            end

            send_feedback_email(
                EMAIL_CREDENTIALS,
                EMAIL_FEEDBACK_C01[city],
                "C01",
                Hyperscript.Node[feedback]
            )
        end
    end
end

run_script(script, EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER)