
# 1. Interface Documentation
# 2. Generic Definitions
# 3. Concrete Implementations
# 4. High-level Functions

####################################################################################################
# INTERFACE DOCUMENTATION
####################################################################################################

# This code provides typed signal-detection framework, where each signal symbolizes a clinically
# relevant event inferred from longitudinal participant data.

# Each signal is represented by a concrete Julia type and must implement the following functions:

# detect(::Type{<:AbstractSignal}, df::DataFrame, cutoff::Date)
# receiver(signal::Signal{<:AbstractSignal})

####################################################################################################
# GENERIC DEFINITIONS
####################################################################################################

abstract type AbstractSignal end

struct Signal{T <: AbstractSignal}
    participant::Participant

    # whether the participant is currently receiving intense sampling
    intense_sampling::Bool

    # signal-specific metadata
    data::Vector{Pair{String, Any}}

    function Signal(
            T::Type{<:AbstractSignal},
            participant::Participant,
            df::DataFrame,
            data::Vector{Pair{String, Any}}
    )
        return new{T}(
            participant,
            last(df.NegativeEventIntensityMoment) isa Vector ||
            last(df.PercentSocialInteractions) isa Vector,
            data
        )
    end
end

"""
    detect(T::Type{<:AbstractSignal}, df::DataFrame, cutoff::Date) -> Union{Signal{T},Nothing}

Detect whether a signal of type `T` occurs for `participant` at the given `cutoff` date.

If a signal is present, it is materialized as a `Signal{T}` object that is associated with a
specific participant and carries derived metadata in a structured key-value form. Otherwise,
`nothing` is returned.
"""
function detect end

"""
    receiver(signal::Signal{<:AbstractSignal}) -> Union{String,Vector{String},Nothing}

Determines the intended recipient(s) of the signal notification (i.e., email addresses).
"""
function receiver end

####################################################################################################
# CONCRETE IMPLEMENTATIONS
####################################################################################################

struct Initial <: AbstractSignal end
struct InflectionDepression <: AbstractSignal end
struct InflectionMania <: AbstractSignal end
struct Expectation <: AbstractSignal end
struct StressfulLifeEvent <: AbstractSignal end
struct MissingIntenseSampling <: AbstractSignal end
struct MissingQuestionsProblems <: AbstractSignal end
struct MissingExercise <: AbstractSignal end
struct SubstanceMore <: AbstractSignal end
struct SocialInteractionMore <: AbstractSignal end
struct Medication <: AbstractSignal end
struct SleepDuration <: AbstractSignal end
struct SleepQuality <: AbstractSignal end
struct EarlyAwakening <: AbstractSignal end
struct Inpatient <: AbstractSignal end
struct SickLeave <: AbstractSignal end
struct SymptomRemission <: AbstractSignal end

function detect(::Type{Initial}, participant::Participant, df::DataFrame, cutoff::Date)
    dates = @chain df begin
        dropmissing(:ChronoRecord)
        subset(:ChronoRecord => ByRow(!isnothing))
        getproperty(:Date)
    end

    if length(dates) == 1 && only(dates) == cutoff
        data = [
            "InitialDate" => cutoff,
            "InitialHasMobileSensing" => last(df.HasMobileSensing),
            "InitialMobileSensingRunning" => last(df.MobileSensingRunning),
            "InitialSubproject" => participant.group
        ]

        return Signal(Initial, participant, df, data)
    end
end

function detect(
        ::Type{InflectionDepression}, participant::Participant, df::DataFrame, cutoff::Date)
    df_phq = @chain df begin
        lastdays(4, cutoff)
        dropmissing(:PHQ9SumScore)
        sort(:Date)
        last(2)
    end

    if nrow(df_phq) == 2 &&
       last(df_phq.Date) == cutoff &&
       all(x -> x >= 10, df_phq.PHQ9SumScore)
        data = [
            "InflectionDepressionFirstDate" => df_phq.Date[1],
            "InflectionDepressionSecondDate" => df_phq.Date[2],
            "InflectionDepressionFirstValue" => df_phq.PHQ9SumScore[1],
            "InflectionDepressionSecondValue" => df_phq.PHQ9SumScore[2]
        ]

        return Signal(InflectionDepression, participant, df, data)
    end
end

function detect(
        ::Type{InflectionMania}, participant::Participant, df::DataFrame, cutoff::Date)
    df_asrm = @chain df begin
        lastdays(4, cutoff)
        dropmissing(:ASRM5SumScore)
        sort(:Date)
        last(2)
    end

    if nrow(df_asrm) == 2 &&
       last(df_asrm.Date) == cutoff &&
       all(x -> x >= 6, df_asrm.ASRM5SumScore)
        data = [
            "InflectionManiaFirstDate" => df_asrm.Date[1],
            "InflectionManiaSecondDate" => df_asrm.Date[2],
            "InflectionManiaFirstValue" => df_asrm.ASRM5SumScore[1],
            "InflectionManiaSecondValue" => df_asrm.ASRM5SumScore[2]
        ]

        return Signal(InflectionMania, participant, df, data)
    end
end

function detect(::Type{Expectation}, participant::Participant, df::DataFrame, cutoff::Date)
    df_expectation = @chain df begin
        lastdays(15, cutoff)
        dropmissing(:ExpectationMentalHealthProblems)
        subset(:ExpectationMentalHealthProblems => ByRow(!isnothing))
        last(2)
    end

    if nrow(df_expectation) == 2 &&
       last(df_expectation.Date) == cutoff &&
       only(diff(df_expectation.ExpectationMentalHealthProblems)) >= 3
        data = [
            "ExpectationFirstDate" => df_expectation.Date[1],
            "ExpectationSecondDate" => df_expectation.Date[2],
            "ExpectationFirstValue" => df_expectation.ExpectationMentalHealthProblems[1],
            "ExpectationSecondValue" => df_expectation.ExpectationMentalHealthProblems[2]
        ]

        return Signal(Expectation, participant, df, data)
    end
end

function detect(
        ::Type{StressfulLifeEvent}, participant::Participant, df::DataFrame, cutoff::Date)
    influence = @chain df begin
        lastdays(1, cutoff)
        getproperty(:MajorLifeEventInfluence)
    end

    if length(influence) == 1 && isvalid(only(influence)) && only(influence) == 3
        data = Pair{String, Any}["StressfulLifeEventDate" => cutoff]

        return Signal(StressfulLifeEvent, participant, df, data)
    end
end

function detect(
        ::Type{MissingIntenseSampling}, participant::Participant, df::DataFrame, cutoff::Date)
    if nrow(df) >= 1
        if participant.group in ["B01", "C01 Cognition", "C01 Emotion"]
            alarm = isalarm(
                (x, i) -> x[i] isa Vector && length(x[i]) == 5 && all(isnothing, x[i]),
                df, :NegativeEventIntensityMoment, cutoff, 2
            )
        elseif contains(participant.group, "B05/C03")
            alarm = isalarm(
                (x, y, i) -> x[i] isa Vector && length(x[i]) == 4 &&
                                 all(isnothing, x[i]) && isnothing(y[i]),
                df, [:PercentSocialInteractions, :SocialContact], cutoff, 2
            )
        else
            return nothing
        end

        if alarm
            data = Pair{String, Any}["MissingIntenseSamplingDate" => cutoff]

            return Signal(MissingIntenseSampling, participant, df, data)
        end
    end
end

function detect(
        ::Type{MissingQuestionsProblems}, participant::Participant, df::DataFrame, cutoff::Date)
    if nrow(df) >= 1 &&
       startswith(participant.group, "C01") &&
       last(df.Date) == cutoff
        missings = nrow(df) >= 2 && all(isnothing, last(df.TrainingSuccess, 2))
        problems = isvalid(last(df.TrainingProblems)) && last(df.TrainingProblems) != 1
        questions = isvalid(last(df.TrainingQuestions)) && last(df.TrainingQuestions) == 1

        if any([missings, problems, questions])
            data = [
                "MissingQuestionsProblemsDate" => cutoff,
                "MissingQuestionsProblemsMissing" => missings,
                "MissingQuestionsProblemsQuestions" => questions,
                "MissingQuestionsProblemsProblems" => problems
            ]

            return Signal(MissingQuestionsProblems, participant, df, data)
        end
    end
end

function detect(
        ::Type{MissingExercise}, participant::Participant, df::DataFrame, cutoff::Date)
    if nrow(df) >= 1 &&
       contains(participant.group, "B05/C03") &&
       participant.group != "Partner B05/C03 Mindfulness" &&
       isalarm(
           (x, i) -> count(isnothing, x[max(1, i - 1):i]) == 2 && isnothing(x[i]),
           df, :ExerciseSuccessful, cutoff, 2
       )
        data = Pair{String, Any}["MissingExerciseDate" => cutoff]

        return Signal(MissingExercise, participant, df, data)
    end
end

function detect(
        ::Type{SubstanceMore}, participant::Participant, df::DataFrame, cutoff::Date)
    if "A06" in participant.subprojects
        substance = @chain df begin
            lastdays(1, cutoff)
            getproperty(:SubstanceMore)
        end

        if length(substance) == 1 && isvalid(only(substance)) && only(substance) > 75
            data = [
                "SubstanceMoreDate" => cutoff,
                "SubstanceMoreValue" => only(substance)
            ]

            return Signal(SubstanceMore, participant, df, data)
        end
    end
end

function detect(
        ::Type{SocialInteractionMore}, participant::Participant, df::DataFrame, cutoff::Date)
    if "A06" in participant.subprojects
        interaction = @chain df begin
            lastdays(4, cutoff)
            getproperty(:SocialInteractionMore)
        end

        if length(interaction) == 4 && any(isvalid, interaction)
            avg = mean(filter(isvalid, interaction))

            if avg < 25 || avg > 75
                data = [
                    "SocialInteractionMoreDate" => cutoff,
                    "SocialInteractionMoreValue" => round(avg; digits = 2)
                ]

                return Signal(SocialInteractionMore, participant, df, data)
            end
        end
    end
end

function detect(
        ::Type{Medication}, participant::Participant, df::DataFrame, cutoff::Date)
    if "A06" in participant.subprojects
        medication = @chain df begin
            lastdays(1, cutoff)
            getproperty(:Medication)
        end

        if length(medication) == 1 && isvalid(only(medication))
            data = [
                "MedicationDate" => cutoff,
                "MedicationValue" => only(medication)
            ]

            return Signal(Medication, participant, df, data)
        end
    end
end

function detect(
        ::Type{SleepDuration}, participant::Participant, df::DataFrame, cutoff::Date)
    if "A06" in participant.subprojects && isalarm(
        (x, i) -> isvalid(x[i]) &&
                      count(isvalid, x[1:i]) >= 5 &&
                      (x[i] < 5 || x[i] > 10) &&
                      count(e -> (e < 5 || e > 10), last(filter(isvalid, x), 5)) >= 3,
        df, :SleepDuration, cutoff, 4
    )
        data = Pair{String, Any}["SleepDurationDate" => cutoff]

        return Signal(SleepDuration, participant, df, data)
    end
end

function detect(::Type{SleepQuality}, participant::Participant, df::DataFrame, cutoff::Date)
    if "A06" in participant.subprojects && isalarm(
        (x, i) -> isvalid(x[i]) &&
                      count(isvalid, x[1:i]) >= 5 &&
                      x[i] <= 30 &&
                      count(e -> e <= 30, last(filter(isvalid, x), 5)) >= 3,
        df, :SleepQuality, cutoff, 4
    )
        data = Pair{String, Any}["SleepQualityDate" => cutoff]

        return Signal(SleepQuality, participant, df, data)
    end
end

function detect(
        ::Type{EarlyAwakening}, participant::Participant, df::DataFrame, cutoff::Date)
    if "A06" in participant.subprojects && isalarm(
        (x, i) -> isvalid(x[i]) &&
                      count(isvalid, x[1:i]) >= 5 &&
                      x[i] <= Time("05:00") &&
                      count(e -> e <= Time("05:00"), last(filter(isvalid, x), 3)) >= 3,
        df, :WakeUp, cutoff, 4
    )
        data = Pair{String, Any}["EarlyAwakeningDate" => cutoff]

        return Signal(EarlyAwakening, participant, df, data)
    end
end

function detect(::Type{Inpatient}, participant::Participant, df::DataFrame, cutoff::Date)
    if "A06" in participant.subprojects
        inpatient = @chain df begin
            lastdays(1, cutoff)
            getproperty(:Inpatient)
        end

        if length(inpatient) == 1 && isvalid(only(inpatient)) && only(inpatient) > 0
            data = [
                "InpatientDate" => cutoff,
                "InpatientValue" => only(inpatient)
            ]

            return Signal(Inpatient, participant, df, data)
        end
    end
end

function detect(::Type{SickLeave}, participant::Participant, df::DataFrame, cutoff::Date)
    if "A06" in participant.subprojects
        sick = @chain df begin
            lastdays(1, cutoff)
            getproperty(:SickLeave)
        end

        if length(sick) == 1 && isvalid(only(sick)) && only(sick) > 0
            data = [
                "SickLeaveDate" => cutoff,
                "SickLeaveValue" => only(sick)
            ]

            return Signal(SickLeave, participant, df, data)
        end
    end
end

function detect(
        ::Type{SymptomRemission}, participant::Participant, df::DataFrame, cutoff::Date)
    # find the most recent diagnosis
    diagnoses = filter(x -> x.date <= cutoff, participant.diagnoses)

    if !isempty(diagnoses)
        _, index = findmax(x -> x.date, diagnoses)
        diagnosis = diagnoses[index]

        if diagnosis.depressive_episode && diagnosis.date <= cutoff - Day(53)
            symptom_remission = @chain df begin
                # only consider days since the most recent diagnosis
                subset(:Date => ByRow(x -> x >= diagnosis.date))

                transform(:PHQ9SumScore => is_symptom_free => :SymptomFree)

                # check if the criteria for symptom remission are met
                transform(:SymptomFree => (x -> map(i -> count(x[max(1, i - 52):i]) == 53, eachindex(x))) => :SymptomRemission)

                getproperty(:SymptomRemission)
            end

            if count(symptom_remission) == 1 &&
               last(symptom_remission) &&
               last(df_remission.Date) == cutoff
                data = Pair{String, Any}["SymptomRemissionDate" => cutoff]

                return Signal(SymptomRemission, participant, df, data)
            end
        end
    end
end

function receiver(signal::Signal{Initial})
    city = signal.participant.city

    city == "Marburg" && return EMAIL_MARBURG_GENERAL
    city == "Münster" && return EMAIL_MÜNSTER_S02
    city == "Dresden" && return EMAIL_DRESDEN_UKD
end

function receiver(signal::Signal{InflectionDepression})
    city = signal.participant.city
    study_center = signal.participant.study_center

    city == "Marburg" && return EMAIL_MARBURG_GENERAL
    city == "Münster" && return EMAIL_MÜNSTER_A04

    if city == "Dresden"
        if "A06" in signal.participant.subprojects
            return EMAIL_DRESDEN_A06
        elseif study_center == "Dresden (FAL)"
            return EMAIL_DRESDEN_FAL
        elseif study_center == "Dresden (UKD)"
            return EMAIL_DRESDEN_UKD
        end
    end
end

function receiver(signal::Signal{InflectionMania})
    city = signal.participant.city
    study_center = signal.participant.study_center
    subprojects = signal.participant.subprojects

    city == "Marburg" && return EMAIL_MARBURG_GENERAL

    if city == "Münster"
        if "B07" in subprojects
            return EMAIL_MÜNSTER_B07
        else
            return [EMAIL_MÜNSTER_B07, EMAIL_MÜNSTER_S02]
        end
    elseif city == "Dresden"
        if "A06" in subprojects
            return EMAIL_DRESDEN_A06
        elseif study_center == "Dresden (FAL)"
            return EMAIL_DRESDEN_FAL
        elseif study_center == "Dresden (UKD)"
            return EMAIL_DRESDEN_UKD
        end
    end
end

function receiver(signal::Signal{Expectation})
    signal.participant.city == "Marburg" && return EMAIL_MARBURG_B03
end

function receiver(signal::Signal{StressfulLifeEvent})
    group = signal.participant.group
    city = signal.participant.city

    city == "Münster" && return [EMAIL_MÜNSTER_B01, EMAIL_MÜNSTER_LISA_LEEHR]

    if city == "Marburg"
        if group == "B01"
            return [EMAIL_MARBURG_B01, EMAIL_MÜNSTER_LISA_LEEHR]
        else
            return EMAIL_MARBURG_B01
        end
    elseif city == "Dresden" && group == "B01"
        return [EMAIL_DRESDEN_B01, EMAIL_MÜNSTER_LISA_LEEHR]
    end
end

function receiver(::Signal{MissingExercise})
    return [EMAIL_MARBURG_B05, EMAIL_MÜNSTER_C03, EMAIL_DRESDEN_FAL]
end

function receiver(signal::Signal{MissingIntenseSampling})
    group = signal.participant.group
    city = signal.participant.city
    study_center = signal.participant.study_center

    if city == "Marburg"
        if contains(group, "B05/C03")
            return [EMAIL_MARBURG_B05, EMAIL_MÜNSTER_C03, EMAIL_DRESDEN_FAL]
        else
            return EMAIL_MARBURG_B01
        end
    elseif city == "Münster"
        if group == "B01" || startswith(group, "C01")
            return EMAIL_MÜNSTER_B01
        elseif contains(group, "B05/C03")
            return [EMAIL_MARBURG_B05, EMAIL_MÜNSTER_C03, EMAIL_DRESDEN_FAL]
        end
    elseif city == "Dresden"
        if study_center == "Dresden (FAL)"
            if contains(group, "B05/C03")
                return [EMAIL_MARBURG_B05, EMAIL_MÜNSTER_C03, EMAIL_DRESDEN_FAL]
            else
                return EMAIL_DRESDEN_FAL
            end
        elseif study_center == "Dresden (UKD)"
            if contains(group, "B05/C03")
                return [EMAIL_MARBURG_B05, EMAIL_MÜNSTER_C03, EMAIL_DRESDEN_FAL]
            else
                return EMAIL_DRESDEN_UKD
            end
        end
    end
end

function receiver(signal::Signal{MissingQuestionsProblems})
    city = signal.participant.city

    city == "Marburg" && return EMAIL_MARBURG_GENERAL
    city == "Dresden" && return EMAIL_DRESDEN_FAL
end

function receiver(signal::Signal{<:Union{SubstanceMore, SocialInteractionMore, Medication,
        SleepDuration, SleepQuality, EarlyAwakening, Inpatient, SickLeave}})
    city = signal.participant.city

    city == "Marburg" && return EMAIL_MARBURG_A06
    city == "Dresden" && return EMAIL_DRESDEN_A06
end

function receiver(signal::Signal{SymptomRemission})
    city = signal.participant.city

    city == "Marburg" && return EMAIL_MARBURG_GENERAL
    city == "Münster" && return EMAIL_MÜNSTER_A04
    city == "Dresden" && return EMAIL_DRESDEN_UKD
end

function format_signal(x::Signal{T}) where {T}
    participant = x.participant

    s = participant.id * " (" * participant.study_center * ", " * participant.group *
        "): " * string(T) * "\n"

    for (variable, value) in x.data
        ismissing(value) && continue

        s *= variable * ": " * string(value) * "\n"
    end

    return s
end

####################################################################################################
# HIGH-LEVEL FUNCTIONS
####################################################################################################

"""
    detect_signals(participants, df; signals = subtypes(AbstractSignal), cutoff = Date(now()) - Day(1))

Detects all applicable signals for a set of participants at a given cutoff date.

This function orchestrates signal detection by iterating over participants and signal types,
applying each signal's `detect` method to the relevant subset of longitudinal data.
"""
function detect_signals(
        participants::Vector{Participant},
        df::DataFrame;
        signals = subtypes(AbstractSignal),
        cutoff::Date = Date(now()) - Day(1)
)
    df_data = subset(df, :Date => ByRow(x -> x <= cutoff))

    results = Signal[]

    for participant in participants
        df_participant = subset(df_data, :Participant => ByRow(isequal(participant.id)))

        for signal in signals
            result = detect(signal, participant, df_participant, cutoff)

            if !isnothing(result)
                push!(results, result)
            end
        end
    end

    results
end