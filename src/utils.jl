
chunk(N, size) = [((i - 1) * size + 1):min(i * size, N) for i in 1:ceil(Int, N / size)]

function make_cutoff(; x = now(), hour = 5, minute = 30)
    string(floor(x, Day) + Hour(hour) + Minute(minute)) * "Z"
end

fill_down(x) = accumulate((a, b) -> coalesce(b, a), x; init = coalesce(x...))

lastdays(df, x, cutoff) = subset(df, :Date => ByRow(d -> d > cutoff - Day(x)))

function clean_movisensxs_id(x)
    value = tryparse(Int, x)

    if isnothing(value)
        return ""
    else
        return string(value)
    end
end

function fill_dates(df::DataFrame)
    df_filled = @chain df begin
        groupby(:Participant)
        transform(
            :Date => minimum => :Start,
            All() => ((x...) -> Date(now()) - Day(1)) => :End;
            ungroup = false
        )
        combine([:Start, :End] => ((s, e) -> first(s):first(e)) => :Date)
    end

    @chain df begin
        outerjoin(df_filled; on = [:Participant, :Date])
        sort([:Participant, :Date])
    end
end

function isalarm(condition::Function, df::DataFrame,
        variables::Vector{Symbol}, cutoff::Date, distance::Int)
    nrow(df) == 0 || last(df.Date) != cutoff && return false

    xs = [getproperty(df, variable) for variable in variables]
    alarm = -distance

    for i in axes(df, 1)
        if condition(xs..., i) && i - alarm >= distance
            alarm = i
        end
    end

    return alarm == nrow(df)
end

function isalarm(
        condition::Function, df::DataFrame, variable::Symbol, cutoff::Date, distance::Int)
    isalarm(condition, df, [variable], cutoff, distance)
end

function is_symptom_free(phq9)
    critical = map(x -> x >= 10, phq9)
    symptom_free = falses(length(critical))

    for i in eachindex(symptom_free)
        i < 14 && continue

        # select the preceding 14-day window and remove missings
        values = filter(!ismissing, critical[(i - 13):i])

        # check if a maximum of half of the PHQ-9 sum scores are >= 10
        symptom_free[i] = count(values) <= length(values) / 2
    end

    return symptom_free
end

function determine_signals(df_data, df_participants, signals; cutoff = Date(now()) - Day(1))
    function nosignal(variables)
        (; (variables .=> [false, repeat([missing], length(variables) - 1)...])...)
    end

    @chain df_data begin
        subset(:Date => ByRow(x -> x <= cutoff))
        leftjoin(df_participants; on = :Participant)
        sort([:Participant, :Date])

        groupby(:Participant)
        combine(
            (AsTable(All()) => (
             df -> @chain df begin
                 DataFrame
                 subset(:InteractionDesignerGroup => ByRow(x -> x in signal.scope))
                 signal.f(cutoff)
                 isnothing(_) ? nosignal(signal.variables) : _
             end
     ) => AsTable for signal in signals)...;
            renamecols = false
        )

        leftjoin(df_participants; on = :Participant)
    end
end

function signals_to_strings(df, signals)
    strings = String[]

    for i in axes(df, 1)
        for variables in getfield.(signals, :variables)
            signal = df[i, first(variables)]

            if !ismissing(signal) && signal
                location = ismissing(df[i, :LocationDresden]) ? "" :
                           df[i, :LocationDresden] * ", "
                s = df[i, :Participant] * " (" * df[i, :City] * ", " * location *
                    df[i, :InteractionDesignerGroup] * "): " * string(first(variables)) *
                    "\n"

                for (j, variable) in enumerate(variables)
                    j == 1 && continue
                    ismissing(df[i, variable]) && continue

                    s *= string(variable) * ": " * string(df[i, variable]) * "\n"
                end

                push!(strings, s)
            end
        end
    end

    return strings
end

print_signals(df, signals) = print(signals_to_strings(df, signals)...)

camel2snakecase(x) = join(lowercase.(split(string(x), r"(?=[A-Z])")), "_")

snake2camelcase(x) = join(uppercasefirst.(split(x, "_")))

function make_feedback_B01_html(data, df_participants, city)
    html = Hyperscript.Node[]

    for participant in data["participants"]
        id = participant["pseudonym"]
        index = findfirst(isequal(id), df_participants.Participant)
        group = df_participants.InteractionDesignerGroup[index]

        items = sum(
            @chain dict begin
                getindex("values")
                filter(x -> !isnothing(x["value"]), _)
                length
            end
        for (_, dict) in participant["variableValues"]
        )

        df = @chain participant["variableValues"] begin
            filter(x -> last(x)["displayName"] == "event_negative", _)
            values
            only
            getindex("values")

            DataFrame(
                :DateTime => getindex.(_, "createdAt"),
                :Value => getindex.(_, "value")
            )
            transform(:DateTime => ByRow(x -> DateTime(x[1:(end - 4)])); renamecols = false)
            transform(:DateTime => ByRow(x -> Time(x) <= Time("05:30") ? Date(x) - Day(1) : Date(x)) => :Date)

            groupby(:Date)
            combine(:Value => (x -> count(!isnothing, x)) => :Responded)

            last(7)
            transform(:Responded => ByRow(x -> B01_COMPENSATION[min(x, 5)]) => :Compensation)

            push!(_, ["Total", sum(_.Responded), sum(_.Compensation)]; promote = true)

            transform(
                :Compensation => (x -> Printf.format.(Ref(Printf.Format("%.2f")), x) .* "€");
                renamecols = false
            )
        end

        percentage = round(100 * items / (73 * nrow(df)); digits = 2)

        push!(
            html,
            make_paragraph(
                """$id ($city, $group)
                Number of completed B01 items: $items ($percentage%)"""
            ),
            make_table(df)
        )
    end

    return html
end

function make_feedback_S01_html(df, df_participants, city)
    html = Hyperscript.Node[]

    for id in unique(df.Participant)
        index = findfirst(isequal(id), df_participants.Participant)
        group = df_participants.InteractionDesignerGroup[index]

        df_participant = @chain df begin
            subset(:Participant => ByRow(isequal(id)))
            transform(:Compliance => ByRow(x -> string(x) * "%"); renamecols = false)
            select(Not(:Participant))
        end

        push!(
            html,
            make_paragraph(
                """$id ($city, $group)
                S01 compliance"""
            ),
            make_table(df_participant)
        )
    end

    return html
end