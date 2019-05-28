using Statistics
using LinearAlgebra

Spot = 36
σ = 0.2
n = 100000
m = 10
K = 40
r = 0.06
T = 1
order = parse(Int, ARGS[1])
Δt = T / m

function first_one(x)
    original = x
    x = x .> 0.
    n_columns = size(x, 2)
    batch_size = size(x, 1)
    x_not = 1 .- x
    sum_x = min.(cumprod(x_not, dims=2), 1.)
    ones_arr = ones(batch_size)
    lag = sum_x[:, 1:(n_columns - 1)]
    lag = hcat(ones_arr, lag)
    return original .* (lag .* x)
end

function chebyshev_basis(x, k)
    B = ones(size(x, 1), k)
    B[:,2] = x
    for n in range(3, stop = k)
        B[:,n] = 2 .* x .* B[:,n - 1] .- B[:,n - 2]
    end
    return B
end

function ridge_regression(X, Y, λ)
    id = Matrix{Float64}(I, order, order)
    β = (X' * X + λ * id) \ (X' * Y)
    return X * β
end


function scale(x)
    xmin = minimum(x)
    xmax = maximum(x)
    a = 2 / (xmax - xmin)
    b = -0.5 * a * (xmin + xmax)
    return a .* x .+ b
end

function where(cond, value_if_true, value_if_false)
    out = value_if_true .* cond + .!cond .* value_if_false
end

function advance(S)
    dB = sqrt(Δt) * randn(Float64, (n))
    out = S .+ r .* S .* Δt .+ σ .* S .* dB
    return out
end


function main()
    S = zeros(n, m + 1)
    S[:, 1] = Spot * ones(n, 1)

    for t = 1:m
        S[:, t + 1] = advance(S[:, t])
    end

    discount = exp(-r * Δt)
    CFL = max.(0, K .- S)

    value = zeros(n, m)
    value[:, end] = CFL[:, end] * discount
    CV = zeros(n, m)

    for k = 1:m -1
        t = m - k
        t_next = t + 1

        XX = chebyshev_basis(scale(S[:, t_next]), order)
        YY = value[:, t_next]
        CV[:, t] = ridge_regression(XX, YY, 100)

        value[:, t] = discount * where(CFL[:, t_next] .> CV[:, t], CFL[:, t_next], value[:, t_next])
    end

    POF = where(CV .< CFL[:, 2:end], CFL[:, 2:end], 0 * CFL[:, 2:end])';

    FPOF = first_one(POF')'
    m_range = collect(range(0; stop=m-1, step = 1))
    dFPOF = (FPOF.*exp.(-r*m_range*Δt))
    PRICE = sum(dFPOF) / n
    return PRICE
end

main();
t0 = time();
for i =1:10
    main();
end
t1 = time()
out = (t1 - t0) / 10

println(out * 4 * 1000)  # Multiply by four bc we need the greeks