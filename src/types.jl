
struct StudyCenter
    name::String
    client_secret::String
    username::String
    password::String
    studyuuid::String
    groups::Dict{String, String}
    movisens_id::String
    movisens_key::String
end

struct EmailCredentials
    server::String
    login::String
    password::String
    sender::String
end

struct Variable
    name::String
    uuid::String
    type::DataType
end

struct Signal
    f::Function
    scope::Vector{String}
    variables::Vector{Symbol}
end