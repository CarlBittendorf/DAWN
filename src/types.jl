
struct StudyCenter
    name::String
    client_secret::String
    username::String
    password::String
    studyuuid::String
    groups::Dict{String, String}
    movisensxs_id::String
    movisensxs_key::String
end

struct EmailCredentials
    server::String
    login::String
    password::String
    sender::String
end