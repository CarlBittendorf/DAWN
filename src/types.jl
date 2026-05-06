
struct StudyCenter
    # Marburg, Münster or Dresden
    name::String

    # client secret for obtaining a bearer token for the InteractionDesigner
    client_secret::String

    # user name for obtaining a bearer token for the InteractionDesigner
    username::String

    # password for obtaining a bearer token for the InteractionDesigner
    password::String

    # study uuid
    studyuuid::String

    # dictionary containing uuids and their corresponding group names
    groups::Dict{String, String}

    # study id for movisensXS
    movisensxs_id::String

    # API key for movisensXS
    movisensxs_key::String
end

struct EmailCredentials
    # email server
    server::String

    # user name
    login::String

    # password
    password::String

    # email address to use as sender
    sender::String
end

struct Diagnosis
    # date of the diagnostic interview
    date::Date

    # where the diagnosis was made (e.g. S02Baseline, S02FollowUp)
    origin::String

    # whether the participant was diagnosed with an acute depressive episode
    depressive_episode::Bool

    # whether the participant was diagnosed with an acute manic episode
    manic_episode::Bool
end

struct Participant
    # four-digit participant ID
    id::String

    # InteractionDesigner group
    group::String

    # Marburg, Münster or Dresden
    city::String

    # Marburg, Münster, Dresden (UKD), Dresden (FAL) or ???
    study_center::String

    # subprojects in which the participant is currently participating
    subprojects::Vector{String}

    # diagnoses from clinical interviews
    diagnoses::Vector{Diagnosis}

    # symptom remissions based on PHQ-9 scores
    remissions::Vector{Date}
end