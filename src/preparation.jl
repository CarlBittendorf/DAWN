
function prepare_queries_dataset(study_center)
    city = study_center.name

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

    @chain begin
        # contains :Participant, :DateTime, :Variable and :Value columns
        read_dataframe(db, "queries")

        # remove test accounts
        subset(:Participant => ByRow(x -> !(x in TEST_ACCOUNTS)))

        # clean participant ids
        transform(:Participant => ByRow(lstrip); renamecols = false)

        # replace missing with nothing to distinguish unanswered queries from those that were not asked
        transform(:Value => ByRow(x -> ismissing(x) ? nothing : x); renamecols = false)

        # ensure that day counters are assigned to the correct day
        transform([:Variable, :DateTime] => ByRow((v, d) -> v in ["C01DayCounter", "B05DayCounter"] ? floor(d, Day) + Hour(12) : d) => :DateTime)

        # contains :Participant, :DateTime, and variables from VARIABLES_DATABASE
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

        # calculate PHQ-9 and ASRM-5 sum scores
        transform(
            [:PHQ1, :PHQ2, :PHQ3, :PHQ4, :PHQ5, :PHQ6, :PHQ7, :PHQ8, :PHQ9] => ByRow((x...) -> any(isnothing, x) ? missing : +(x...)) => :PHQ9SumScore,
            [:ASRM1, :ASRM2, :ASRM3, :ASRM4, :ASRM5] => ByRow((x...) -> any(isnothing, x) ? missing : +(x...)) => :ASRM5SumScore
        )

        # set missing PHQ-9 and ASRM-5 sum scores to 0 for all rows where :ChronoRecord is not missing
        transform(
            [:ChronoRecord, :PHQ9SumScore] => ByRow((c, s) -> isvalid(c) && ismissing(s) ? 0 : s) => :PHQ9SumScore,
            [:ChronoRecord, :ASRM5SumScore] => ByRow((c, s) -> isvalid(c) && ismissing(s) ? 0 : s) => :ASRM5SumScore
        )

        # parse :FallAsleep and :WakeUp
        transform(
            [:FallAsleep, :WakeUp] .=> ByRow(x -> isvalid(x) ? Time(x) : nothing);
            renamecols = false
        )

        # calculate :SleepDuration
        transform([:FallAsleep, :WakeUp] => ByRow(duration) => :SleepDuration)

        # ensure that :TrainingSuccess and :ExerciseSuccessful are set to nothing if they are not completed during the intervention phase
        transform(
            [:C01DayCounter, :TrainingSuccess] => ByRow((c, t) -> isvalid(c) && c >= 15 && c <= 70 && ismissing(t) ? nothing : t) => :TrainingSuccess,
            [:B05DayCounter, :ExerciseSuccessful] => ByRow((c, e) -> isvalid(c) && c >= 15 && c <= 70 && ismissing(e) ? nothing : e) => :ExerciseSuccessful
        )

        # add :HasMobileSensing and :MobileSensingRunning columns
        leftjoin(df_sensing; on = :Participant)
        leftjoin(df_running; on = [:Participant, :Date])
        transform(
            [:HasMobileSensing, :MobileSensingRunning] .=> ByRow(!ismissing);
            renamecols = false
        )

        sort([:Participant, :Date])
    end
end

function prepare_participants_dataset(study_center, df)
    city = study_center.name

    # connection to database
    db = DuckDB.DB(joinpath("data", city * ".db"))

    # contains :Participant, :InteractionDesignerParticipantUUID, :InteractionDesignerGroup and :StudyCenter columns
    df_participants = read_dataframe(db, "participants")

    # contains :Participant, :IsA06, :IsB01, :IsB03, :IsB05, :IsB07, :IsC01, :IsC02, :IsC03 and :IsC04 columns
    df_subprojects = read_dataframe(db, "subprojects")

    df_diagnoses = @chain begin
        # contains :Participant, :DIPSDate, :DepressiveEpisode and :ManicEpisode columns
        read_dataframe(db, "diagnoses")

        sort(:DIPSDate)

        transform([:DIPSDate, :DepressiveEpisode, :ManicEpisode] => ByRow(Diagnosis) => :Diagnosis)

        # reduce to one row per participant
        groupby(:Participant)
        combine(:Diagnosis => (x -> [[x...]]) => :Diagnoses)
    end

    subprojects = ["A04", "A06", "B01", "B03", "B05", "B07", "C01", "C02", "C03", "C04"]

    @chain df begin
        select(:Participant, :IsA04)

        # reduce to one row per participant
        groupby(:Participant)
        combine(:IsA04 => (x -> coalesce(reverse(x)...)); renamecols = false)

        leftjoin(df_participants; on = :Participant)
        dropmissing(:InteractionDesignerGroup)

        # add :City column and replace missings in :StudyCenter with "???"
        transform(
            All() => ByRow((x...) -> city) => :City,
            :StudyCenter => ByRow(x -> ismissing(x) ? "???" : x);
            renamecols = false
        )

        leftjoin(df_subprojects; on = :Participant)

        # replace missings with false
        transform(
            "Is" .* subprojects .=> ByRow(x -> isvalid(x) ? x : false);
            renamecols = false
        )

        # collect subproject assignments into a vector
        transform("Is" .* subprojects => ByRow((x...) -> subprojects[[x...]]) => :Subprojects)

        leftjoin(df_diagnoses; on = :Participant)

        # replace missings in :Diagnoses with an empty vector
        transform(
            :Diagnoses => ByRow(x -> ismissing(x) ? Diagnosis[] : x);
            renamecols = false
        )
    end
end

function prepare_participant_ids(study_centers = STUDY_CENTERS)
    @chain begin
        vcat((
            begin
                city = study_center.name

                # connection to database
                db = DuckDB.DB(joinpath("data", city * ".db"))

                @chain db begin
                    read_dataframe("participants")

                    # remove test accounts
                    subset(:Participant => ByRow(x -> !(x in TEST_ACCOUNTS)))
                end
            end
        for study_center in study_centers
        )...)

        transform(:Participant => ByRow(clean_participant_id); renamecols = false)
        getproperty(:Participant)
        unique
    end
end