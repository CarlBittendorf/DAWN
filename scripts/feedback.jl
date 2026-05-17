include("../src/main.jl")

function script()
    # read the study center index from command-line arguments
    index = parse(Int, only(ARGS))

    # select the study center based on the provided index
    study_center = STUDY_CENTERS[index]

    # extract the city name from the study center metadata
    city = study_center.name

    # define a cutoff date (yesterday) for feedback detection
    cutoff = Date(now()) - Day(1)

    # prepare the dataset containing the results from the queries
    df = prepare_queries_dataset(study_center)

    # build participant records based on the study center and query data
    participants = prepare_participants(study_center, df)

    # detect feedback for participants, considering only data up to the cutoff date
    feedback = detect_feedback(participants, df; cutoff)

    # upload detected feedback to REDCap
    upload_redcap(REDCapFeedback, feedback)

    # collect all unique feedback receivers (can be strings or vectors)
    receivers = @chain feedback begin
        @. receiver       # extract receiver(s) from each feedback
        vcat(_...)        # flatten into a single vector
        unique            # remove duplicates
    end

    # iterate over each unique receiver (email)
    for email in receivers
        # select feedback relevant to the current receiver and format them
        html = @chain feedback begin
            filter(
                x -> email == receiver(x) ||
                    (receiver(x) isa Vector && email in receiver(x)),
                _
            )
            @. format_feedback
            vcat(_...)
        end

        # send the formatted feedback via email
        if email isa String
            # send directly to this email plus additional configured receivers
            send_feedback_email(
                EMAIL_CREDENTIALS,
                [email, EMAIL_ADDITIONAL_RECEIVERS...],
                city,
                html
            )
        end
    end
end

run_script(script, EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER)