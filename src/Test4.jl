module Test4

using BenchmarkTools

struct Constant{Value}
    value::Value
end

struct Join{Key, Index, Input}
    key::Key
    index::Index
    input::Input
end

struct Filter{Condition, Input}
    condition::Condition
    input::Input
end

struct Count{Input}
    input::Input
end

# lift(x) = @eval () -> $x
# unlift(x) = x()

# lift(x) = Val{x}
# unlift(::Type{Val{x}}) where {x} = x

lift(x) = Val{x}()
unlift(::Val{x}) where x = x

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
        join_row = get(join.index, input_row[unlift(join.key)], nothing)
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
        query = Join(lift(2), make_index(holidays_events, 1), query)
        query = Filter((row) -> row[end] === true, query)
        query = Count(query)
    end

    # @code_warntype iterate(query, nothing)
    # @code_warntype iterate(query.input, nothing)
    # @code_warntype iterate(query.input.input, nothing)
    # @code_warntype iterate(query.input.input.input, nothing)

    display(@benchmark iterate($query))
end

end
