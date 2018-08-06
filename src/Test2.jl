module Test2

using BenchmarkTools

struct Constant
    value
end

struct Join
    key::Int64
    index
    input
end

struct Filter
    condition
    input
end

struct Count
    input
end

lift(x) = Val{x}()
unlift(::Val{x}) where x = x

@generated function get_row(columns::Tuple, r)
    :(tuple($((:(columns[$c][r]) for c in 1:length(columns.parameters))...)))
end

function iterator(constant::Constant)
    quote
        (state=nothing) -> begin
            state === nothing && (state = 1)
            state > $(length(constant.value[1])) && return nothing
            (get_row($(constant.value), state), state+1)
        end
    end
end

function iterator(join::Join)
    quote
        let input_iterator = $(iterator(join.input))
            (state=nothing) -> begin
                while true
                    next = input_iterator(state)
                    next === nothing && return nothing
                    (input_row, state) = next
                    join_row = get($(join.index), input_row[$(join.key)], nothing)
                    join_row !== nothing && return ((input_row..., join_row...), state)
                end
            end
        end
    end
end

function iterator(filter::Filter)
    quote
        let input_iterator = $(iterator(filter.input))
            (state=nothing) -> begin
                while true
                    next = input_iterator(state)
                    next === nothing && return nothing
                    (input_row, state) = next
                    $(filter.condition)(input_row) && return (input_row, state)
                end
            end
        end
    end
end


function iterator(count::Count)
    quote
        let input_iterator = $(iterator(count.input))
            (state=nothing) -> begin
                if state === nothing
                    result = 0
                    next = input_iterator(nothing)
                    while next !== nothing
                        (_, state) = next
                        result += 1
                        next = input_iterator(state)
                    end
                    return ((result,), true)
                end
            end
        end
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

    # i = eval(iterator(query))
    # @code_warntype i(nothing)
    # i = eval(iterator(query.input))
    # @code_warntype i(nothing)
    # i = eval(iterator(query.input.input))
    # @code_warntype i(nothing)
    # i = eval(iterator(query.input.input.input))
    # @code_warntype i(nothing)

    begin
        query_iterator = eval(iterator(query))
        display(@benchmark Base.invokelatest($query_iterator, nothing))
    end
end

end
