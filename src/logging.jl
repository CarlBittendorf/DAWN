
function start_logging(filename, minlevel = MiniLoggers.Info)
    MiniLogger(
        io = filename;
        errlevel = MiniLoggers.AboveMaxLevel,
        minlevel = minlevel,
        format = "╭{[{timestamp}] - {level} - :func}{{module}@{basename}:{line:cyan}:light_green}\n╰→ {message}"
    ) |> global_logger
end

function run_script(script, credentials, receivers)
    # use the current date and time as filename
    filename = "logs/" * Dates.format(now(), "yyyy-mm-ddTHH-MM-SS") * ".txt"

    start_logging(filename)

    try
        script()
        @info "Finished running script."

    catch e
        @error (e, catch_backtrace())

        message = sprint(showerror, e)

        send_error_email(credentials, receivers, message, filename)
    end
end