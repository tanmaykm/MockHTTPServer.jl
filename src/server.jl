struct Handler
    method::Set{Symbol}
    path::String
    config::Any
    handler::Function

    function Handler(handler::Function, path::AbstractString;
            method = Set([:get, :post, :put, :delete, :head, :patch, :options, :trace]),
            config = nothing
        )
        method_set = isa(method, Symbol) ? Set([method]) : Set(method)
        new(method_set, path, config, handler)
    end
end

Handler(resp::HTTP.Response, args...; kwargs...) = Handler((req)->resp, args...; kwargs...)
Handler(f; path::AbstractString, kwargs...) = Handler(f, path; kwargs...)

function Handler(; handler::Union{Nothing,Function}=nothing, path::AbstractString, kwargs...)
    @assert handler !== nothing
    Handler(handler, path; kwargs...)
end

function handlers(hlist...)
    handler_vec = Handler[]
    for handler in hlist
        if isa(handler, Handler)
            push!(handler_vec, handler)
        elseif isa(handler, Dict)
            push!(handler_vec, Handler(; handler...))
        elseif isa(handler, NamedTuple)
            push!(handler_vec, Handler(; handler...))
        else
            error("Invalid handler type: $(typeof(handler))")
        end
    end
    return handler_vec
end

mutable struct Ctx
    host::String
    port::Int
    server_args::Dict{Symbol, Any}
    handlers::Vector{Handler}
    server::Union{Nothing, HTTP.Servers.Server}

    function Ctx(hlist...; host::String="0.0.0.0", port::Int=80, server_args=Dict{Symbol, Any}())
        new(host, port, server_args, handlers(hlist...), nothing)
    end
end

function handlers!(ctx::Ctx, hlist...)
    ctx.handlers = handlers(hlist...)
    return ctx
end

function handle(ctx::Ctx, req::HTTP.Request)
    @debug("finding handler for", req.method, req.target)
    method = Symbol(lowercase(req.method))
    for handlerspec in ctx.handlers
        if (method in handlerspec.method) && req.target == handlerspec.path
            return handlerspec.handler(req)
        end
    end
    return HTTP.Response(404, "Not Found")
end

function Base.isopen(ctx::Ctx)
    return (ctx.server !== nothing) && isopen(ctx.server)
end

function Base.close(ctx::Ctx)
    if isopen(ctx)
        HTTP.close(ctx.server)
        ctx.server = nothing
    end
    return nothing
end

function with_mockhttpserver(f, ctx::Ctx, hlist...)
    # setup/replace handlers
    old_handlers = ctx.handlers
    handlers!(ctx, hlist...)

    # setup HTTP server, if not done yet
    opened_server = false
    if !isopen(ctx)
        ctx.server = HTTP.serve!(ctx.host, ctx.port; ctx.server_args...) do req
            handle(ctx, req)
        end
        opened_server = true
    end

    try
        f()
    finally
        # close server if it was opened in this scope
        opened_server && close(ctx)
        ctx.handlers = old_handlers
    end
end
