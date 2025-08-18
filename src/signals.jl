
function initial(df, cutoff)
    dates = dropmissing(df, :ChronoRecord).Date

    if length(dates) == 1 && only(dates) == cutoff
        return (;
            Initial = true,
            InitialDate = cutoff,
            InitialHasMobileSensing = last(df.HasMobileSensing),
            InitialMobileSensingRunning = last(df.MobileSensingRunning),
            InitialSubproject = last(df.InteractionDesignerGroup)
        )
    end
end

function inflection_depression(df, cutoff)
    df_phq = @chain df begin
        lastdays(4, cutoff)
        dropmissing(:PHQ9TotalScore)
        sort(:Date)
        last(2)
    end

    if nrow(df_phq) == 2 && last(df_phq.Date) == cutoff &&
       all(x -> x >= 10, df_phq.PHQ9TotalScore)
        return (;
            InflectionDepression = true,
            InflectionDepressionFirstDate = df_phq.Date[1],
            InflectionDepressionSecondDate = df_phq.Date[2],
            InflectionDepressionFirstValue = df_phq.PHQ9TotalScore[1],
            InflectionDepressionSecondValue = df_phq.PHQ9TotalScore[2]
        )
    end
end

function inflection_mania(df, cutoff)
    df_asrm = @chain df begin
        lastdays(4, cutoff)
        dropmissing(:ASRM5TotalScore)
        sort(:Date)
        last(2)
    end

    if nrow(df_asrm) == 2 && last(df_asrm.Date) == cutoff &&
       all(x -> x >= 6, df_asrm.ASRM5TotalScore)
        return (;
            InflectionMania = true,
            InflectionManiaFirstDate = df_asrm.Date[1],
            InflectionManiaSecondDate = df_asrm.Date[2],
            InflectionManiaFirstValue = df_asrm.ASRM5TotalScore[1],
            InflectionManiaSecondValue = df_asrm.ASRM5TotalScore[2]
        )
    end
end

function expectation(df, cutoff)
    df_expectation = @chain df begin
        lastdays(15, cutoff)
        dropmissing(:Expectation)
        last(2)
    end

    if nrow(df_expectation) == 2 && last(df_expectation.Date) == cutoff &&
       only(diff(df_expectation.Expectation)) >= 3
        return (;
            Expectation = true,
            ExpectationFirstDate = df_expectation.Date[1],
            ExpectationSecondDate = df_expectation.Date[2],
            ExpectationFirstValue = df_expectation.Expectation[1],
            ExpectationSecondValue = df_expectation.Expectation[2]
        )
    end
end

function stressful_life_event(df, cutoff)
    df_sle = @chain df begin
        lastdays(1, cutoff)
        dropmissing(:Influence)
    end

    if nrow(df_sle) == 1 && only(df_sle.Influence) == 3
        return (;
            StressfulLifeEvent = true,
            StressfulLifeEventDate = only(df_sle.Date)
        )
    end
end

function missing_chrono_record(df, cutoff)
    if isalarm((x, i) -> count(ismissing, x[max(1, i - 3):i]) >= 2 && ismissing(x[i]),
        df, :ChronoRecord, cutoff, 4)
        indices = findall(ismissing, last(df.ChronoRecord, 4))
        dates = last(df.Date, 4)[indices]
        a04 = length(collect(skipmissing(df.IsA04))) >= 1 &&
              last(collect(skipmissing(df.IsA04)))
        intense_sampling = last(df.EventNegative) isa Vector ||
                           last(df.SocialInteractions) isa Vector

        return (;
            MissingChronoRecord = true,
            MissingChronoRecordFirstDate = dates[1],
            MissingChronoRecordSecondDate = dates[2],
            MissingChronoRecordThirdDate = length(dates) >= 3 ? dates[3] : missing,
            MissingChronoRecordFourthDate = length(dates) == 4 ? dates[4] : missing,
            MissingChronoRecordA04 = a04,
            MissingChronoRecordIntenseSampling = intense_sampling
        )
    end
end

function missing_mobile_sensing(df, cutoff)
    if isalarm((x, i) -> count(.!x[max(1, i - 6):i]) == 7,
        subset(df, :HasMobileSensing), :MobileSensingRunning, cutoff, 7)
        a04 = length(collect(skipmissing(df.IsA04))) >= 1 &&
              last(collect(skipmissing(df.IsA04)))
        intense_sampling = last(df.EventNegative) isa Vector ||
                           last(df.SocialInteractions) isa Vector

        return (;
            MissingMobileSensing = true,
            MissingMobileSensingDate = cutoff,
            MissingMobileSensingA04 = a04,
            MissingMobileSensingIntenseSampling = intense_sampling
        )
    end
end

function missing_exercise(df, cutoff)
    if isalarm((x, i) -> count(ismissing, x[max(1, i - 1):i]) == 2 && ismissing(x[i]),
        df, :ExerciseSuccessful, cutoff, 2)
        return (;
            MissingExercise = true,
            MissingExerciseDate = cutoff
        )
    end
end

function missing_intense_sampling(df, cutoff)
    if nrow(df) >= 1
        group = last(df.InteractionDesignerGroup)

        if group in ["B01", "C01 Cognition", "C01 Emotion"]
            alarm = isalarm(
                (x, i) -> x[i] isa Vector &&
                              length(x[i]) == 5 &&
                              all(ismissing, replace(x[i], typemax(Int32) => missing)),
                df, :EventNegative, cutoff, 2
            )
        elseif group in ["B05/C03 Mindfulness", "B05/C03 PSAT",
            "Partner B05/C03 Mindfulness", "Partner B05/C03 PSAT"]
            alarm = isalarm(
                (x, y, i) -> x[i] isa Vector &&
                                 length(x[i]) in [2, 4] &&
                                 all(ismissing, replace(x[i], typemax(Int32) => missing)) &&
                                 ismissing(y[i]),
                df, [:SocialInteractions, :SocialContact], cutoff, 2
            )
        end

        if alarm
            return (;
                MissingIntenseSampling = true,
                MissingIntenseSamplingDate = cutoff
            )
        end
    end
end

function missing_questions_problems(df, cutoff)
    if nrow(df) >= 1 && last(df.Date) == cutoff
        missings = nrow(df) >= 2 && all(ismissing, last(df.ExerciseSuccessful, 2))
        problems = !ismissing(last(df.TrainingProblems)) && last(df.TrainingProblems)
        questions = !ismissing(last(df.TrainingQuestions)) && last(df.TrainingQuestions)

        if any([missings, problems, questions])
            return (;
                MissingQuestionsProblems = true,
                MissingQuestionsProblemsDate = cutoff,
                MissingQuestionsProblemsMissing = missings,
                MissingQuestionsProblemsQuestions = problems,
                MissingQuestionsProblemsProblems = questions
            )
        end
    end
end

function substance_more(df, cutoff)
    substance = @chain df begin
        subset(:IsA06)
        lastdays(1, cutoff)
        getproperty(:SubstanceMore)
    end

    if length(substance) == 1 && !ismissing(only(substance)) && only(substance) > 75
        return (;
            SubstanceMore = true,
            SubstanceMoreDate = cutoff,
            SubstanceMoreValue = only(substance)
        )
    end
end

function social_interaction_more(df, cutoff)
    interaction = @chain df begin
        subset(:IsA06)
        lastdays(4, cutoff)
        getproperty(:SocialInteractionMore)
    end

    if length(interaction) == 4 && any(!ismissing, interaction)
        avg = mean(skipmissing(interaction))

        if avg < 25 || avg > 75
            return (;
                SocialInteractionMore = true,
                SocialInteractionMoreDate = cutoff,
                SocialInteractionMoreValue = avg
            )
        end
    end
end

function medication(df, cutoff)
    medication = @chain df begin
        subset(:IsA06)
        lastdays(1, cutoff)
        getproperty(:Medication)
    end

    if length(medication) == 1 && !ismissing(medication)
        return (;
            Medication = true,
            MedicationDate = cutoff,
            MedicationValue = medication
        )
    end
end

function sleep_duration(df, cutoff)
    df_sleep = subset(df, :IsA06)

    if nrow(df_sleep) >= 28 && last(df_sleep.Date) == cutoff
        outside = statistical_process_control(df_sleep, :SleepDuration)

        if last(outside)
            return (;
                SleepDuration = true,
                SleepDurationDate = cutoff
            )
        end
    end
end

function sleep_quality(df, cutoff)
    df_sleep = subset(df, :IsA06)

    if nrow(df_sleep) >= 28 && last(df_sleep.Date) == cutoff
        outside = statistical_process_control(df_sleep, :SleepQuality)

        if last(outside)
            return (;
                SleepQuality = true,
                SleepQualityDate = cutoff
            )
        end
    end
end

# TODO: implement remaining signal
function early_awakening(df, cutoff)
    return nothing
end

function remission_depression(df, cutoff)
    df_a04 = @chain df begin
        select(:Date, :IsA04)
        dropmissing
    end

    if nrow(df_a04) >= 1 && last(df_a04.IsA04)
        index = findprev(.!df_a04.IsA04, nrow(df_a04))

        if isnothing(index)
            index = 1
        end

        if cutoff - df_a04.Date[index] >= Day(56)
            df_phq = @chain df begin
                lastdays(14, cutoff)
                dropmissing(:PHQ9TotalScore)
                sort(:Date)
            end

            if nrow(df_phq) >= 1 &&
               count(x -> x < 10, df_phq.PHQ9TotalScore) >= nrow(df_phq) / 2
                return (;
                    RemissionDepression = true,
                    RemissionDepressionFirstDate = first(df_phq.Date),
                    RemissionDepressionLastDate = last(df_phq.Date)
                )
            end
        end
    end
end

function symptom_remission(df, cutoff)
    df_remission = subset(df, :DepressiveEpisode)

    if nrow(df_remission) >= 53
        symptom_free = @chain df_remission begin
            transform(:PHQ9TotalScore => is_symptom_free => :SymptomFree)

            # only consider days since the last diagnosis
            subset([:Date, :DIPSDate] => ((d, x) -> d .>= last(x)))

            # only consider entries since the last non-symptom-free day
            subset(:SymptomFree => (x -> map(i -> all(x[i:end]), eachindex(x))))

            getproperty(:SymptomFree)
        end

        if length(symptom_free) == 53 && all(symptom_free)
            return (;
                SymptomRemission = true,
                SymptomRemissionDate = cutoff
            )
        end
    end
end