include("../src/main.jl")

# determine the group uuids for each study center
for study_center in STUDY_CENTERS
    city, username, password, clientsecret = study_center.name,
    study_center.username, study_center.password, study_center.client_secret

    token = download_interaction_designer_token(username, password, clientsecret)
    studyuuid = download_interaction_designer_studyuuid(token)

    println(city)
    println("\"", studyuuid, "\"")
    println()

    groups = download_interaction_designer_groups(token, studyuuid)

    for groupuuid in groups
        dicts = download_interaction_designer_group_data(token, studyuuid, groupuuid)

        println("\"", dicts["id"], "\"", " => ", "\"", dicts["name"], "\"")
    end

    println()
end