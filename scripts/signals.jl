include("../src/main.jl")

function script()
    index = parse(Int, only(ARGS))
    sc = STUDY_CENTERS[index]

    city = sc.name

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

    df_diagnoses = @chain begin
        # contains :Participant, :DIPSDate, :DepressiveEpisode and :ManicEpisode columns
        read_dataframe(db, "diagnoses")

        sort([:Participant, :DIPSDate])
        transform(:DIPSDate => ByRow(identity) => :Date)
        fill_dates
        transform(
            [:DIPSDate, :DepressiveEpisode, :ManicEpisode] .=> fill_down;
            renamecols = false
        )
    end

    ####################################################################################################
    # PREPARE DATASET
    ####################################################################################################

    df_data = @chain begin
        # contains :Participant, :DateTime, :Variable and :Value columns
        read_dataframe(db, "queries")

        # remove test accounts
        subset(:Participant => ByRow(x -> !(x in TEST_ACCOUNTS)))

        # replace missing with nothing to distinguish unanswered queries from those that were not asked
        transform(All() .=> ByRow(x -> ismissing(x) ? nothing : x); renamecols = false)

        unstack(:Variable, :Value; combine = first)

        # entries before 05:30 are considered to belong to the previous day
        transform(:DateTime => ByRow(x -> Time(x) <= Time("05:30") ? Date(x) - Day(1) : Date(x)) => :Date)
        select(Not(:DateTime))

        # add variables that are not yet present in the dataframe
        transform(
            _,
            (All() => ((x...) -> missing) => name
            for name in filter(
                x -> !(x in names(_)),
                unique(getproperty.(VARIABLES_DATABASE, :name))
            ))...
        )

        # parse the values of each variable as its corresponding type
        transform(
            (name => ByRow(x -> !isvalid(x) || typeof(x) == type ? x : parse(type, x))
            for (name, type) in unique(
                getproperty.(VARIABLES_DATABASE, :name) .=>
                getproperty.(VARIABLES_DATABASE, :type)
            ))...;
            renamecols = false
        )

        # reduce to one row per participant per day
        groupby([:Participant, :Date])
        combine(
            [:NegativeEventIntensityMoment, :PercentSocialInteractions] .=>
                (x -> any(!ismissing, x) ? Ref(collect(skipmissing(x))) : missing),
            Not(:NegativeEventIntensityMoment, :PercentSocialInteractions) .=>
                (x -> coalesce(x...));
            renamecols = false
        )

        transform(
            [:PHQ1, :PHQ2, :PHQ3, :PHQ4, :PHQ5, :PHQ6, :PHQ7, :PHQ8, :PHQ9] => ByRow((x...) -> any(isnothing, x) ? missing : +(x...)) => :PHQ9SumScore,
            [:ASRM1, :ASRM2, :ASRM3, :ASRM4, :ASRM5] => ByRow((x...) -> any(isnothing, x) ? missing : +(x...)) => :ASRM5SumScore
        )

        # set missing PHQ-9 and ASRM-5 sum scores to 0 for all rows where ChronoRecord is not missing
        transform(
            [:ChronoRecord, :PHQ9SumScore] => ByRow((c, s) -> isvalid(c) && ismissing(s) ? 0 : s) => :PHQ9SumScore,
            [:ChronoRecord, :ASRM5SumScore] => ByRow((c, s) -> isvalid(c) && ismissing(s) ? 0 : s) => :ASRM5SumScore
        )

        transform(
            [:FallAsleep, :WakeUp] .=> ByRow(x -> isvalid(x) ? Time(x) : nothing);
            renamecols = false
        )
        transform([:FallAsleep, :WakeUp] => ByRow((a, w) -> isvalid(a) && isvalid(w) ? duration(a, w) : nothing) => :SleepDuration)

        transform([:B05DayCounter, :ExerciseSuccessful] => ByRow((c, e) -> isvalid(c) && c >= 15 && c <= 70 && ismissing(e) ? nothing : e) => :ExerciseSuccessful)

        # add :City column
        transform(All() => ((x...) -> city) => :City)

        # add :InteractionDesignerParticipantUUID, :InteractionDesignerGroup and :StudyCenter columns
        leftjoin(read_dataframe(db, "participants"); on = :Participant)
        dropmissing(:InteractionDesignerGroup)

        # add :HasMobileSensing and :MobileSensingRunning columns
        leftjoin(df_sensing; on = :Participant)
        leftjoin(df_running; on = [:Participant, :Date])
        transform(
            [:HasMobileSensing, :MobileSensingRunning] .=> ByRow(!ismissing);
            renamecols = false
        )

        # add :DIPSDate, :DepressiveEpisode and :ManicEpisode columns
        leftjoin(df_diagnoses; on = [:Participant, :Date])
        transform(
            [:DepressiveEpisode, :ManicEpisode] .=> ByRow(x -> !ismissing(x) && x);
            renamecols = false
        )

        # add :IsA06, :IsB01, :IsB03, :IsB05, :IsB07, :IsC01, :IsC02, :IsC03 and :IsC04 columns
        leftjoin(read_dataframe(db, "subprojects"); on = :Participant)
        transform(
            [:IsA06, :IsB01, :IsB03, :IsB05, :IsB07, :IsC01, :IsC02, :IsC03, :IsC04] .=>
                ByRow(x -> !ismissing(x) && x);
            renamecols = false
        )

        sort([:Participant, :Date])
    end

    ####################################################################################################
    # DETECT SIGNALS
    ####################################################################################################

    signals = determine_signals(df_data, SIGNALS; cutoff = Date(now()) - Day(1))

    upload_redcap_signals(REDCAP_API_TOKEN_1308, signals)

    receivers = @chain signals begin
        @. receiver
        vcat(_...)
        unique
    end

    for email in receivers
        strings = @chain signals begin
            filter(
                x -> email == receiver(x) ||
                    (receiver(x) isa Vector && email in receiver(x)),
                _
            )
            @. format_signal
        end

        if email isa String
            send_signals_email(
                EMAIL_CREDENTIALS,
                [email, EMAIL_ADDITIONAL_RECEIVERS...],
                city,
                strings
            )
        else
            send_signals_email(EMAIL_CREDENTIALS, EMAIL_ADDITIONAL_RECEIVERS, city, strings)
        end
    end
end

run_script(script, EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER)