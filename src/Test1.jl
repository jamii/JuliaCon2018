module Test1

using BenchmarkTools

abstract type Query end

struct Constant <: Query
    value
end

struct Join <: Query
    key::Int64
    index::Dict
    input::Query
end

struct Filter <: Query
    condition::Function
    input::Query
end

struct Count <: Query
    input::Query
end

@generated function get_row(columns::Tuple, r)
    :(tuple($((:(columns[$c][r]) for c in 1:length(columns.parameters))...)))
end

function Base.iterate(constant::Constant, state=nothing)
    state === nothing && (state = 1)
    state > length(constant.value[1]) && return nothing
    (get_row(constant.value, state), state+1)
end

function Base.iterate(join::Join, state=nothing)
    while true
        next = iterate(join.input, state)
        next === nothing && return nothing
        (input_row, state) = next
        join_row = get(join.index, input_row[join.key], nothing)
        join_row !== nothing && return ((input_row..., join_row...), state)
    end
end

function Base.iterate(filter::Filter, state=nothing)
    while true
        next = iterate(filter.input, state)
        next === nothing && return nothing
        (input_row, state) = next
        filter.condition(input_row) && return (input_row, state)
    end
end

function Base.iterate(count::Count, state=nothing)
    if state === nothing
        result = 0
        for _ in count.input
            result += 1
        end
        return ((result,), true)
    end
end

make_index(input, key) = Dict(((input[key][i], get_row(input, i)) for i in 1:length(input[1])))

function bench(holidays_events, train)
    @time begin
        query = Constant(train)
        query = Join(2, make_index(holidays_events, 1), query)
        query = Filter((row) -> row[end] === true, query)
        query = Count(query)
    end

    display(@benchmark iterate($query))
end

end
