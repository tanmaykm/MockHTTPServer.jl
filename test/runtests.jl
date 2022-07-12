using Test

include("basic_tests.jl")
include("server_tests.jl")

function runtests()
    @testset "MockHTTPServer" begin
        @testset "types" begin
            BasicTests.test_types()
        end
        @testset "server" begin
            ServerTests.test_mockhttpserver()
        end
    end
end

runtests()