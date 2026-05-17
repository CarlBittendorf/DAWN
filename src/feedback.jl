
# 1. Interface Documentation
# 2. Generic Definitions
# 3. Concrete Implementations
# 4. Helper Functions
# 5. High-level Functions

####################################################################################################
# INTERFACE DOCUMENTATION
####################################################################################################

# This code provides a typed interface for detecting and handling feedback associated with
# participants.

# Each feedback is represented by a concrete Julia type and must implement the following functions:

# detect(::Type{<:AbstractFeedback}, df::DataFrame, cutoff::Date)
# receiver(feedback::Feedback{<:AbstractFeedback})

####################################################################################################
# GENERIC DEFINITIONS
####################################################################################################

abstract type AbstractFeedback end

struct Feedback{T <: AbstractFeedback}
    participant::Participant

    # feedback table
    table::DataFrame

    # feedback-specific metadata
    data::Vector{Pair{String, Any}}
end

function Feedback(
        T::Type{<:AbstractFeedback},
        participant::Participant,
        table::DataFrame,
        data::Vector{Pair{String, Any}}
)
    return Feedback{T}(participant, table, data)
end

"""
    detect(T::Type{<:AbstractFeedback}, df::DataFrame, cutoff::Date) -> Union{Feedback{T},Nothing}

Detect whether feedback of type `T` occurs for `participant` at the given `cutoff` date.

If feedback is available, it is materialized as a `Feedback{T}` object that is associated with a
specific participant and carries a table as a `DataFrame`, as well as derived metadata in a
structured key-value form. Otherwise, `nothing` is returned.
"""
function detect end

"""
    receiver(feedback::Feedback{<:AbstractFeedback}) -> Union{String,Vector{String},Nothing}

Determines the intended recipient(s) of the feedback notification (i.e., email addresses).
"""
function receiver end

####################################################################################################
# CONCRETE IMPLEMENTATIONS
####################################################################################################

struct FeedbackB01 <: AbstractFeedback end
struct FeedbackB05 <: AbstractFeedback end
struct FeedbackC01 <: AbstractFeedback end
struct FeedbackC03 <: AbstractFeedback end
struct FeedbackS01 <: AbstractFeedback end

function detect(::Type{FeedbackB01}, participant::Participant, df::DataFrame, cutoff::Date)
    if nrow(df) >= 1 && participant.group == "B01"
        variables_intense_sampling = getproperty.(VARIABLES_B01_INTENSE_SAMPLING, :name)

        df_b01 = @chain df begin
            dropmissing(:NegativeEventIntensityMoment)

            groupby(:Participant)
            subset(:Date => (x -> any(isequal(cutoff), x)))

            sort(:Date)
            transform(
                :Date => enumerate_blocks => :Block,
                :Date => (x -> eachindex(x)) => :Instance
            )
            subset(:Block => (x -> x .== maximum(x; init = 1)))
            transform(
                :Date => (x -> eachindex(x)) => :Day,
                :NegativeEventIntensityMoment => ByRow(x -> x isa Vector ? count(!isnothing, x) : 0) => :Prompts,
                variables_intense_sampling => ByRow((x...) -> count(isvalid, vcat(x...))) => :Items
            )
            transform(:Prompts => ByRow(x -> COMPENSATION_B01[min(x, 5)]) => :Compensation)
            transform(
                :Prompts => cumsum => :CumulativePrompts,
                :Items => cumsum => :CumulativeItems,
                :Compensation => cumsum => :CumulativeCompensation
            )
            transform([:Day, :CumulativeItems] => ByRow((d, x) -> round(100 * x / (73 * d); digits = 2)) => :CumulativeCompliance)
            transform(:CumulativeCompliance => ByRow(x -> COMPENSATION_B01_BONUS[floor(Int, x)]) => :Bonus)
        end

        if nrow(df_b01) >= 1
            table = @chain df_b01 begin
                select(:Block, :Date, :Prompts, :Items, :Compensation, :Bonus)

                push!(
                    _,
                    ["Total", "", sum(_.Prompts), sum(_.Items),
                        sum(_.Compensation), last(_.Bonus)];
                    promote = true
                )

                transform(
                    :Compensation => ByRow(format_compensation),
                    :Bonus => ByRow(format_compensation);
                    renamecols = false
                )
            end

            data = [
                "RedcapRepeatInstance" => last(df_b01.Instance),
                "FeedbackB01Date" => last(df_b01.Date),
                "FeedbackB01AcceptedPrompts" => last(df_b01.Prompts),
                "FeedbackB01CompletedItems" => last(df_b01.Items),
                "FeedbackB01DailyCompensation" => last(df_b01.Compensation),
                "FeedbackB01TotalAcceptedPrompts" => last(df_b01.CumulativePrompts),
                "FeedbackB01TotalCompletedItems" => last(df_b01.CumulativeItems),
                "FeedbackB01TotalCompensation" => last(df_b01.CumulativeCompensation),
                "FeedbackB01PredictedBonus" => last(df_b01.Bonus)
            ]

            return Feedback(FeedbackB01, participant, table, data)
        end
    end
end

function detect(::Type{FeedbackB05}, participant::Participant, df::DataFrame, cutoff::Date)
    if nrow(df) >= 1 && contains(participant.group, "B05/C03")
        variables_intense_sampling = getproperty.(VARIABLES_B05_INTENSE_SAMPLING, :name)

        df_b05 = @chain df begin
            lastdays(14, cutoff)
            dropmissing(:B05DayCounter)
            subset(:B05DayCounter => ByRow(x -> x in [1:14..., 71:84...]))

            groupby(:Participant)
            subset(:Date => (x -> any(isequal(cutoff), x)))

            sort(:B05DayCounter)
            transform(
                :B05DayCounter => ByRow(x -> (x - 1) % 14 + 1) => :Day,
                :PercentSocialInteractions => ByRow(x -> x isa Vector ? count(!isnothing, x) : 0) => :Prompts,
                variables_intense_sampling => ByRow((x...) -> count(isvalid, vcat(x...))) => :Items
            )
            transform(:Prompts => cumsum => :CumulativePrompts)
            transform([:Day, :CumulativePrompts] => ByRow((d, x) -> round(100 * x / (4 * d); digits = 2)) => :CumulativeCompliance)
            transform(:CumulativeCompliance => ByRow(x -> COMPENSATION_B05[floor(Int, x)]) => :Compensation)
        end

        if nrow(df_b05) >= 1
            table = @chain df_b05 begin
                select(:Date, :Prompts, :Items, :Compensation)

                push!(
                    _,
                    ["Total", sum(_.Prompts), sum(_.Items), last(_.Compensation)];
                    promote = true
                )

                transform(:Compensation => ByRow(format_compensation); renamecols = false)
            end

            data = [
                "RedcapRepeatInstance" => last(df_b05.B05DayCounter),
                "FeedbackB05Date" => last(df_b05.Date),
                "FeedbackB05AcceptedPrompts" => last(df_b05.Prompts),
                "FeedbackB05CompletedItems" => last(df_b05.Items),
                "FeedbackB05PredictedCompensation" => last(df_b05.Compensation),
                "FeedbackB05TotalAcceptedPrompts" => last(df_b05.CumulativePrompts),
                "FeedbackB05Compliance" => last(df_b05.CumulativeCompliance)
            ]

            return Feedback(FeedbackB05, participant, table, data)
        end
    end
end

function detect(::Type{FeedbackC01}, participant::Participant, df::DataFrame, cutoff::Date)
    if nrow(df) >= 1 && contains(participant.group, "C01")
        df_c01 = @chain df begin
            dropmissing(:C01DayCounter)

            groupby(:Participant)
            subset(:Date => (x -> any(isequal(cutoff), x)))

            transform(:C01DayCounter => ByRow(x -> ceil(Int, x / 7)) => :Week)
        end

        if nrow(df_c01) >= 1 && nrow(df_c01) % 7 == 0
            if last(df_c01.Week) in [1, 2, 11, 12]
                df_c01 = @chain df_c01 begin
                    lastdays(14, cutoff)
                    subset(:Week => ByRow(x -> x in [1, 2, 11, 12]))

                    groupby(:Week)
                    combine(
                        :Date => (x -> minimum(x; init = cutoff)) => :Start,
                        :Date => (x -> maximum(x; init = cutoff - Day(180))) => :End,
                        :NegativeEventIntensityMoment => ByRow(x -> x isa Vector ? count(!isnothing, x) : 0) => :Prompts
                    )

                    sort(:Week)
                    transform(:Prompts => ByRow(x -> round(100 * x / (5 * 7); digits = 2)) => :Compliance)
                    transform(:Compliance => ByRow(x -> COMPENSATION_C01_INTENSE_SAMPLING[floor(Int, x)]) => :Compensation)
                    transform(:Prompts => cumsum => :CumulativePrompts)
                    transform(:CumulativePrompts => ByRow(x -> 100 * x / (5 * 7 * length(x))) => :CumulativeCompliance)
                end

                table = @chain df_c01 begin
                    select(:Week, :Prompts, :Compliance, :Compensation)

                    push!(
                        _,
                        ["Total", sum(_.Prompts),
                            last(df_c01.CumulativeCompliance), last(_.Compensation)];
                        promote = true
                    )

                    transform(
                        :Compliance => ByRow(x -> format_compliance(x / 100)),
                        :Compensation => ByRow(format_compensation);
                        renamecols = false
                    )
                end

                data = [
                    "RedcapRepeatInstance" => last(df_c01.Week),
                    "FeedbackC01StartDate" => last(df_c01.Start),
                    "FeedbackC01EndDate" => last(df_c01.End),
                    "FeedbackC01AcceptedPrompts" => last(df_c01.Prompts),
                    "FeedbackC01PredictedCompensation" => last(df_c01.Compensation),
                    "FeedbackC01TotalAcceptedPrompts" => last(df_c01.CumulativePrompts)
                ]

                return Feedback(FeedbackC01, participant, table, data)
            else
                df_c01 = @chain df_c01 begin
                    lastdays(56, cutoff)
                    subset(:Week => ByRow(x -> x in 3:10))

                    transform(:TrainingSuccess => ByRow(isvalid) => :Training)

                    # for each week, calculate the number of days the participant trained
                    groupby(:Week)
                    combine(
                        :Date => (x -> minimum(x; init = cutoff)) => :Start,
                        :Date => (x -> maximum(x; init = cutoff - Day(180))) => :End,
                        :Training => count => :Training
                    )

                    sort(:Week)
                    transform(:Training => ByRow(x -> COMPENSATION_C01_TRAINING[x]) => :Compensation)
                    transform(
                        :Training => cumsum => :CumulativeTraining,
                        :Compensation => cumsum => :CumulativeCompensation
                    )
                end

                table = @chain df_c01 begin
                    select(:Week, :Training, :Compensation)

                    push!(
                        _,
                        ["Total", sum(_.Training), sum(_.Compensation)];
                        promote = true
                    )

                    transform(
                        :Compensation => ByRow(format_compensation);
                        renamecols = false
                    )
                end

                data = [
                    "RedcapRepeatInstance" => last(df_c01.Week),
                    "FeedbackC01StartDate" => last(df_c01.Start),
                    "FeedbackC01EndDate" => last(df_c01.End),
                    "FeedbackC01TrainingCompleted" => last(df_c01.Training),
                    "FeedbackC01Compensation" => last(df_c01.Compensation),
                    "FeedbackC03TotalTrainingCompleted" => last(df_c01.CumulativeTraining),
                    "FeedbackC03TotalCompensation" => last(df_c01.CumulativeCompensation)
                ]

                return Feedback(FeedbackC01, participant, table, data)
            end
        end
    end
end

function detect(::Type{FeedbackC03}, participant::Participant, df::DataFrame, cutoff::Date)
    if nrow(df) >= 1 && contains(participant.group, "B05/C03")
        df_c03 = @chain df begin
            lastdays(56, cutoff)
            dropmissing(:B05DayCounter)
            subset(:B05DayCounter => ByRow(x -> x in 15:70))

            groupby(:Participant)
            subset(:Date => (x -> any(isequal(cutoff), x)))

            transform(
                :B05DayCounter => ByRow(x -> x - 14) => :Day,
                :B05DayCounter => ByRow(x -> floor(Int, (x - 7) / 7)) => :Week,
                :MDMQContentMoment => ByRow(x -> x isa Vector ? count(!isnothing, x) : 0) => :Prompts
            )
        end

        if nrow(df_c03) >= 1
            if participant.group == "Partner B05/C03 Mindfulness"
                df_c03 = @chain df_c03 begin
                    sort(:B05DayCounter)
                    transform(:Prompts => cumsum => :CumulativePrompts)
                    transform([:Day, :CumulativePrompts] => ByRow((d, x) -> round(100 * x / (2 * d); digits = 2)) => :CumulativeCompliance)
                    transform(:CumulativeCompliance => ByRow(x -> COMPENSATION_C03_PARTNER[floor(Int, x)]) => :Compensation)
                end

                table = @chain df_c03 begin
                    select(:Date, :Prompts, :Compensation)

                    push!(
                        _,
                        ["Total", sum(_.Prompts), last(_.Compensation)];
                        promote = true
                    )

                    transform(
                        :Compensation => ByRow(format_compensation);
                        renamecols = false
                    )
                end

                data = [
                    "RedcapRepeatInstance" => last(df_c03.B05DayCounter),
                    "FeedbackC03Date" => last(df_c03.Date),
                    "FeedbackC03AcceptedPrompts" => last(df_c03.Prompts),
                    "FeedbackC03PredictedCompensation" => last(df_c03.Compensation),
                    "FeedbackC03TotalAcceptedPrompts" => last(df_c03.CumulativePrompts)
                ]
            else
                df_c03 = @chain df_c03 begin
                    transform(:ExerciseSuccessful => ByRow(x -> !isnothing(x) && x != 0) => :Exercise)
                    transform(
                        [:Exercise, :Prompts] => ByRow((x, prompts) -> 0.5 * (x && prompts >= 1)) => :Compensation,
                        [:Exercise, :Prompts] => ByRow((x, prompts) -> x && prompts >= 2) => :Complete
                    )

                    groupby(:Week)
                    transform(
                        :Complete => (x -> COMPENSATION_C03_EXERCISE[sum(x)]) => :Bonus,
                        :B05DayCounter => ByRow(x -> x in 21:7:70) => :LastDay
                    )

                    sort(:B05DayCounter)

                    # add the bonus to the last day of the week
                    transform([:Compensation, :Bonus, :LastDay] => ByRow((c, b, l) -> l ? c + b : c) => :Compensation)

                    transform(
                        :Prompts => cumsum => :CumulativePrompts,
                        :Compensation => cumsum => :CumulativeCompensation
                    )
                end

                table = @chain df_c03 begin
                    select(:Date, :Exercise, :Prompts, :Compensation)

                    push!(
                        _,
                        ["Total", sum(_.Exercise), sum(_.Prompts), sum(_.Compensation)];
                        promote = true
                    )

                    transform(
                        :Compensation => ByRow(format_compensation);
                        renamecols = false
                    )
                end

                data = [
                    "RedcapRepeatInstance" => last(df_c03.B05DayCounter),
                    "FeedbackC03Date" => last(df_c03.Date),
                    "FeedbackC03ExerciseCompleted" => last(df_c03.Exercise),
                    "FeedbackC03AcceptedPrompts" => last(df_c03.Prompts),
                    "FeedbackC03DailyCompensation" => last(df_c03.Compensation),
                    "FeedbackC03TotalAcceptedPrompts" => last(df_c03.CumulativePrompts),
                    "FeedbackC03TotalCompensation" => last(df_c03.CumulativeCompensation)
                ]
            end

            return Feedback(FeedbackC03, participant, table, data)
        end
    end
end

function detect(::Type{FeedbackS01}, participant::Participant, df::DataFrame, cutoff::Date)
    if nrow(df) >= 1
        df_s01 = @chain df begin
            # determine if the participant just finished a multiple of 30 days
            # and has at least one entry within the last 30 days
            groupby(:Participant)
            subset(
                :Date => (x -> (Dates.value(cutoff - minimum(x)) + 1) % 30 == 0),
                :Date => (x -> any(d -> d > cutoff - Day(30), x))
            )
        end

        if nrow(df_s01) >= 1
            df_s01 = @chain df_s01 begin
                transform(:Date => (x -> Dates.value.(x .- minimum(x; init = cutoff)) .+ 1) => :Day)
                transform(:Day => ByRow(x -> ceil(Int, x / 30)) => :Block)

                groupby(:Block)
                combine(
                    :Date => (x -> minimum(x; init = cutoff)) => :Start,
                    :Date => (x -> maximum(x; init = cutoff - Day(180))) => :End,
                    :ChronoRecord => (x -> round(100 * count(isvalid, x) / 30; digits = 2)) => :Compliance;
                    renamecols = false
                )
            end

            table = @chain df_s01 begin
                select(:Block, :Start, :End, :Compliance)
                sort(:Block)

                transform(
                    :Compliance => ByRow(x -> format_compliance(x / 100));
                    renamecols = false
                )
            end

            data = [
                "RedcapRepeatInstance" => last(df_s01.Block),
                "FeedbackS01StartDate" => last(df_s01.Start),
                "FeedbackS01EndDate" => last(df_s01.End),
                "FeedbackS01Compliance" => last(df_s01.Compliance)
            ]

            return Feedback(FeedbackS01, participant, table, data)
        end
    end
end

function receiver(feedback::Feedback{FeedbackB01})
    if nrow(feedback.table) - 1 in [5, 7, 14]
        city = feedback.participant.city

        city == "Marburg" && return EMAIL_MARBURG_B01
        city == "Münster" && return EMAIL_MÜNSTER_B01
        city == "Dresden" && return EMAIL_DRESDEN_B01
    end
end

function receiver(feedback::Feedback{FeedbackB05})
    if nrow(feedback.table) - 1 in [5, 7, 14]
        city = feedback.participant.city

        city == "Marburg" && return [EMAIL_MARBURG_B05, EMAIL_MÜNSTER_C03]
        city == "Münster" && return EMAIL_MÜNSTER_C03
        city == "Dresden" && return [EMAIL_MÜNSTER_C03, EMAIL_DRESDEN_FAL]
    end
end

function receiver(feedback::Feedback{FeedbackC01})
    if nrow(feedback.table) - 1 in [3, 5, 7, 9]
        city = feedback.participant.city

        city == "Marburg" && return EMAIL_MARBURG_C01
        city == "Dresden" && return EMAIL_DRESDEN_FAL
    end
end

function receiver(feedback::Feedback{FeedbackC03})
    if nrow(feedback.table) - 1 in 7:7:56
        city = feedback.participant.city

        city == "Marburg" && return [EMAIL_MARBURG_B05, EMAIL_MÜNSTER_C03]
        city == "Münster" && return EMAIL_MÜNSTER_C03
        city == "Dresden" && return [EMAIL_MÜNSTER_C03, EMAIL_DRESDEN_FAL]
    end
end

function receiver(feedback::Feedback{FeedbackS01})
    if nrow(feedback.table) % 6 == 0
        city = feedback.participant.city

        city == "Marburg" && return EMAIL_MARBURG_GENERAL
        city == "Münster" && return EMAIL_MÜNSTER_S02
        city == "Dresden" && return EMAIL_DRESDEN_UKD
    end
end

####################################################################################################
# HELPER FUNCTIONS
####################################################################################################

function format_header(feedback::Feedback{T}) where {T}
    # extract participant associated with the feedback
    participant = feedback.participant

    # header line with participant metadata and feedback type
    return string(
        participant.id, " (",
        participant.study_center, ", ",
        participant.group, "): ",
        string(T)
    )
end

"""
    format_feedback(feedback::Feedback) -> Vector{Node{HTMLSVG}}

Convert a detected feedback into a HTML representation.

The output contains:
- Participant identifier and metadata (study center, group)
- The feedback type
- The feedback table
"""
function format_feedback(feedback::Feedback)
    [
        make_paragraph(format_header(feedback)),
        make_table(feedback.table)
    ]
end

####################################################################################################
# HIGH-LEVEL FUNCTIONS
####################################################################################################

"""
    detect_feedback(participants, df; feedback = subtypes(AbstractFeedback), cutoff = Date(now()) - Day(1))

Detect all applicable feedback for a set of participants up to a cutoff date.

Workflow:
1. Filter the longitudinal dataset to records up to the cutoff date.
2. For each participant:
   - Extract participant-specific data.
   - Apply each feedback type's `detect` method.
3. Collect and return all detected feedback.

Only non-`nothing` detection results are returned.
"""
function detect_feedback(
        participants::Vector{Participant},
        df::DataFrame;
        feedback = subtypes(AbstractFeedback),
        cutoff::Date = Date(now()) - Day(1)
)
    # restrict data to observations on or before the cutoff date
    df_data = subset(df, :Date => ByRow(x -> x <= cutoff))

    # container for all feedback
    results = Feedback[]

    # iterate over each participant
    for participant in participants
        # extract longitudinal data for the current participant
        df_participant = subset(df_data, :Participant => ByRow(isequal(participant.id)))

        # apply each feedback detector to the participant's data
        for x in feedback
            result = detect(x, participant, df_participant, cutoff)

            # store feedback (ignore non-detections)
            if !isnothing(result)
                push!(results, result)
            end
        end
    end

    results
end