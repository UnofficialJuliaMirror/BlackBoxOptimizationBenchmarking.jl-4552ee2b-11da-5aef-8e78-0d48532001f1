using Optim, BlackBoxOptim, NLopt, PyCall

import BlackBoxOptimizationBenchmarking: minimizer, minimum, optimize
import Base.string

# Define optimize, minimum and minimizer for each optimizer

## NLopt

type NLoptOptimMethod 
    s::Symbol
end
string(opt::NLoptOptimMethod) = string("NLopt.",opt.s)

function optimize(NLmeth::NLoptOptimMethod,f,D,run_length)  
    opt = Opt(NLmeth.s, D)
    min_objective!(opt, (p,g) -> f(p) ) #NLopt expect gradient
    maxeval!(opt,run_length)
    minf,minx,ret = NLopt.optimize(opt, pinit(D))
    return NLmeth, minx, minf
end
minimum(mfit::Tuple{NLoptOptimMethod,Array{Float64,1},Float64}) = mfit[3]
minimizer(mfit::Tuple{NLoptOptimMethod,Array{Float64,1},Float64}) = mfit[2]

#opt = Opt(:LN_BOBYQA, 3)
#min_objective!(opt,(p,g)->BBOBFunctions.F1.f(p))
#maxeval!(opt,1000)
#minf,minx,ret = NLopt.optimize(opt, pinit(D))

## python cma

    @pyimport cma
    
    struct PyCMA
    end

    function optimize(m::PyCMA,f,D,run_length) 
        es = cma.CMAEvolutionStrategy(pinit(D), 1, Dict("verb_disp"=>0,"maxiter"=>run_length))
        mfit = es[:optimize](f)[:result]
        (mfit[1],mfit[2])
    end

    string(m::PyCMA) = "PyCMA"
  
## scipy

    @pyimport scipy.optimize as scipy_opt

    struct PyMinimize
        method::String
    end

    optimize(m::PyMinimize,f,D,run_length) = scipy_opt.minimize(
        f, pinit(D),method=m.method,
        options = Dict(
            "maxfev"=>run_length,"xatol"=>1e-8,"fatol"=>1e-8,
            "maxiter"=>run_length,"gtol"=>1e-12,
        )
    )
    minimum(mfit::Dict{Any,Any}) = mfit["fun"]
    minimizer(mfit::Dict{Any,Any}) = mfit["x"]
    
    string(m::PyMinimize) = string("Py.",m.method)

## my cmaes

    include("cmaes.jl")
    using CMAES

    type CMAESoptim end

    optimize(::Type{CMAESoptim},f,D,run_length) = CMAES.cmaes(f, pinit(D), 3.0, run_length, round(Int, 3 + floor(3log(D))))
    minimum(mfit::Tuple{Array{Float64,1},Float64}) = mfit[2]
    minimizer(mfit::Tuple{Array{Float64,1},Float64}) = mfit[1]

## Optim

    optimize(opt::Optim.Optimizer,f,D,run_length) =
        Optim.optimize(f, pinit(D), opt, Optim.Options(f_calls_limit=run_length,g_tol=1e-12))
        
    minimum(mfit::Optim.OptimizationResults) = mfit.minimum
    minimizer(mfit::Optim.OptimizationResults) = mfit.minimizer

    string(opt::Optim.Optimizer) = string(typeof(opt).name)

    # Optim with restart
    try 
        type OptimRestart{T}
            opt::T
        end
    end

    function optimize(opt::OptimRestart,f,D,run_length) 
        fits = [optimize(opt.opt,f,D,round(Int,run_length/20)) for i=1:20]
        mins = [minimum(fit) for fit in fits]
        fits[indmin(mins)]
    end

    string(opt::OptimRestart) = string("R-",string(opt.opt))

## BlackBoxOptim

    type BlackBoxOptimMethod 
        s::Symbol
    end
    string(opt::BlackBoxOptimMethod) = string("BBO.",opt.s)
    
    box(D) = fill((-5.0, 5.0),D)
    pinit(D) = 10*rand(D)-5

    optimize(method::BlackBoxOptimMethod,f,D,run_length) =
        bboptimize(f; SearchRange=box(D), NumDimensions=D, Method=method.s, MaxFuncEvals=run_length, TraceMode=:silent)

    minimum(mfit::BlackBoxOptim.OptimizationResults) = best_fitness(mfit)
    minimizer(mfit::BlackBoxOptim.OptimizationResults) = best_candidate(mfit)