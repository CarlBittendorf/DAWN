include("../src/main.jl")

df = DataFrame()

for sc in STUDY_CENTERS
    city, username, password, clientsecret, studyuuid = sc.name,
    sc.username, sc.password, sc.client_secret, sc.studyuuid

    df = vcat(
        df,
        download_interaction_designer_dataframe(
            username, password, clientsecret, studyuuid)
    )
end

CSV.write("export/CRC393 Forms (raw).csv", df)