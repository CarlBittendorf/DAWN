include("../src/main.jl")

function script()
    # read the study center index from command-line arguments
    index = parse(Int, only(ARGS))

    # select the study center based on the provided index
    study_center = STUDY_CENTERS[index]

    # extract the city name from the study center metadata
    city = study_center.name

    # define a cutoff date (7 days ago) for compliance
    cutoff = Date(now()) - Day(7)

    # prepare the dataset containing the results from the queries
    df_queries = prepare_queries_dataset(study_center)

    # build participant records based on the study center and query data
    df_participants = prepare_participants_dataset(study_center, df_queries)

    df = @chain df_queries begin
        # only use participants who are still active
        groupby(:Participant)
        subset(:Date => (x -> any(d -> d >= cutoff, x)))

        sort([:Participant, :Date])

        groupby(:Participant)
        combine(
            [:ChronoRecord, :Date] => ((x, d) -> mean(isvalid.(x[d .>= cutoff]))) => :S01,
            :ChronoRecord => (x -> mean(isvalid.(x))) => :S01Total,
            [:HasMobileSensing, :MobileSensingRunning, :Date] => ((s, r, d) -> last(s) ? mean(r[d .>= cutoff]) : missing) => :Sensing,
            [:HasMobileSensing, :MobileSensingRunning] => ((s, r) -> any(s) ? mean(r) : missing) => :SensingTotal
        )

        leftjoin(df_participants; on = :Participant)

        dropmissing(:InteractionDesignerGroup)
        subset(:InteractionDesignerGroup => ByRow(x -> !contains(x, "Partner")))
    end

    for (selection, email) in EMAIL_COMPLIANCE_TABLE[city]
        df_project = @chain df begin
            subset(:Subprojects => ByRow(x -> isempty(selection) ||
                any(p -> p in selection, x)))
            transform(:Subprojects => ByRow(x -> join(x, ", ")); renamecols = false)

            sort([:S01, :S01Total])

            transform(
                [:S01, :S01Total, :Sensing, :SensingTotal] .=>
                    ByRow(x -> ismissing(x) ? "-" : format_compliance(x));
                renamecols = false
            )

            select(:Participant, :S01, :S01Total, :Sensing, :SensingTotal, :Subprojects)
        end

        if nrow(df_project) > 0
            send_compliance_email(
                EMAIL_CREDENTIALS,
                [email, EMAIL_ADDITIONAL_RECEIVERS...],
                city,
                df_project
            )
        end
    end
end

run_script(script, EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER)