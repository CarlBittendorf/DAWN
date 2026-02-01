
abstract type AbstractSignal end

const SIGNALS = [
    :Initial, :InflectionDepression, :InflectionMania, :Expectation, :StressfulLifeEvent,
    :MissingIntenseSampling, :MissingQuestionsProblems, :MissingExercise,
    :SubstanceMore, :SocialInteractionMore, :Medication, :SleepDuration,
    :SleepQuality, :EarlyAwakening, :RemissionDepression, :SymptomRemission
]

# define types via metaprogramming to avoid repetitive code
for signal in SIGNALS
    @eval struct $signal <: AbstractSignal
        participant::String
        group::String
        city::String
        study_center::String
        a04::Bool
        a06::Bool
        b01::Bool
        b07::Bool
        intense_sampling::Bool
        data::Vector{Pair{String, Any}}

        function $signal(df::DataFrame, data::Vector{Pair{String, Any}})
            return new(
                last(df.Participant),
                last(df.InteractionDesignerGroup),
                last(df.City),
                last_valid(df, :StudyCenter, "???"),
                last_valid(df, :IsA04, false),
                last_valid(df, :IsA06, false),
                last_valid(df, :IsB01, false),
                last_valid(df, :IsB07, false),
                last(df.NegativeEventIntensityMoment) isa Vector ||
                last(df.PercentSocialInteractions) isa Vector,
                data
            )
        end
    end
end

function check_signal(::Type{Initial}, df, cutoff)
    dates = @chain df begin
        dropmissing(:ChronoRecord)
        subset(:ChronoRecord => ByRow(!isnothing))
        getproperty(:Date)
    end

    if length(dates) == 1 && only(dates) == cutoff
        return Initial(
            df,
            [
                "InitialDate" => cutoff,
                "InitialHasMobileSensing" => last(df.HasMobileSensing),
                "InitialMobileSensingRunning" => last(df.MobileSensingRunning),
                "InitialSubproject" => last(df.InteractionDesignerGroup)
            ]
        )
    end
end

function check_signal(::Type{InflectionDepression}, df, cutoff)
    df_phq = @chain df begin
        lastdays(4, cutoff)
        dropmissing(:PHQ9SumScore)
        sort(:Date)
        last(2)
    end

    if nrow(df_phq) == 2 &&
       last(df_phq.Date) == cutoff &&
       all(x -> x >= 10, df_phq.PHQ9SumScore)
        return InflectionDepression(
            df,
            [
                "InflectionDepressionFirstDate" => df_phq.Date[1],
                "InflectionDepressionSecondDate" => df_phq.Date[2],
                "InflectionDepressionFirstValue" => df_phq.PHQ9SumScore[1],
                "InflectionDepressionSecondValue" => df_phq.PHQ9SumScore[2]
            ]
        )
    end
end

function check_signal(::Type{InflectionMania}, df, cutoff)
    df_asrm = @chain df begin
        lastdays(4, cutoff)
        dropmissing(:ASRM5SumScore)
        sort(:Date)
        last(2)
    end

    if nrow(df_asrm) == 2 &&
       last(df_asrm.Date) == cutoff &&
       all(x -> x >= 6, df_asrm.ASRM5SumScore)
        return InflectionMania(
            df,
            [
                "InflectionManiaFirstDate" => df_asrm.Date[1],
                "InflectionManiaSecondDate" => df_asrm.Date[2],
                "InflectionManiaFirstValue" => df_asrm.ASRM5SumScore[1],
                "InflectionManiaSecondValue" => df_asrm.ASRM5SumScore[2]
            ]
        )
    end
end

function check_signal(::Type{Expectation}, df, cutoff)
    df_expectation = @chain df begin
        lastdays(15, cutoff)
        dropmissing(:ExpectationMentalHealthProblems)
        subset(:ExpectationMentalHealthProblems => ByRow(!isnothing))
        last(2)
    end

    if nrow(df_expectation) == 2 &&
       last(df_expectation.Date) == cutoff &&
       only(diff(df_expectation.ExpectationMentalHealthProblems)) >= 3
        return Expectation(
            df,
            [
                "ExpectationFirstDate" => df_expectation.Date[1],
                "ExpectationSecondDate" => df_expectation.Date[2],
                "ExpectationFirstValue" => df_expectation.ExpectationMentalHealthProblems[1],
                "ExpectationSecondValue" => df_expectation.ExpectationMentalHealthProblems[2]
            ]
        )
    end
end

function check_signal(::Type{StressfulLifeEvent}, df, cutoff)
    df_sle = @chain df begin
        lastdays(1, cutoff)
        dropmissing(:MajorLifeEventInfluence)
        subset(:MajorLifeEventInfluence => ByRow(!isnothing))
    end

    if nrow(df_sle) == 1 && only(df_sle.MajorLifeEventInfluence) == 3
        return StressfulLifeEvent(
            df,
            Pair{String, Any}["StressfulLifeEventDate" => only(df_sle.Date)]
        )
    end
end

function check_signal(::Type{MissingIntenseSampling}, df, cutoff)
    if nrow(df) >= 1
        group = last(df.InteractionDesignerGroup)

        if group in ["B01", "C01 Cognition", "C01 Emotion"]
            alarm = isalarm(
                (x, i) -> x[i] isa Vector && length(x[i]) == 5 && all(isnothing, x[i]),
                df, :NegativeEventIntensityMoment, cutoff, 2
            )
        elseif startswith(group, "B05/C03")
            alarm = isalarm(
                (x, y, i) -> x[i] isa Vector && length(x[i]) == 6 &&
                                 all(isnothing, x[i]) && isnothing(y[i]),
                df, [:PercentSocialInteractions, :SocialContact], cutoff, 2
            )
        else
            return nothing
        end

        if alarm
            return MissingIntenseSampling(
                df,
                Pair{String, Any}["MissingIntenseSamplingDate" => cutoff]
            )
        end
    end
end

function check_signal(::Type{MissingQuestionsProblems}, df, cutoff)
    if nrow(df) >= 1 &&
       startswith(last(df.InteractionDesignerGroup), "C01") &&
       last(df.Date) == cutoff
        missings = nrow(df) >= 2 && all(isnothing, last(df.TrainingSuccess, 2))
        problems = isvalid(last(df.TrainingProblems)) && last(df.TrainingProblems) != 0
        questions = isvalid(last(df.TrainingQuestions)) && last(df.TrainingQuestions) == 1

        if any([missings, problems, questions])
            return MissingQuestionsProblems(
                df,
                [
                    "MissingQuestionsProblemsDate" => cutoff,
                    "MissingQuestionsProblemsMissing" => missings,
                    "MissingQuestionsProblemsQuestions" => problems,
                    "MissingQuestionsProblemsProblems" => questions
                ]
            )
        end
    end
end

function check_signal(::Type{MissingExercise}, df, cutoff)
    if nrow(df) >= 1 &&
       contains(last(df.InteractionDesignerGroup), "B05/C03") &&
       isalarm(
           (x, i) -> count(isnothing, x[max(1, i - 1):i]) == 2 && isnothing(x[i]),
           df, :ExerciseSuccessful, cutoff, 2
       )
        return MissingExercise(df, Pair{String, Any}["MissingExerciseDate" => cutoff])
    end
end

function check_signal(::Type{SubstanceMore}, df, cutoff)
    substance = @chain df begin
        subset(:IsA06)
        lastdays(1, cutoff)
        getproperty(:SubstanceMore)
    end

    if length(substance) == 1 && isvalid(only(substance)) && only(substance) > 75
        return SubstanceMore(
            df,
            [
                "SubstanceMoreDate" => cutoff,
                "SubstanceMoreValue" => only(substance)
            ]
        )
    end
end

function check_signal(::Type{SocialInteractionMore}, df, cutoff)
    interaction = @chain df begin
        subset(:IsA06)
        lastdays(4, cutoff)
        getproperty(:SocialInteractionMore)
    end

    if length(interaction) == 4 && any(isvalid, interaction)
        avg = mean(filter(isvalid, interaction))

        if avg < 25 || avg > 75
            return SocialInteractionMore(
                df,
                [
                    "SocialInteractionMoreDate" => cutoff,
                    "SocialInteractionMoreValue" => avg
                ]
            )
        end
    end
end

function check_signal(::Type{Medication}, df, cutoff)
    medication = @chain df begin
        subset(:IsA06)
        lastdays(1, cutoff)
        getproperty(:Medication)
    end

    if length(medication) == 1 && isvalid(medication)
        return Medication(
            df,
            [
                "MedicationDate" => cutoff,
                "MedicationValue" => medication
            ]
        )
    end
end

function check_signal(::Type{SleepDuration}, df, cutoff)
    if last(df.IsA06) && isalarm(
        (x, i) -> isvalid(x[i]) &&
                      count(isvalid, x[1:i]) >= 5 &&
                      (x[i] < 5 || x[i] > 10) &&
                      count(e -> (e < 5 || e > 10), last(filter(isvalid, x), 5)) >= 3,
        df, :SleepDuration, cutoff, 4
    )
        return SleepDuration(df, Pair{String, Any}["SleepDurationDate" => cutoff])
    end
end

function check_signal(::Type{SleepQuality}, df, cutoff)
    if last(df.IsA06) && isalarm(
        (x, i) -> isvalid(x[i]) &&
                      count(isvalid, x[1:i]) >= 5 &&
                      x[i] <= 30 &&
                      count(e -> e <= 30, last(filter(isvalid, x), 5)) >= 3,
        df, :SleepQuality, cutoff, 4
    )
        return SleepQuality(df, Pair{String, Any}["SleepQualityDate" => cutoff])
    end
end

function check_signal(::Type{EarlyAwakening}, df, cutoff)
    if last(df.IsA06) && isalarm(
        (x, i) -> isvalid(x[i]) &&
                      count(isvalid, x[1:i]) >= 5 &&
                      x[i] <= Time("05:00") &&
                      count(e -> e <= Time("05:00"), last(filter(isvalid, x), 3)) >= 3,
        df, :WakeUp, cutoff, 4
    )
        return EarlyAwakening(df, Pair{String, Any}["EarlyAwakeningDate" => cutoff])
    end
end

function check_signal(::Type{RemissionDepression}, df, cutoff)
    df_a04 = @chain df begin
        select(:Date, :IsA04)
        dropmissing
        subset(:IsA04 => ByRow(!isnothing))
    end

    if nrow(df_a04) >= 1 && last(df_a04.IsA04)
        index = findprev(.!df_a04.IsA04, nrow(df_a04))

        if isnothing(index)
            index = 1
        end

        if cutoff - df_a04.Date[index] >= Day(56)
            df_phq = @chain df begin
                lastdays(14, cutoff)
                dropmissing(:PHQ9SumScore)
                sort(:Date)
            end

            if nrow(df_phq) >= 1 &&
               count(x -> x < 10, df_phq.PHQ9SumScore) >= nrow(df_phq) / 2
                return RemissionDepression(
                    df,
                    Pair{String, Any}[
                        "RemissionDepressionFirstDate" => first(df_phq.Date),
                        "RemissionDepressionLastDate" => last(df_phq.Date)
                    ]
                )
            end
        end
    end
end

function check_signal(::Type{SymptomRemission}, df, cutoff)
    df_remission = subset(df, :DepressiveEpisode)

    if nrow(df_remission) >= 53
        symptom_remission = @chain df_remission begin
            transform(:PHQ9SumScore => is_symptom_free => :SymptomFree)

            # only consider days since the last diagnosis
            subset([:Date, :DIPSDate] => ((d, x) -> d .>= last(x)))

            # check if the criteria for symptom remission are met
            transform(:SymptomFree => (x -> map(i -> count(x[max(1, i - 52):i]) == 53, eachindex(x))) => :SymptomRemission)

            getproperty(:SymptomRemission)
        end

        if count(symptom_remission) == 1 &&
           last(symptom_remission) &&
           last(df_remission.Date) == cutoff
            return SymptomRemission(df, Pair{String, Any}["SymptomRemissionDate" => cutoff])
        end
    end
end

function receiver(x::Initial)
    x.city == "Marburg" && return EMAIL_MARBURG_GENERAL
    x.city == "Münster" && return EMAIL_MÜNSTER_S02
    x.city == "Dresden" && return EMAIL_DRESDEN_UKD
end

function receiver(x::InflectionDepression)
    x.city == "Marburg" && return EMAIL_MARBURG_GENERAL
    x.city == "Münster" && return EMAIL_MÜNSTER_A04

    if x.city == "Dresden"
        if x.a06
            return EMAIL_DRESDEN_A06
        elseif x.study_center == "Dresden (FAL)"
            return EMAIL_DRESDEN_FAL
        elseif x.study_center == "Dresden (UKD)"
            return EMAIL_DRESDEN_UKD
        end
    end
end

function receiver(x::InflectionMania)
    x.city == "Marburg" && return EMAIL_MARBURG_GENERAL

    if x.city == "Münster"
        if x.b07
            return EMAIL_MÜNSTER_B07
        else
            return [EMAIL_MÜNSTER_B07, EMAIL_MÜNSTER_S02]
        end
    elseif x.city == "Dresden"
        if x.a06
            return EMAIL_DRESDEN_A06
        elseif x.study_center == "Dresden (FAL)"
            return EMAIL_DRESDEN_FAL
        elseif x.study_center == "Dresden (UKD)"
            return EMAIL_DRESDEN_UKD
        end
    end
end

function receiver(x::Expectation)
    x.city == "Marburg" && return EMAIL_MARBURG_B03
end

function receiver(x::StressfulLifeEvent)
    x.city == "Münster" && return [EMAIL_MÜNSTER_B01, EMAIL_MÜNSTER_LISA_LEEHR]

    if x.city == "Marburg"
        if x.group == "B01"
            return [EMAIL_MARBURG_B01, EMAIL_MÜNSTER_LISA_LEEHR]
        else
            return EMAIL_MARBURG_B01
        end
    elseif x.city == "Dresden" && x.group == "B01"
        return [EMAIL_DRESDEN_B01, EMAIL_MÜNSTER_LISA_LEEHR]
    end
end

function receiver(x::MissingExercise)
    x.city == "Marburg" && return EMAIL_MARBURG_B05
    x.city == "Münster" && return EMAIL_MÜNSTER_C03
    x.city == "Dresden" && return EMAIL_DRESDEN_FAL
end

function receiver(x::MissingIntenseSampling)
    x.city == "Marburg" && return EMAIL_MARBURG_B01

    if x.city == "Münster"
        if x.group == "B01" || startswith(x.group, "C01")
            return EMAIL_MÜNSTER_B01
        elseif startswith(x.group, "B05/C03")
            return EMAIL_MÜNSTER_C03
        end
    elseif x.city == "Dresden"
        if x.study_center == "Dresden (FAL)"
            return EMAIL_DRESDEN_FAL
        elseif x.study_center == "Dresden (UKD)"
            return EMAIL_DRESDEN_UKD
        end
    end
end

function receiver(x::MissingQuestionsProblems)
    x.city == "Marburg" && return EMAIL_MARBURG_GENERAL
    x.city == "Dresden" && return EMAIL_DRESDEN_FAL
end

function receiver(x::Union{SubstanceMore, SocialInteractionMore, Medication,
        SleepDuration, SleepQuality, EarlyAwakening})
    x.city == "Marburg" && return EMAIL_MARBURG_A06
    x.city == "Dresden" && return EMAIL_DRESDEN_A06
end

function receiver(x::Union{RemissionDepression, SymptomRemission})
    x.city == "Marburg" && return EMAIL_MARBURG_GENERAL
    x.city == "Münster" && return EMAIL_MÜNSTER_A04
    x.city == "Dresden" && return EMAIL_DRESDEN_UKD
end

function determine_signals(df, signals; cutoff = Date(now()) - Day(1))
    df_data = @chain df begin
        subset(:Date => ByRow(x -> x <= cutoff))
        sort([:Participant, :Date])
    end

    results = AbstractSignal[]

    for participant in unique(df_data.Participant)
        df_participant = subset(df_data, :Participant => ByRow(isequal(participant)))

        for signal in signals
            result = check_signal(eval(signal), df_participant, cutoff)

            if !isnothing(result)
                push!(results, result)
            end
        end
    end

    return results
end