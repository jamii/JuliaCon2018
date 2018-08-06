module JuliaCon2018

using Dates
using CSV
using DataFrames
using BenchmarkTools

# default hash causes allocation :(
Base.hash(date::Date, h::UInt) = hash(date.instant.periods.value, h)
const hash_nothing = hash(nothing)
Base.hash(::Nothing, h::UInt) = hash(hash_nothing, h)

include("Test1.jl")
include("Test2.jl")
include("Test3.jl")
include("Test4.jl")

function cache(f, key)
    try
        task_local_storage(key)
    catch
        task_local_storage(key, f())
    end
end

# empty!(task_local_storage())

function bench()
    holidays_events = @time cache(:holidays_events) do
        df = CSV.read("/home/jamie/.kaggle/competitions/favorita-grocery-sales-forecasting/holidays_events.csv", types=[Date, String, String, String, String, Bool], dateformat="yyyy-mm-dd", truestring="True", falsestring="False")
        tuple(DataFrames.columns(df)[[1,6]]...)
    end
    train = @time cache(:train) do
        df = CSV.read("/home/jamie/.kaggle/competitions/favorita-grocery-sales-forecasting/train-mini.csv", types=[Int64, Date, Int64, Int64, Float64, Union{Bool, Missing}], truestring="True", falsestring="False", dateformat="yyyy-mm-dd")
        tuple(DataFrames.columns(df)[[1,2]]...)
    end

    println("Test1")
    Test1.bench(holidays_events, train)
    println()

    println("Test2")
    Test2.bench(holidays_events, train)
    println()

    println("Test3")
    Test3.bench(holidays_events, train)
    println()

    println("Test4")
    Test4.bench(holidays_events, train)
    println()

    n = 1e9
    ints1 = collect(1:n)
    ints2 = collect(1:n)
    the_string = ""
    strings = String[the_string for _ in 1:n]

    println("Without allocation")
    big_table = (ints1, ints2)
    query = Test4.Count(Test4.Filter((row) -> row[1] > 1e8, Test4.Filter((row) -> row[1] > 1e8, Test4.Filter((row) -> row[1] > 1e8, Test4.Constant(big_table)))))
    display(@benchmark iterate($query, nothing))
    println()

    println("With allocation")
    big_table = (ints1, strings)
    query = Test4.Count(Test4.Filter((row) -> row[1] > 1e8, Test4.Filter((row) -> row[1] > 1e8, Test4.Filter((row) -> row[1] > 1e8, Test4.Constant(big_table)))))
    display(@benchmark iterate($query, nothing))
    println()

end

bench()

end
