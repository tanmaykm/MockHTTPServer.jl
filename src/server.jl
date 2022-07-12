"""
    Handler(handler, path;
        method=Set([:get, :post, :put, :delete, :head, :patch, :options, :trace]))
    Handler(resp, path)

Creates a handler mock response for a specific request. Request can be matched
by HTTP method(s) and request path.

Where:
- `handler`: A function of the form of HTTP.Handler (takes a HTTP.Request and
        returns a HTTP.Response). If a HTTP.Response object is provided instead
        of a handler function, an appropriate handler function will be generated
        that just returns the provided response object
- `path`: The path to match against for the handler.
- `method`: The HTTP method(s) to match against for the handler.
"""
struct Handler
    method::Set{Symbol}
    path::String
    handler::Function

    function Handler(handler::Function, path::AbstractString;
            method = Set([:get, :post, :put, :delete, :head, :patch, :options, :trace]),
        )
        method_set = isa(method, Symbol) ? Set([method]) : Set(method)
        new(method_set, path, handler)
    end
end

Handler(resp::HTTP.Response, args...; kwargs...) = Handler((req)->resp, args...; kwargs...)
function Handler(f; path::Union{AbstractString,Nothing}=nothing, kwargs...)
    @assert path !== nothing
    @assert f !== nothing
    Handler(f, path; kwargs...)
end

function Handler(; handler::Union{Nothing,Function}=nothing, path::Union{AbstractString,Nothing}=nothing, kwargs...)
    @assert handler !== nothing
    @assert path !== nothing
    Handler(handler, path; kwargs...)
end

"""
    handlers(hlist...)

Creates an array of Handler instances from the provided specification.
Method parameters can be one of:
- Handler instances
- Dict with keys `:method`, `:path` and `:handler` which can be used to invoke the Handler constructor
- NamedTuple with fields `method`, `path` and `handler` which can be used to invoke the Handler constructor
"""
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

"""
    Ctx(hlist...; host="0.0.0.0", port=80, server_args=Dict())

Creates a context for initializing the HTTP server to use to respond to requests.

`hlist`: A list of Handler instances to use for the server.
`host`: The hostname to listen on.
`port`: The port to listen on.
`server_args`: A dictionary of arguments to pass to the underlying HTTP server.
"""
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

"""
    handlers!(ctx::Ctx, hlist...)

Replace the handlers of the context with the newly passed list of handlers
"""
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

"""
    isopen(ctx::Ctx)

Whether the server is listening
"""
function Base.isopen(ctx::Ctx)
    return (ctx.server !== nothing) && isopen(ctx.server)
end

"""
    close(ctx::Ctx)

Close the server and stop listening
"""
function Base.close(ctx::Ctx)
    if isopen(ctx)
        HTTP.close(ctx.server)
        ctx.server = nothing
    end
    return nothing
end

"""
    with_mockhttpserver(f, ctx::Ctx, hlist...)

Setup the mock HTTP server with handlers specified in `hlist` and run `f` with
the server open.

Nested `with_mockhttpserver` calls are allowed, and when the execution enters
a nested scope, the handlers are replaced with the ones specified for the
scope. On exit, the handlers are restored to the original values. The outermost
scope's exit closes the server.
"""
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
