module BasicTests

using Test
using HTTP
using Sockets
using MockHTTPServer

function make_test_handlers(resp::HTTP.Response)
    handler1_params = (path="/test1", handler=(req)->resp)
    handler1 = MockHTTPServer.Handler(; handler1_params...)
    handler2 = MockHTTPServer.Handler(; path="/test2") do req
        return resp
    end
    handler3 = (method=:get, path="/test3", handler=(req)->resp)
    handler4 = (method=(:get,:put), path="/test4", handler=(req)->resp)
    handler5 = (method=[:get,:put], path="/test5", handler=(req)->resp)

    return [handler1, handler2, handler3, handler4, handler5]
end

function test_handlers(resp::HTTP.Response, hlist::Vector{MockHTTPServer.Handler})
    @test length(hlist) == 5
    for idx in 1:length(hlist)
        @test hlist[idx].path == "/test$idx"
        @test (hlist[idx].handler)(nothing) === resp
    end
    @test hlist[1].method == Set([:get, :post, :put, :delete, :head, :patch, :options, :trace])
    @test hlist[3].method == Set([:get])
    @test hlist[4].method == Set([:get, :put])
    return nothing
end

function test_handler_constructor()
    resp = HTTP.Response(200, "OK")
    hlist = MockHTTPServer.handlers(make_test_handlers(resp)...)
    test_handlers(resp, hlist)
    return nothing
end

function test_mockhttp_constructor()
    mockhttp = MockHTTPServer.Ctx()
    resp = HTTP.Response(200, "OK")
    handlers_arr = make_test_handlers(resp)

    MockHTTPServer.handlers!(mockhttp, handlers_arr...)
    test_handlers(resp, mockhttp.handlers)
    return nothing
end

function test_types()
    test_handler_constructor()
    test_mockhttp_constructor()
end

end # module BasicTests