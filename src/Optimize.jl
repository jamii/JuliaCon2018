function map_query(f, constant::Constant)
    constant
end

function map_query(f, join::Join)
    Join(join.key, join.index, f(join.input))
end

function map_query(f, filter::Filter)
    Filter(filter.condition, f(filter.input))
end

function map_query(f, count::Count)
    Count(f(count.input))
end

@generated function map_expr(f, constructor, expr::Expr)
    quote
        constructor($(@splice fieldname in fieldnames(expr) begin
                      if fieldtype(expr, fieldname) <: Expr
                      :(f(expr.$fieldname))
                      elseif fieldtype(expr, fieldname) <: Vector{T} where {T <: Expr}
                      :(map(f, expr.$fieldname))
                      else
                      :(expr.$fieldname)
                      end
                      end))
    end
end

@generated function map_query(f, query::Query)
    quote
        $query($(@splice fieldname in fieldnames(query) begin
                 if fieldtype(query, fieldname) <: Query
                 quote f(query.$fieldname) end
                 else
                 quote query.$fieldname end
                 end
                 end))
    end
end

postwalk(f, query) = f(map_query(q -> postwalk(f, q), query))

using Rematch

function optimize(query::Query)
    @match query begin
        Filter(f, Filter(g, input)) => optimize(Filter((row) -> f(row) && g(row), input))
        _ => map_query(optimize, query)
    end
end
