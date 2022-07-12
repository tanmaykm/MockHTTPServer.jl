# MockHTTPServer.jl

Convenient mock HTTP server for testing HTTP APIs in Julia.

[![Build Status](https://github.com/tanmaykm/MockHTTPServer.jl/workflows/CI/badge.svg)](https://github.com/tanmaykm/MockHTTPServer.jl/actions?query=workflow%3ACI+branch%3Amain)


## Example

```julia
using MockHTTPServer, HTTP, Test
import MockHTTPServer: Ctx, with_mockhttpserver

mockhttp = Ctx(; host="127.0.0.1", port=8080);
server_uri = "http://127.0.0.1:8080";

with_mockhttpserver(mockhttp) do
    testset1 = [
        (method=:get, path="/get1", handler=(req)->HTTP.Response(200, "OK")),
        (method=:get, path="/post1", handler=(req)->HTTP.Response(200, "OK")),
    ]
    with_mockhttpserver(mockhttp, testset1...) do
        resp = HTTP.get(server_uri * "/get1")
        @test resp.status == 200
    end

    testset2 = [
        (method=:post, path="/post2", handler=(req)->HTTP.Response(200, "OK")),
        (method=:post, path="/get2", handler=(req)->HTTP.Response(200, "OK")),
    ]
    with_mockhttpserver(mockhttp, testset2...) do
        resp = HTTP.post(server_uri * "/post2")
        @test resp.status == 200
    end
end
```

## Details

A context encapsulates the HTTP server and its configuration to use to respond to requests.

```julia
    MockHTTPServer.Ctx(hlist...; host="0.0.0.0", port=80, server_args=Dict())
```

Where:
- `hlist`: A list of Handler instances to use for the server.
- `host`: The hostname to listen on.
- `port`: The port to listen on.
- `server_args`: A dictionary of arguments to pass to the underlying HTTP server.

A single handler can be created with the `MockHTTPServer.Handler` method. More convenient is the `MockHTTPServer.handlers` method that can
also create a bunch of handlers:

```julia
    MockHTTPServer.handlers(hlist...)
```

Creates an array of `MockHTTPServer.Handler` instances from the provided specification(s) in `hlist`.

Method parameters can be one of:
- `Handler` instances
- `Dict` with keys `:method`, `:path` and `:handler` which can be used to invoke the Handler constructor
- `NamedTuple` with fields `method`, `path` and `handler` which can be used to invoke the Handler constructor

Finally, the `with_mockhttpserver` method allows easy to use scopes to execute testcases.

```julia
    with_mockhttpserver(f, ctx::Ctx, hlist...)
```

It sets up the mock HTTP server with handlers specified in `hlist` and run `f` with the server open.

Nested `with_mockhttpserver` calls are allowed, and when the execution enters a nested scope, the handlers are replaced with the ones specified for the scope. On exit, the handlers are restored to the original values. The outermost scope's exit closes the server.
