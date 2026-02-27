
struct Variable
    name::String
    uuid::String
    type::DataType
end

const VARIABLES_DATABASE = [
    # S01
    Variable("ChronoRecord", "f9415c23-ba74-460a-9548-61b52a3182c5", Int),
    Variable("PHQ1", "4a8dfcf8-74da-470b-935b-4d956e53d1c6", Int),
    Variable("PHQ2", "99ba96d0-af51-4a0d-aa8a-b731280c4567", Int),
    Variable("PHQ3", "4cd93865-08a2-4508-af1f-f0b4486a2196", Int),
    Variable("PHQ4", "1fe83b74-f70f-4181-9d46-aaeaf4cf6cdd", Int),
    Variable("PHQ5", "91074a52-efa3-4856-8875-bc0889cd8c51", Int),
    Variable("PHQ6", "2215da23-c219-4b09-b590-460e267c288c", Int),
    Variable("PHQ7", "d4390a39-778d-446c-a9d3-11a1b9312ae4", Int),
    Variable("PHQ8", "0f8cb0ab-63b0-4741-ba82-73c1f8c34333", Int),
    Variable("PHQ9", "fbe0c9a9-9897-4393-b3a8-fc2c4bd69dd4", Int),
    Variable("ASRM1", "f3832929-56f1-424a-8ffd-5935cacfe471", Int),
    Variable("ASRM2", "9690f35c-6b80-4abf-b9c1-fa6cb75c45a8", Int),
    Variable("ASRM3", "85aa78d5-e932-413b-a7f2-e8b5017be179", Int),
    Variable("ASRM4", "38c80e9e-0c9d-47e6-9fdc-2fefcdb55615", Int),
    Variable("ASRM5", "c24c098b-485d-469d-9f6f-7a590aced6c3", Int),
    Variable("FallAsleep", "b093451b-2d2b-419b-8e82-2b82cc7d1670", String),
    Variable("WakeUp", "059fc218-aa8e-4329-82ae-eb919c1e3070", String),
    Variable("SleepQuality", "6ae09269-4c35-4e48-8951-dbd2f6518bab", Int),
    Variable("SocialInteractionMore", "3403d1e6-2143-4e54-a774-484cbc8f28b9", Int),
    Variable("MajorLifeEventInfluence", "593899e8-50c0-47d2-a68b-23fe4327b71c", Int),
    Variable("Medication", "71c2dfb3-d05b-4c9e-a700-95f54ae393b8", String),
    Variable("SubstanceMore", "d864251b-ab40-4785-b520-7e2bb5933d39", Int),
    Variable(
        "ExpectationMentalHealthProblems", "6af4de87-5e40-4836-8417-729291c4a0f6", Int),
    Variable("IsA04", "b6ef4e98-c75f-4a37-8aab-e32c6cb212fd", Bool),

    # B01
    Variable("NegativeEventIntensityMoment", "8ff830c0-39be-480f-8a2c-4da9c24b370d", Int),

    # C01
    Variable("TrainingSuccess", "8f71f2c4-611d-46f7-90b0-8c7954627eb0", Int),
    Variable("TrainingProblems", "e5219fbb-5227-430d-81d7-23b4989e86b3", Int),
    Variable("TrainingQuestions", "47a32b8e-41d4-4660-8b6a-1aac0ab17e2e", Int),
    Variable("C01DayCounter", "a77152d5-2e72-4d00-8fcf-11bf1b3df54c", Int),

    # B05/C03
    Variable("SocialContact", "b6c34383-81df-4628-8890-058c5e934355", Int),
    Variable("PercentSocialInteractions", "98a78237-4f14-4738-a0bf-25022c1ffa64", Int),
    Variable("ExerciseSuccessful", "68e88276-e419-49d5-b86f-d12210fec164", Int),
    Variable("ExerciseSuccessful", "b0791d6c-a53a-4432-8dda-3f257829b76e", Int),
    Variable("ExerciseSuccessful", "64698771-ebf8-4685-9056-e620f7b22f38", Int),
    Variable("ExerciseSuccessful", "aa028d22-45f5-4c3e-b57f-92c8a10485fe", Int),
    Variable("B05DayCounter", "d89f6622-51a7-405b-86eb-1d473feccee9", Int)
]

const VARIABLE_GROUP = Variable(
    "InteractionDesignerGroupIndex",
    "f4efb3f1-508a-4be7-a021-3f5e5edd8fe1",
    Int
)

const VARIABLES_B01_INTENSE_SAMPLING = [
    Variable("MDMQContentMoment", "7b2c3197-8090-48a9-bff1-b0d9301b5bc6", Int),
    Variable("MDMQAgitatedMoment", "9a515c37-79d7-408e-a168-eaec70fd0a6c", Int),
    Variable("MDMQUnwellMoment", "635a5137-8f9f-41d9-aaca-668119f80e40", Int),
    Variable("MDMQRelaxedMoment", "134d9cd8-9e22-482e-9fd1-40f2e44b34cd", Int),
    Variable("NegativeEventIntensityMoment", "8ff830c0-39be-480f-8a2c-4da9c24b370d", Int),
    Variable("EventTimepoint", "254ecf51-a49c-460f-9400-3480373ce7dc", Int),
    Variable("MDMQContentEvent", "0a60dedf-b5fe-4fc9-9471-f46c939f56d9", Int),
    Variable("MDMQAgitatedEvent", "4ab049dd-50d1-4390-8fde-f9c475c3b5e6", Int),
    Variable("MDMQUnwellEvent", "b2508b69-7e41-470d-90d8-53b4c2444719", Int),
    Variable("MDMQRelaxedEvent", "d360e579-1bcc-4a63-b444-f00d88208616", Int),
    Variable("SocialEvent", "e183fde1-c830-4776-91e4-73c486e32c3f", Int),
    Variable("SocialEventType", "cb13be7e-f016-4ab4-ac7c-ea2bdb346a4b", Int),
    Variable("SocialEventAgency", "19fdbaee-39cb-4be3-8d04-27635b1bb910", Int),
    Variable("SocialEventComunion", "e784d883-495f-4960-92de-160129a0c507", Int),
    Variable("RegulationStrategy", "9554d28f-047a-49f4-8b8f-7de6bb34a644", Int),
    Variable("RegulationOther", "fe104a9e-93a7-48f4-ab18-0952c244a617", String),
    Variable("RegulationEffort", "0aca7aa1-2de3-44a6-98bb-1791f5011deb", Int),
    Variable("RegulationGoal", "f14209b0-c8f7-42c5-9ceb-01bdd5cac524", Int),
    Variable("RegulationSuccess", "59ef3edd-2544-4a7c-a24b-4a5bee3db76e", Int),
    Variable("SocialCompany", "11bdb38c-b2d7-401c-92ea-c9ddc1ca1b4d", Int),
    Variable("SocialCompanyType", "445189d5-d0ae-48d9-8cad-e7837691f91c", Int),
    Variable("SocialCompanyProximity", "673d1774-08ef-4ee3-afc5-8e7ff9921a5b", Int),
    Variable("IfNoEventWhatDone", "f61c8c6d-0a7a-4b35-ba35-c1e7330734c7", String)
]

const VARIABLES_B05_INTENSE_SAMPLING = [
    Variable("MDMQContentMoment", "682d63c7-aeee-4085-9742-f2ed8ecdbd14", Int),
    Variable("MDMQUnwellMoment", "24d2dc41-8ad0-45de-854c-5350a9623c1f", Int),
    Variable("PercentSocialInteractions", "98a78237-4f14-4738-a0bf-25022c1ffa64", Int),
    Variable("NumberSocialInteractions", "5f4fa2bd-fe0a-41df-81da-149976cabe3b", Int),
    Variable("InteractionPartner", "975d9005-6bed-4145-bf88-4045580966d5", Int),
    Variable("InteractionPartnerUnderstandingSelf",
        "0382f26e-16a8-4d26-8d96-63e9aea395ff", Int),
    Variable("InteractionPartnerEmpathySelf", "21bdd276-c518-4256-b191-31ace0f7efde", Int),
    Variable("InteractionPartnerEmpathicDistressSelf",
        "230faea9-a1f6-47d3-b5f1-189c6195eed9", Int),
    Variable("InteractionPartnerEmpathicConcernSelf",
        "63668fda-3dd3-4c4d-8213-1c41c058cd71", Int),
    Variable("InteractionPartnerEmotionalSupportSelf",
        "d7d6e9ac-d3f7-495f-8f00-f909255803f8", Int),
    Variable("InteractionPartnerPracticalSupportSelf",
        "8c3a632c-7230-4d8f-9883-8eb85c832a4e", Int),
    Variable("InteractionPartnerUnderstandingOther",
        "877394c0-739d-4efd-8928-8a2d4d82f56b", Int),
    Variable("InteractionPartnerEmpathyOther", "5c620ebd-717d-4b14-9ce3-cfec4e345c78", Int),
    Variable("InteractionPartnerEmpathicDistressOther",
        "cff2d75a-84c8-4065-a0ee-f73e17570f81", Int),
    Variable("InteractionPartnerEmpathicConcernOther",
        "c51b73b3-29d6-40ca-9daa-0849b0b282ca", Int),
    Variable("InteractionPartnerEmotionalSupportOther",
        "9e042316-ce9b-4f1f-a487-739a610e8429", Int),
    Variable("InteractionPartnerPracticalSupportOther",
        "c7bf7a9d-f8f1-469c-ab1b-30be9629f640", Int),
    Variable("InteractionPartnerQuality", "a0362687-a301-4cb9-b674-1d402d60608b", Int),
    Variable("InteractionPartnerCloseness", "fdc3f92f-5b01-4ebc-9367-06a93e80c0a4", Int),
    Variable("InteractionPersonRelationshipType",
        "0a5c5cea-461e-4629-aee4-852c3910581b", Int),
    Variable("InteractionPersonRelationshipCloseness",
        "0b9dbfe0-542f-49f9-a47a-97e60e053115", Int),
    Variable("InteractionPersonFeelingsOther", "3863240d-d241-4c91-bc2f-df61d56b9208", Int),
    Variable("InteractionPersonUnderstandingSelf",
        "91989728-ef07-4aa3-b6bb-c95737f869fc", Int),
    Variable("InteractionPersonEmpathySelf", "85c18974-0c17-4394-8d05-5dcbd7435645", Int),
    Variable("InteractionPersonEmpathicDistressSelf",
        "dc18c425-cffd-460f-91b9-8823776f0110", Int),
    Variable("InteractionPersonEmpathicConcernSelf",
        "07aa9c24-a943-49cb-a4a4-e4ab55bde569", Int),
    Variable("InteractionPersonEmotionalSupportSelf",
        "63ca92c6-77b8-454a-93d4-37056afc7b7b", Int),
    Variable("InteractionPersonPracticalSupportSelf",
        "ad14f368-110a-4166-b07b-a8c000e88c96", Int),
    Variable("InteractionPersonUnderstandingOther",
        "a4ee3302-f2a5-4e47-9341-46c603e6cf62", Int),
    Variable("InteractionPersonEmpathyOther", "d64cc442-4658-43df-9301-d3a627cb65b6", Int),
    Variable("InteractionPersonEmpathicDistressOther",
        "5f388e67-f8a6-4189-a934-66d073063918", Int),
    Variable("InteractionPersonEmpathicConcernOther",
        "be7a9bae-6808-4d8c-a79b-0e69228e2fb8", Int),
    Variable("InteractionPersonEmotionalSupportOther",
        "f45b13ae-963c-49ec-8dd3-4ac23913e6cf", Int),
    Variable("InteractionPersonPracticalSupportOther",
        "b5d2bebb-c17a-4ea9-9192-c721497a2fa7", Int),
    Variable("InteractionPersonQuality", "1f8b7d01-d834-4448-a568-c31373ecab3c", Int),
    Variable("InteractionPersonCloseness", "28e5fbaa-5465-4de8-9fc5-6337a8d2b1f9", Int),
    Variable("ThoughtsPartner", "c3656f96-eb36-40a0-8fd4-d33c4c914ea1", Int),
    Variable("ThoughtsPartnerUnderstandingSelf",
        "c22226f5-73b8-4129-b462-e43a95769fe5", Int),
    Variable("ThoughtsPartnerEmpathySelf", "83e22b68-a250-4ff7-8c24-2f73fd85cfae", Int),
    Variable("ThoughtsPartnerEmpathicDistressSelf",
        "68b6bea0-8edc-41f8-98b6-855b83e5f056", Int),
    Variable("ThoughtsPartnerEmpathicConcernSelf",
        "d33313fa-5eaa-42bb-a69b-bf00183293b1", Int),
    Variable("ThoughtsPartnerEmotionalSupportSelf",
        "8a8bfcc3-e9d2-4166-bd62-b2ed21f6786b", Int),
    Variable("ThoughtsPartnerPracticalSupportSelf",
        "0f87b8fe-9c06-47a8-9ac0-b6474133fddc", Int),
    Variable("ThoughtsPartnerUnderstandingOther",
        "3eb43d0f-cf0d-4d22-bac9-3f22e617308d", Int),
    Variable("ThoughtsPartnerEmpathyOther", "de251f07-1c78-46ec-a189-2a6c467fa980", Int),
    Variable("ThoughtsPartnerEmpathicDistressOther",
        "c8636d93-c4e1-447e-a6bc-c2b0278d3d5d", Int),
    Variable("ThoughtsPartnerEmpathicConcernOther",
        "81e2adad-1a01-4359-a555-d576762e8d97", Int),
    Variable("ThoughtsPartnerEmotionalSupportOther",
        "e2ce96f3-bc30-4f35-9c96-11ce8f0ce486", Int),
    Variable("ThoughtsPartnerPracticalSupportOther",
        "c5ee7ec0-017b-4b6f-8d5a-c9f4e6cbef4d", Int),
    Variable("ThoughtsPartnerQuality", "9b7b8a62-3b9e-42a0-ac3c-17ad0fa37194", Int),
    Variable("ThoughtsPartnerCloseness", "2ac89b1e-0d22-4e02-8bb6-cda55d61a839", Int),
    Variable("SocialFunctioning", "9cea9684-852b-4a51-847b-549947b624f0", String),
    Variable("CurrentlyAlone", "321430f3-b7b9-4fd9-8f5d-b2e094bbcc46", Int),
    Variable("NumberPeopleNearby", "6fe19f80-8719-4803-94e2-2b22f6b77ca6", Int),
    Variable("Loneliness", "b8eff2b7-5809-4866-908c-e4fd9b44e9e0", Int),
    Variable("MindfulnessFeelings", "88ba9b63-aed6-4a03-850c-fca043a22d2d", Int),
    Variable("MindfulnessInTheMoment", "d4350e3c-369f-4182-9982-9764c0d61a00", Int),
    Variable("Rumination", "8b7ec0ad-55b6-4c11-993a-61d7260ae676", Int),
    Variable("Distraction", "cd283efe-2aea-41c8-8258-fd04c1ac3b6a", Int),
    Variable("AffectiveControl", "dd1eb159-df55-45aa-829c-401bc1f1897b", Int),
    Variable("CognitiveFlexibility", "93a96ad6-4f5a-4dcd-8cee-adf2e31d1e17", Int),
    Variable("SelfCompassion", "4ca4bbba-3880-4612-96b7-38d297adc425", Int),
    Variable("LonelinessInverse", "1c996915-7597-484f-a703-cdc3d3d4edea", Int)
]

const VARIABLE_C01_INTENSE_SAMPLING = Variable(
    "NegativeEventIntensityMoment",
    "8ff830c0-39be-480f-8a2c-4da9c24b370d",
    Int
)

const VARIABLES_C01_TRAINING = [
    Variable("TrainingSuccess", "8f71f2c4-611d-46f7-90b0-8c7954627eb0", Int),
    Variable("C01DayCounter", "a77152d5-2e72-4d00-8fcf-11bf1b3df54c", Int)
]

const VARIABLES_C03_INTERVENTION = [
    Variable("ExerciseSuccessful", "68e88276-e419-49d5-b86f-d12210fec164", Int),
    Variable("ExerciseSuccessful", "b0791d6c-a53a-4432-8dda-3f257829b76e", Int),
    Variable("ExerciseSuccessful", "64698771-ebf8-4685-9056-e620f7b22f38", Int),
    Variable("ExerciseSuccessful", "aa028d22-45f5-4c3e-b57f-92c8a10485fe", Int),
    Variable("MDMQContentMoment", "682d63c7-aeee-4085-9742-f2ed8ecdbd14", Int),
    Variable("B05DayCounter", "d89f6622-51a7-405b-86eb-1d473feccee9", Int)
]