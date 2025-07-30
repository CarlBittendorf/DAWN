
const INTERACTION_DESIGNER_VARIABLES = [
    # S01
    Variable("ChronoRecord", "f9415c23-ba74-460a-9548-61b52a3182c5", Int),
    Variable("PHQ2_1", "4a8dfcf8-74da-470b-935b-4d956e53d1c6", Int),
    Variable("PHQ2_2", "99ba96d0-af51-4a0d-aa8a-b731280c4567", Int),
    Variable("PHQ9_3", "4cd93865-08a2-4508-af1f-f0b4486a2196", Int),
    Variable("PHQ9_4", "1fe83b74-f70f-4181-9d46-aaeaf4cf6cdd", Int),
    Variable("PHQ9_5", "91074a52-efa3-4856-8875-bc0889cd8c51", Int),
    Variable("PHQ9_6", "2215da23-c219-4b09-b590-460e267c288c", Int),
    Variable("PHQ9_7", "d4390a39-778d-446c-a9d3-11a1b9312ae4", Int),
    Variable("PHQ9_8", "0f8cb0ab-63b0-4741-ba82-73c1f8c34333", Int),
    Variable("PHQ9_9", "fbe0c9a9-9897-4393-b3a8-fc2c4bd69dd4", Int),
    Variable("ASRM1", "f3832929-56f1-424a-8ffd-5935cacfe471", Int),
    Variable("ASRM2", "9690f35c-6b80-4abf-b9c1-fa6cb75c45a8", Int),
    Variable("ASRM3", "85aa78d5-e932-413b-a7f2-e8b5017be179", Int),
    Variable("ASRM4", "38c80e9e-0c9d-47e6-9fdc-2fefcdb55615", Int),
    Variable("ASRM5", "c24c098b-485d-469d-9f6f-7a590aced6c3", Int),
    Variable("FallAsleep", "b093451b-2d2b-419b-8e82-2b82cc7d1670", Time),
    Variable("WakeUp", "059fc218-aa8e-4329-82ae-eb919c1e3070", Time),
    Variable("SleepQuality", "6ae09269-4c35-4e48-8951-dbd2f6518bab", Int),
    Variable("SocialInteractionMore", "3403d1e6-2143-4e54-a774-484cbc8f28b9", Int),
    Variable("Influence", "593899e8-50c0-47d2-a68b-23fe4327b71c", Int),
    Variable("Medication", "71c2dfb3-d05b-4c9e-a700-95f54ae393b8", String),
    Variable("SubstanceMore", "d864251b-ab40-4785-b520-7e2bb5933d39", Int),
    Variable("Expectation", "6af4de87-5e40-4836-8417-729291c4a0f6", Int),
    Variable("IsA04", "b6ef4e98-c75f-4a37-8aab-e32c6cb212fd", Bool),

    # B01
    Variable("EventNegative", "8ff830c0-39be-480f-8a2c-4da9c24b370d", Vector{Int}),

    # C01
    Variable("TrainingSuccess", "8f71f2c4-611d-46f7-90b0-8c7954627eb0", Int),
    Variable("TrainingProblems", "e5219fbb-5227-430d-81d7-23b4989e86b3", Int),
    Variable("TrainingQuestions", "47a32b8e-41d4-4660-8b6a-1aac0ab17e2e", Int),

    # B05/C03
    Variable("SocialInteractions", "98a78237-4f14-4738-a0bf-25022c1ffa64", Vector{Int}),
    Variable("SocialContact", "b6c34383-81df-4628-8890-058c5e934355", Bool),
    Variable("CoupleDialogSuccessful", "68e88276-e419-49d5-b86f-d12210fec164", Int),
    Variable("BodyScanSuccessful", "b0791d6c-a53a-4432-8dda-3f257829b76e", Int),
    Variable("BreathingExerciseSuccessful", "64698771-ebf8-4685-9056-e620f7b22f38", Int),
    Variable("CompassionMeditationSuccessful", "aa028d22-45f5-4c3e-b57f-92c8a10485fe", Int)
]

const DATABASE_VARIABLES = [
    "Participant",
    "Date",

    # S01
    "ChronoRecord",
    "PHQ9TotalScore",
    "ASRM5TotalScore",
    "FallAsleep",
    "WakeUp",
    "SleepQuality",
    "SocialInteractionMore",
    "Influence",
    "Medication",
    "SubstanceMore",
    "Expectation",
    "IsA04",

    # B01
    "EventNegative",

    # C01
    "TrainingProblems",
    "TrainingQuestions",

    # B05/C03
    "SocialInteractions",
    "SocialContact",

    # C01 + B05/C03
    "ExerciseSuccessful"
]

const SIGNALS = [
    Signal(
        initial,
        ["S01", "B01", "C01 Cognition", "C01 Emotion",
            "B05/C03 Mindfulness", "B05/C03 PSAT"],
        [:Initial, :InitialDate, :InitialHasMobileSensing,
            :InitialMobileSensingRunning, :InitialSubproject]
    ),
    Signal(
        inflection_depression,
        ["S01", "B01", "C01 Cognition", "C01 Emotion",
            "B05/C03 Mindfulness", "B05/C03 PSAT"],
        [:InflectionDepression, :InflectionDepressionFirstDate,
            :InflectionDepressionSecondDate, :InflectionDepressionFirstValue,
            :InflectionDepressionSecondValue]
    ),
    Signal(
        inflection_mania,
        ["S01", "B01", "C01 Cognition", "C01 Emotion",
            "B05/C03 Mindfulness", "B05/C03 PSAT"],
        [:InflectionMania, :InflectionManiaFirstDate, :InflectionManiaSecondDate,
            :InflectionManiaFirstValue, :InflectionManiaSecondValue]
    ),
    Signal(
        expectation,
        ["S01", "B01", "C01 Cognition", "C01 Emotion",
            "B05/C03 Mindfulness", "B05/C03 PSAT"],
        [:Expectation, :ExpectationFirstDate, :ExpectationSecondDate,
            :ExpectationFirstValue, :ExpectationSecondValue]
    ),
    Signal(
        stressful_life_event,
        ["S01", "B01", "C01 Cognition", "C01 Emotion",
            "B05/C03 Mindfulness", "B05/C03 PSAT"],
        [:StressfulLifeEvent, :StressfulLifeEventDate]
    ),
    Signal(
        missing_chrono_record,
        ["S01", "B01", "C01 Cognition", "C01 Emotion",
            "B05/C03 Mindfulness", "B05/C03 PSAT"],
        [:MissingChronoRecord, :MissingChronoRecordFirstDate,
            :MissingChronoRecordSecondDate, :MissingChronoRecordThirdDate,
            :MissingChronoRecordFourthDate, :MissingChronoRecordA04,
            :MissingChronoRecordIntenseSampling]
    ),
    Signal(
        missing_mobile_sensing,
        ["S01", "B01", "C01 Cognition", "C01 Emotion",
            "B05/C03 Mindfulness", "B05/C03 PSAT"],
        [:MissingMobileSensing, :MissingMobileSensingDate,
            :MissingMobileSensingA04, :MissingMobileSensingIntenseSampling]
    ),
    Signal(
        missing_exercise,
        ["B05/C03 Mindfulness", "B05/C03 PSAT",
            "Partner B05/C03 Mindfulness", "Partner B05/C03 PSAT"],
        [:MissingExercise, :MissingExerciseDate]
    ),
    Signal(
        missing_intense_sampling,
        ["B01", "C01 Cognition", "C01 Emotion"],
        [:MissingIntenseSampling, :MissingIntenseSamplingDate]
    ),
    Signal(
        missing_questions_problems,
        ["C01 Cognition", "C01 Emotion"],
        [:MissingQuestionsProblems, :MissingQuestionsProblemsDate,
            :MissingQuestionsProblemsMissing, :MissingQuestionsProblemsQuestions,
            :MissingQuestionsProblemsProblems]
    ),
    Signal(
        substance_more,
        ["S01", "B01", "C01 Cognition", "C01 Emotion", "B05/C03 Mindfulness",
            "B05/C03 PSAT", "Partner B05/C03 Mindfulness", "Partner B05/C03 PSAT"],
        [:SubstanceMore, :SubstanceMoreDate, :SubstanceMoreValue]
    ),
    Signal(
        social_interaction_more,
        ["S01", "B01", "C01 Cognition", "C01 Emotion", "B05/C03 Mindfulness",
            "B05/C03 PSAT", "Partner B05/C03 Mindfulness", "Partner B05/C03 PSAT"],
        [:SocialInteractionMore, :SocialInteractionMoreDate, :SocialInteractionMoreValue]
    ),
    Signal(
        medication,
        ["S01", "B01", "C01 Cognition", "C01 Emotion", "B05/C03 Mindfulness",
            "B05/C03 PSAT", "Partner B05/C03 Mindfulness", "Partner B05/C03 PSAT"],
        [:Medication, :MedicationDate, :MedicationValue]
    ),
    Signal(
        sleep_duration,
        ["S01", "B01", "C01 Cognition", "C01 Emotion", "B05/C03 Mindfulness",
            "B05/C03 PSAT", "Partner B05/C03 Mindfulness", "Partner B05/C03 PSAT"],
        [:SleepDuration, :SleepDurationDate]
    ),
    Signal(
        sleep_quality,
        ["S01", "B01", "C01 Cognition", "C01 Emotion", "B05/C03 Mindfulness",
            "B05/C03 PSAT", "Partner B05/C03 Mindfulness", "Partner B05/C03 PSAT"],
        [:SleepQuality, :SleepQualityDate]
    ),
    Signal(
        early_awakening,
        ["S01", "B01", "C01 Cognition", "C01 Emotion", "B05/C03 Mindfulness",
            "B05/C03 PSAT", "Partner B05/C03 Mindfulness", "Partner B05/C03 PSAT"],
        [:EarlyAwakening, :EarlyAwakeningDate]
    ),
    Signal(
        remission_depression,
        ["S01", "B01", "C01 Cognition", "C01 Emotion", "B05/C03 Mindfulness",
            "B05/C03 PSAT", "Partner B05/C03 Mindfulness", "Partner B05/C03 PSAT"],
        [:RemissionDepression, :RemissionDepressionFirstDate, :RemissionDepressionLastDate]
    ),
    Signal(
        symptom_remission,
        ["S01", "B01", "C01 Cognition", "C01 Emotion",
            "B05/C03 Mindfulness", "B05/C03 PSAT"],
        [:SymptomRemission, :SymptomRemissionDate]
    )
]