
chunk(N, size) = [((i - 1) * size + 1):min(i * size, N) for i in 1:ceil(Int, N / size)]

format_cutoff_time(x) = string(x) * "Z"

format_compliance(x) = string(round(x * 100; digits = 2)) * "%"

format_compensation(x) = Printf.format(Printf.Format("%.2f"), x) * "€"
format_compensation(x::Int) = string(x) * "€"

function format_weeks(x)
    min, max = extrema(x)

    if min == max
        return string(max)
    else
        return join([min, max], "-")
    end
end

function format_signal(x)
    s = x.participant * " (" * x.study_center * ", " * x.group * "): " * string(typeof(x)) *
        "\n"

    for (variable, value) in x.data
        ismissing(value) && continue

        s *= variable * ": " * string(value) * "\n"
    end

    return s
end

function parse_value(T, x)
    if isnothing(x) || ismissing(x)
        return missing
    elseif typeof(x) == T
        return x
    else
        return parse(T, x)
    end
end

function parse_value(x, name, variables)
    index = findfirst(isequal(name), getproperty.(variables, :name))
    T = variables[index].type

    return parse_value(T, x)
end

parse_created_at(x) = DateTime(x[1:(end - 4)])

isvalid(x) = !isnothing(x) && !ismissing(x)

function last_valid(df, x, default)
    any(!ismissing, df[:, x]) ? coalesce(reverse(df[:, x])...) : default
end

lastdays(df, x, cutoff) = subset(df, :Date => ByRow(d -> d > cutoff - Day(x)))

function clean_movisensxs_id(x)
    value = tryparse(Int, x)

    if isnothing(value)
        return ""
    else
        return string(value)
    end
end

function clean_study_center(location, location_dresden)
    ismissing(location) && return missing

    if location == "1"
        ismissing(location_dresden) && return missing
        location_dresden == "1" && return "Dresden (UKD)"
        location_dresden == "2" && return "Dresden (FAL)"
    end

    location == "2" && return "Münster"
    location == "3" && return "Marburg"

    return missing
end

fill_down(x) = accumulate((a, b) -> coalesce(b, a), x; init = coalesce(x...))

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

camel2snakecase(x) = join(lowercase.(split(string(x), r"(?=[A-Z])")), "_")

snake2camelcase(x) = join(uppercasefirst.(split(x, "_")))