module ServerTests

using Test
using HTTP
using Sockets
using MockHTTPServer

const TESTS1 = [
    (method=:get, path="/basic_get_ok", handler=(req)->HTTP.Response(200, "OK")),
    (method=:post, path="/basic_post_ok", handler=(req)->HTTP.Response(200, "OK")),
    (method=:get, path="/headers", handler=(req)->HTTP.Response(200, ["test-header" => "test-value"]; body="OK")),
]
const TESTS2 = [
    (method=:get, path="/get_notfound", handler=(req)->HTTP.Response(404, "Not Found")),
    (method=(:get,:post), path="/get_servererror", handler=(req)->HTTP.Response(500, "Server Error")),
]
const TESTS3 = [
    (method=:get, path=r"/getall_[a-z]+", handler=(req)->HTTP.Response(200, "OK")),
    (method=:get, path=r"/getall_[0-9]+", handler=(req)->HTTP.Response(404, "Not Found")),
]
const TESTS3_TESTPATH = [
    (method=:get, path="/getall_abc", handler=(req)->HTTP.Response(200, "OK")),
    (method=:get, path="/getall_123", handler=(req)->HTTP.Response(404, "Not Found")),
]

function make_test_handlers(resp::HTTP.Response)
    handler1_params = (path="/test1", handler=(req)->resp)
    handler1 = MockHTTPServer.Handler(; handler1_params...)
    handler2 = MockHTTPServer.Handler(; path="/test2") do req
        return resp
    end
    handler3 = (method=:get, path="/test3", handler=(req)->resp)
    handler4 = (method=(:get,:put), path="/test4", handler=(req)->resp)
    handler5 = (method=[:get,:put], path="/test5", handler=(req)->resp, config="testconfig")

    return [handler1, handler2, handler3, handler4, handler5]
end

function wait_for_server(ctx::MockHTTPServer.Ctx; timeout::Real=120.0, pollint::Real=5.0)
    return timedwait(timeout; pollint=pollint) do
        sock = Sockets.connect(ctx.host, ctx.port)
        if isopen(sock)
            close(sock)
            return true
        else
            return false
        end
    end
end

function test_all(server_uri::String, tests)
    for test in tests
        methods = isa(test.method, Symbol) ? [test.method] : test.method
        for method in methods
            action = getproperty(HTTP, method)
            resp = action(server_uri * test.path; status_exception=false)
            check_resp = test.handler(nothing)
            @test resp.status == check_resp.status

            if test.path == "/headers"
                @test HTTP.header(resp, "test-header") == "test-value"
            end
        end
    end
end

function test_mockhttpserver()
    host = "127.0.0.1"
    port = 8080
    proto = "http"
    mockhttp = MockHTTPServer.Ctx(; host=host, port=port)
    server_uri = "$proto://$host:$port"

    @testset "mock" begin
        MockHTTPServer.with_mockhttpserver(mockhttp) do
            @test isempty(mockhttp.handlers)
            server_running = wait_for_server(mockhttp)
            @test :ok === server_running

            if server_running === :ok
                MockHTTPServer.with_mockhttpserver(mockhttp, TESTS1...) do
                    test_all(server_uri, TESTS1)
                end
                @test isempty(mockhttp.handlers)
                MockHTTPServer.with_mockhttpserver(mockhttp, TESTS2...) do
                    test_all(server_uri, TESTS2)
                end
                @test isempty(mockhttp.handlers)
                MockHTTPServer.with_mockhttpserver(mockhttp, TESTS3...) do
                    test_all(server_uri, TESTS3_TESTPATH)
                end
            end
            @test isempty(mockhttp.handlers)
        end
    end
end

end # module ServerTests
