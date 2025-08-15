include("../src/main.jl")

for sc in STUDY_CENTERS
    city, username, password, clientsecret, studyuuid = sc.name,
    sc.username, sc.password, sc.client_secret, sc.studyuuid

    df = download_interaction_designer_dataframe(
        username, password, clientsecret, studyuuid)

    CSV.write("export/CRC393 $city Forms (raw).csv", df)
end