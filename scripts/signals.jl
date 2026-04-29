include("../src/main.jl")

function script()
    # read the study center index from command-line arguments
    index = parse(Int, only(ARGS))

    # select the study center based on the provided index
    study_center = STUDY_CENTERS[index]

    # extract the city name from the study center metadata
    city = study_center.name

    # define a cutoff date (yesterday) for signal detection
    cutoff = Date(now()) - Day(1)

    # prepare the dataset containing the results from the queries
    df = prepare_queries_dataset(study_center)

    # build participant records based on the study center and query data
    participants = prepare_participants(study_center, df)

    # detect signals for participants, considering only data before the cutoff
    signals = detect_signals(participants, df; cutoff)

    # upload detected signals to REDCap
    upload_redcap(REDCapSignals, signals)

    # collect all unique signal receivers (can be strings or vectors)
    receivers = @chain signals begin
        @. receiver       # extract receiver(s) from each signal
        vcat(_...)        # flatten into a single vector
        unique            # remove duplicates
    end

    # iterate over each unique receiver (email)
    for email in receivers
        # select signals relevant to the current receiver and format them
        strings = @chain signals begin
            filter(
                x -> email == receiver(x) ||
                    (receiver(x) isa Vector && email in receiver(x)),
                _
            )
            @. format_signal
        end

        # send the formatted signals via email
        if email isa String
            # send directly to this email plus additional configured receivers
            send_signals_email(
                EMAIL_CREDENTIALS,
                [email, EMAIL_ADDITIONAL_RECEIVERS...],
                city,
                strings
            )
        else
            # if the receiver is not a single string, send only to default receivers
            send_signals_email(EMAIL_CREDENTIALS, EMAIL_ADDITIONAL_RECEIVERS, city, strings)
        end
    end
end

run_script(script, EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER)