
function ewma_smooth(y, λ, μ̂)
    N = length(y)

    # pre-allocate output vector
    z = zeros(N)

    # input vector is empty
    N == 0 && return z

    z[1] = λ * first(y) + (1 - λ) * μ̂

    for i in 2:N
        z[i] = λ * y[i] + (1 - λ) * z[i - 1]
    end

    return z
end

function control_limits(y, λ, L, μ̂, σ̂)
    deviations = L * σ̂ * sqrt.(λ / (2 - λ) * [1 - (1 - λ)^(2 * i) for i in eachindex(y)])

    lcl = μ̂ .- deviations
    ucl = μ̂ .+ deviations

    return lcl, ucl
end

isoutside(x, lcl, ucl) = (x .< lcl) .| (x .> ucl)

function statistical_process_control(y, baseline; λ, L)
    μ̂ = @chain y[baseline] begin
        skipmissing
        mean
    end

    σ̂ = @chain y[baseline] begin
        skipmissing
        std
    end

    x = fill_down(y)
    baseline_start = findfirst(baseline)

    ewma = ewma_smooth(x[baseline_start:end], λ, μ̂)
    lcl, ucl = control_limits(x[baseline_start:end], λ, L, μ̂, σ̂)

    return isoutside(ewma, lcl, ucl)
end

function statistical_process_control(df, variable; λ = 0.15, L = 2.536435)
    baseline_start = max(first(df.BaselineStart), first(df.Date))
    baseline_end = min(first(df.BaselineEnd), last(df.Date))
    baseline = map(x -> x >= baseline_start && x <= baseline_end, df.Date)

    return statistical_process_control(getproperty(df, variable), baseline; λ, L)
end