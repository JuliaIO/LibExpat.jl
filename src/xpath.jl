const xpath_axes = (String=>Symbol)[
    "ancestor" => :ancestor,
    "ancestor-or-self" => :ancestor_or_self,
    "attribute" => :attribute,
    "child" => :child,
    "descendant" => :descendant,
    "descendant-or-self" => :descendant_or_self,
    "following" => :following,
    "following-sibling" => :following_sibling,
#    "namespace" => :namespace,
    "parent" => :parent,
    "preceding" => :preceding,
    "preceding-sibling" => :preceding_sibling,
    "self" => :self]

const xpath_types = (String=>Symbol)[
    "comment" => :comment,
    "text" => :text,
#    "processing-instruction" => :processing_instruction,
    "node" => :node]

const xpath_functions = (String=>(Symbol,Int,Int))[ # (name, min args, max args)
    #node-set
    "last" => (:last,0,0),
    "position" => (:position,0,0),
    "count" => (:count,0,1),

    #boolean
    "not" => (:not,1,1),
    "true" => (:true_,0,0),
    "false" => (:false_,0,0),
    "boolean" => (:bool,1,1),

    #string
    "string" => (:string_fn,0,1),
    "contains" => (:contains,2,2),

    #number
    #TODO: more functions
    ]

function consume_whitespace(xpath, k)
    #consume leading space
    while !done(xpath, k)
        c, k2 = next(xpath, k)
        if !isspace(c)
            break
        end
        k = k2
    end
    k
end

const xpath_separators = Set('+','(',')','[',']','<','>','!','=','|','/','*',',')

function xpath_parse{T<:String}(xpath::T)
    k = start(xpath)
    k, parsed = xpath_parse(xpath, k)
    if isa(parsed,(Symbol,Any))
        assert(parsed[1]::Symbol === :(|))
        parsed = push!(Array((Symbol, Any), 0), parsed)
    end
    if !done(xpath,k)
        error("failed to parse to the end of the xpath (stopped at $k)")
    end
    parsed::Vector{(Symbol,Any)}
end

function xpath_parse{T<:String}(xpath::T, k)
    parsed = Array((Symbol, Any), 0)
    k = consume_whitespace(xpath, k)
    if done(xpath,k)
        error("empty xpath expressions is not valid")
    end
    # 1. Consume root node
    c, k2 = next(xpath,k)
    if c == '/'
        push!(parsed, (:root,nothing))
        k = k2
    end
    first = true
    while !done(xpath,k)
        # i..j has text, k is current character
        havename::Bool = false
        axis::Symbol = :child
        colon::Int = 0
        doublecolon::Bool = false
        dot::Bool = false
        parens::Bool = false
        name::T = ""
        c, k2 = next(xpath,k)
        i = k
        j = 0
        if c == '/'
            push!(parsed, (:descendant_or_self, nothing))
            i = k = k2 #advance to next
        end
        # 2. Consume node name
        while !done(xpath,k)
            c, k2 = next(xpath,k)
            if c == ':'
                # 2a. Consume axis name
                if !havename && j == 0
                    error("unexpected : at $k $i:$j")
                end
                if colon != 0
                    if !havename
                        name = xpath[i:j]
                    end
                    if doublecolon
                        error("unexpected :: at $k")
                    end
                    havename = false
                    axis_ = get(xpath_axes, name, nothing)
                    if axis_ === nothing
                        error("unknown axis $name")
                    end
                    axis = axis_::Symbol
                    colon = 0
                    doublecolon = true
                    i = k2
                    j = 0
                else # colon == 0
                    colon = k
                end #if
            else # c != ":"
                if colon != 0
                    j = colon
                    colon = 0
                end #if
                # 2b. Consume node name
                if j == 0 && c == '*'
                    havename = true
                    name = "*"
                    i = k = k2
                    break
                elseif isspace(c) || contains(xpath_separators,c)
                    if j != 0
                        assert(!havename)
                        havename = true
                        name = xpath[i:j]
                        j = 0
                    end
                    if c == '('
                        k2 = consume_whitespace(xpath, k2)
                        if done(xpath,k2)
                            error("unexpected end to xpath after (")
                        end
                        c, k3 = next(xpath,k2)
                        if c != ')'
                            error("unexpected character in () at $k2")
                        end
                        k = k3
                        parens = true
                        break
                    elseif !isspace(c)
                        break
                    end #if
                    i = k2
                elseif havename # && !isspace && !separator
                    break
                elseif c == '-' && j == 0
                    error("TODO: -negation")
                else # text character
                    j = k
                end #if
            end #if
            k = k2
        end # if
        if !havename
            if j!=0
                havename = true
                name = xpath[i:j]
            elseif first != true
                if done(xpath,k)
                    error("xpath should not end with a /")
                end
                error("expected name before $c at $k")
            else
                break
            end
        elseif j!=0
            assert(false)
        end
        first = false
        if parens
            nodetype = get(xpath_types, name, nothing)
            if nodetype === nothing
                error("unknown node type or function $name at $k")
            end
            push!(parsed, (axis,nothing))
            push!(parsed, (:type,nodetype::Symbol))
        elseif name[1] == '.'
            if doublecolon
                error("xml names may not begin with a . (at $k)")
            elseif length(name) == 2 && name[2] == '.'
                push!(parsed, (:parent,nothing))
            elseif length(name) == 1
                push!(parsed, (:self,nothing))
            else
                error("xml names may not begin with a . (at $k)")
            end
        elseif name[1] == '@' || axis == :attribute
            if axis != :attribute
                k2 = consume_whitespace(name, 2)
                name = name[k2:end]
            end
            if name == "*"
                push!(parsed, (:attribute,nothing))
            else
                push!(parsed, (:attribute,name))
            end
        else
            push!(parsed, (axis,nothing))
            if name != "*"
                push!(parsed, (:name,name))
            end
        end #if
        while !done(xpath,k)
            c, k2 = next(xpath,k)
            if c == '/'
                k = k2
                if done(xpath,k)
                    error("xpath should not end with a /")
                end
                break
            elseif c == '|'
                k, parsed2 = xpath_parse(xpath, k2)
                return k, (:(|), (parsed, parsed2))
            elseif c == '['
                i = k
                k = k2
                k, filter, has_last_fn = xpath_parse_expr(xpath, k, 0)
                if has_last_fn
                    push!(parsed, (:filter_with_last, filter))
                else
                    push!(parsed, (:filter, filter))
                end
                k = consume_whitespace(xpath, k)
                if done(xpath, k)
                    error("unmatched ] at $i")
                end
                c, k2 = next(xpath, k)
                if (c != ']')
                    error("expected matching ] at $k for [ at $i, found $c")
                end
                k = k2
                if !done(xpath, k)
                    c, k2 = next(xpath, k)
                end
            else
                return k, parsed #hope something else can parse it
            end #if
        end #while
    end # while
    k, parsed
end # function

function xpath_parse_expr{T<:String}(xpath::T, k, precedence::Int)
    i = k = consume_whitespace(xpath, k)
    token::T = ""
    j = 0
    prevtokenspecial = true
    while !done(xpath, k)
        c, k2 = next(xpath, k)
        if prevtokenspecial && c == '*'
            nothing
        elseif c == '@' || c == ':' #TODO: this is wrong (both of them are approximations)
            prevtokenspecial = true
            k = k2
            continue
        elseif c == '"' || c == '\''
            c2::Char = 0
            while c2 != c
                j = k
                k = k2
                if done(xpath, k)
                    error("unterminated string literal $c at $k")
                end
                c2, k2 = next(xpath, k)
            end
            k = k2
            break
        elseif isspace(c) || contains(xpath_separators, c)
            if c == '/'
                j = k
            end
            break
        end
        prevtokenspecial = false
        j = k
        k = k2
    end
    if j == 0 || done(xpath, k)
        error("expected expression at $k")
    end
    k = consume_whitespace(xpath, k)
    if done(xpath, k)
        c = 0
        k2 = k
    else
        c, k2 = next(xpath, k)
    end
    has_fn_last::Bool = false
    local fn::(Symbol,Any)
    if '0' <= xpath[i] <= '9' || xpath[i] == '-'
        # parse token as a number
        num = parsefloat(xpath[i:j])
        fn = (:number, num)
    elseif xpath[i] == '"' || xpath[i] == '\''
        fn = (:string, xpath[next(xpath,i)[2]:j])
    elseif c == '('
        name = xpath[i:j]
        k, fn_, has_fn_last = consume_function(xpath, k2, name)
        if fn_ === nothing
            k, fn_ = xpath_parse(xpath, i)
            if fn_[end][1]::Symbol == :attribute
                if length(fn_) == 1
                    fn_ = fn_[end]
                else
                    fn_ = (:xpath_attr, fn_)
                end
            else
                fn_ = (:xpath, fn_)
            end
        end
        fn = fn_::(Symbol,Any)
    else
        k, fn_ = xpath_parse(xpath, i)
        if fn_[end][1]::Symbol == :attribute
            if length(fn_) == 1
                fn = fn_[end]::(Symbol,Any)
            else
                fn = (:xpath_attr, fn_)
            end
        else
            fn = (:xpath, fn_)
        end
    end
    k = consume_whitespace(xpath, k)
    while !done(xpath,k)
        c1,k1 = next(xpath,k)
        if c1 == ']' || c1 == ')' || c1 == ','
            break
        end
        if done(xpath,k2)
            error("unexpected end to xpath")
        end
        c2,k2 = next(xpath,k1)
        i = k #backup k
        if c1 == 'o' && c2 == 'r' # lowest precedence (0)
            if done(xpath,k2)
                error("unexpected end to xpath")
            end
            c3,k3 = next(xpath,k2)
            if !isspace(c3)
                error("expected a space after operator at $k")
            end
            op_precedence = 0
            op = :or
            k = k3

        elseif c1 == 'a' && c2 == 'n'
            if done(xpath,k2)
                error("unexpected end to xpath")
            end
            c3,k3 = next(xpath,k2)            
            if c3 != 'd'
                error("invalid operator $c at $k")
            end
            if done(xpath,k3)
                error("unexpected end to xpath")
            end
            c3,k2 = next(xpath,k3)
            if !isspace(c3)
                error("expected a space after operator at $k")
            end
            op_precedence = 1
            op = :and
            k = k3

        elseif c1 == '='
            op_precedence = 2
            op = :(=)
            k = k1
        elseif c1 == '!' && c2 == '='
            op_precedence = 2
            op = :(!=)
            k = k1
    
        elseif c1 == '>'
            op_precedence = 3
            if c2 == '='
                op = :(>=)
                k = k2
            else
                op = :(>)
                k = k1
            end
        elseif c1 == '<'
            op_precedence = 3        
            if c2 == '='
                op = :(<=)
                k = k2
            else
                op = :(<)
                k = k1
            end
    
        elseif c1 == '+'
            op_precedence = 4
            op = :(+)
            k = k1
        elseif c1 == '-'
            op_precedence = 4
            op = :(-)
            k = k1
    
        else # highest precedence (5) 
            if done(xpath,k2)
                error("unexpected end to xpath")
            end
            c3,k3 = next(xpath,k2)
            if done(xpath,k3)
                error("unexpected end to xpath")
            end
            op_precedence = 5
            if c1 == 'd' && c2 == 'i' && c3 == 'v'
                op = :div
            elseif c1 == 'm' && c2 == 'o' && c3 == 'd'
                op = :mod
            else
                error("invalid operator $c1 at $k")
            end
            c4,k = next(xpath,k3)
            if !isspace(c4)
                error("expected a space after operator at $k")
            end
        end
        if precedence > op_precedence
            k = i #restore k
            break
        end
        k, fn2, has_fn_last2 = xpath_parse_expr(xpath, k, op_precedence+1)
        k = consume_whitespace(xpath, k)
        fn = (:binop, (op, fn, fn2))
        has_fn_last |= has_fn_last2
    end
    return k, fn, has_fn_last
end

function consume_function(xpath, k, name)
    #consume a function call
    k = consume_whitespace(xpath, k)
    if done(xpath,k)
        error("unexpected end to xpath after (")
    end
    fntype = get(xpath_functions, name, nothing)
    if fntype === nothing
        return k, nothing, false
    end
    minargs = fntype[2]::Int
    maxargs = fntype[3]::Int
    args = Array((Symbol,Any), 0)
    c, k2 = next(xpath,k)
    if c == ','
        error("unexpected , in functions args at $k")
    end
    has_fn_last::Bool = (fntype[1] == :last)
    while c != ')'
        k, arg, has_fn_last2 = xpath_parse_expr(xpath, k, 0)
        push!(args, arg)
        has_fn_last |= has_fn_last2
        k = consume_whitespace(xpath, k)
        if done(xpath,k)
            error("unexpected end to xpath after (")
        end
        c, k2 = next(xpath, k)
        if c != ',' && c != ')'
            error("unexpected character $c at $k")
        end
        k = k2
    end
    if !(minargs <= length(args) <= maxargs)
        error("incorrect number of arguments for function $name (found $(length(args)))")
    end
    return k2, (fntype[1]::Symbol, args), has_fn_last
end
 
isroot(pd::ParsedData) = (pd.parent == pd)

immutable XPath{T<:String}
    # an XPath filter is a series of XPath segments implemented as
    # (:cmd, data) pairs. For example,
    # "//A/..//*[2]" should be parsed as:
    # [(:root,nothing), (:descendant_or_self,nothing), (:child,nothing), (:name,"A")),
    #  (:parent,nothing), (:descendant_or_self,nothing), (:child,nothing), (:filter,(:number,2))]
    # All data strings are expected to be of type T
    filter::Vector{(Symbol,Any)}
end

type XPath_Collector
    nodes::Vector{ParsedData}
    filter::Any
    index::Int
    function XPath_Collector()
        new(ParsedData[], nothing, 0)
    end
end

xpath{T<:String}(filter::T) = XPath{T}(xpath_parse(filter))

xpath{T<:String}(pd::ParsedData, filter::T) = xpath(pd, xpath(filter), ParsedData[])
xpath(pd::ParsedData, filter::XPath) = xpath(pd, filter, ParsedData[])
function xpath(pd::ParsedData, filter::XPath, output)
    xpath(pd, filter, filter.filter, 1, Int[], 1, XPath_Collector(), output)
    return output
end
function xpath{T<:String}(pd::Vector{ParsedData}, filter::T)
    xp = xpath(filter)
    output = ParsedData[]
    for ele in pd
        xpath(ele, xp, output)
    end
    return output
end

xpath_boolean(a::Bool) = a
xpath_boolean(a::Int) = a != 0
xpath_boolean(a::Float64) = a != 0 && !isnan(a)
xpath_boolean(a::String) = length(a) != 0
xpath_boolean(a::Vector{String}) = length(a) > 0
xpath_boolean(a::ParsedData) = true

xpath_number(a::Bool) = a?1:0
xpath_number(a::Int) = a
xpath_number(a::Float64) = a
xpath_number(a::String) = try parseint(a) catch ex NaN end
xpath_number(a::ParsedData) = xpath_number(string_value(a))

xpath_string(a::Bool) = string(a)
xpath_string(a::Int) = string(a)
function xpath_string(a::Float64)
    if a == 0
        return "0"
    elseif isinf(a)
        return (a<0? "-Infinity" : "Infinity")
    elseif isinteger(a)
        return string(int(a))
    else
        return string(a)
    end
end
xpath_string(a::String) = a
xpath_string(a::ParsedData) = string_value(a)
xpath_string(a::Vector{ParsedData}) = length(a) == 0 ? "" : string_value(a[1])

function xpath_expr{T<:String}(pd::ParsedData, xp::XPath{T}, filter::(Symbol,Any), position::Int, last::Int, output_hint::Type)
    op = filter[1]::Symbol
    args = filter[2]
    if op == :attribute
        if isa(args, Nothing)
            return pd.attr
        else
            attr = get(pd.attr, args::T, nothing)
            if attr === nothing
                return String[]
            else
                return String[attr]
            end
        end
    elseif op == :number
        return args
    elseif op == :string
        return args
    elseif op == :position
        assert(position > 0)
        return position
    elseif op == :last
        assert(last >= 0)
        return last
    elseif op == :count
        result = xpath_expr(pd, xp, args[1]::(Symbol,Any), position, last, Vector)::Vector
        return length(result)
    elseif op == :not
        return !(xpath_boolean(xpath_expr(pd, xp, args[1]::(Symbol,Any), position, last, Bool))::Bool)
    elseif op == :true_
        return true
    elseif op == :false_
        return false
    elseif op == :bool
        return xpath_boolean(xpath_expr(pd, xp, args[1]::(Symbol,Any), position, last, Bool))::Bool
    elseif op == :binop
        op = args[1]::Symbol
        if op == :and
            a = xpath_boolean(xpath_expr(pd, xp, args[2]::(Symbol,Any), position, last, Bool))::Bool
            if a
                return xpath_boolean(xpath_expr(pd, xp, args[3]::(Symbol,Any), position, last, Bool))::Bool
            end
            return false
        elseif op == :or
            a = xpath_boolean(xpath_expr(pd, xp, args[2]::(Symbol,Any), position, last, Bool))::Bool
            if a
                return true
            end
            return xpath_boolean(xpath_expr(pd, xp, args[3]::(Symbol,Any), position, last, Bool))::Bool
        end
        a = xpath_expr(pd, xp, args[2]::(Symbol,Any), position, last, Any)
        b = xpath_expr(pd, xp, args[3]::(Symbol,Any), position, last, Any)
        if op == :(+)
            return xpath_number(a) + xpath_number(b)
        elseif op == :(-)
            return xpath_number(a) - xpath_number(b)
        elseif op == :div
            return xpath_number(a) / xpath_number(b)
        elseif op == :mod
            return xpath_number(a) % xpath_number(b)
        else
            if !isa(a,Vector)
                a = (a,)
            end
            if !isa(b,Vector)
                b = (b,)
            end
            for a = a
                for b = b
                    if isa(a, ParsedData)
                        if isa(b, ParsedData)
                            #nothing
                        elseif isa(b, Int) || isa(b, Float64)
                            a = xpath_number(a)
                        elseif isa(b, Bool)
                            a = xpath_boolean(a)
                        elseif isa(b, String)
                            a = xpath_string(a)
                        else
                            assert(false)
                        end
                    elseif isa(b, ParsedData)
                        if isa(a, Int) || isa(a, Float64)
                            b = xpath_number(b)
                        elseif isa(a, Bool)
                            b = xpath_boolean(b)
                        elseif isa(a, String)
                            b = xpath_string(b)
                        else
                            assert(false)
                        end
                    end #if
                    if op == :(=) || op == :(!=)
                        if isa(a, Bool) || isa(b, Bool)
                            a = xpath_boolean(a)
                            b = xpath_boolean(b)
                        elseif isa(a, Int) || isa(b, Int)
                            a = xpath_number(a)
                            b = xpath_number(b)
                        else
                            a = xpath_string(a)
                            b = xpath_string(b)
                        end
                        if op == :(=)
                            if a == b
                                return true
                            end
                        else
                            if a != b
                                return true
                            end
                        end
                    else # op != :(=) && op != :(!=)
                        a = xpath_number(a)
                        b = xpath_number(b)
                        if op == :(>)
                            if a > b
                                return true
                            end
                        elseif op == :(>=)
                            if a >= b
                                return true
                            end
                        elseif op == :(<)
                            if a < b
                                return true
                            end
                        elseif op == :(<=)
                            if a <= b
                                return true
                            end
                        else
                            assert(false)
                        end
                    end #if
                end #for b
            end #for a
            return false
        end #if
    elseif op == :xpath
        if output_hint == Bool
            return xpath(pd, xp, args::Vector{(Symbol,Any)}, 1, Int[], 1, XPath_Collector(), Bool)
        elseif output_hint == Vector{ParsedData} || output_hint == Vector || output_hint == Any
            out = ParsedData[]
            xpath(pd, xp, args::Vector{(Symbol,Any)}, 1, Int[], 1, XPath_Collector(), out)
            return out
        else
            assert(false, "unexpected output hint $output_hint")
        end
    elseif op == :xpath_attr
        if output_hint == Bool
            return xpath(pd, xp, args::Vector{(Symbol,Any)}, 1, Int[], 1, XPath_Collector(), Bool)
        elseif output_hint == Vector{String} || output_hint == Vector || output_hint == Any
            out = String[]
            xpath(pd, xp, args::Vector{(Symbol,Any)}, 1, Int[], 1, XPath_Collector(), out)
            return out
        else
            assert(false)
        end
    elseif op == :string_fn
        if length(args) == 0
            a = xpath_string(pd)::String
        else
            a = xpath_string(xpath_expr(pd, xp, args[1]::(Symbol,Any), position, last, Any))::String
        end
        return a
    elseif op == :contains
        a = xpath_string(xpath_expr(pd, xp, args[1]::(Symbol,Any), position, last, Any))::String
        b = xpath_string(xpath_expr(pd, xp, args[2]::(Symbol,Any), position, last, Any))::String
        return !(isempty(search(a, b)))::Bool
    else
        error("invalid or unimplmented op $op")
    end
    assert(false)
end

function xpath{T<:String}(pd::ParsedData, xp::XPath{T}, filter::Vector{(Symbol,Any)}, index::Int, position::Vector{Int}, position_index::Int, collector::XPath_Collector, output)
    #return value is whether the node is counted for next position filter in sequence
    #implements axes: child, descendant, parent, ancestor, self, root, descendant-or-self, ancestor-or-self
    #implements filters: name
    if index > length(filter)
        if isa(output,Vector)
            if !contains(output,pd)
                push!(output, pd)
            end
        end
        return true
    end
    axis = filter[index][1]::Symbol
    name = filter[index][2]
    index += 1
    iscounted::Bool = false

    # FILTERS
    if axis == :filter
        s = length(position)+1
        if s <= position_index
            resize!(position, position_index)
            for i = s:position_index-1
                position[s] = -1
            end
            position[end] = 1
        else
            position[position_index] += 1
        end
        p = position[position_index]
        bool = xpath_expr(pd, xp, name, p, -1, Bool)
        if isa(bool, Int)
            iscounted = bool::Int == p
        elseif isa(bool, Vector{ParsedData})
            iscounted = length(bool::Vector{ParsedData}) != 0
        else
            iscounted = xpath_boolean(bool)::Bool
        end
        if iscounted
            iscounted = xpath(pd, xp, filter, index, position, position_index+1, collector, output)
        end

    elseif axis == :filter_with_last
        if collector.filter === nothing
            assert(collector.index == 0)
            collector.nodes = ParsedData[]
            collector.filter = name
            collector.index = index
        else
            assert(collector.filter === name)
            assert(collector.index === index)
        end
        push!(collector.nodes, pd)
        iscounted = false

    elseif axis == :attribute
        index -= 1
        if index != length(filter)
            error("attribute selector must be last in xpath")
        end
        attrs = xpath_expr(pd, xp, filter[index]::(Symbol,Any), -1, -1, Vector{String})::Vector{String}
        if isa(output, Vector)
            for attr in attrs
                if !contains(output,attr)
                    push!(output,attr)
                end
            end
        end
        return (length(attrs) > 0)::Bool

    elseif axis == :name
        if name::T == pd.name
            iscounted = xpath(pd, xp, filter, index, position, position_index, collector, output)
        else
            iscounted = false
        end

    # AXES
    else
        if axis == :root
            root = pd
            while !isroot(root)
                root = root.parent
            end
            iscounted = xpath(root, xp, filter, index, position, position_index, collector, output)
        elseif axis == :parent
            parent = pd.parent
            iscounted = xpath(parent, xp, filter, index, position, position_index, collector, output)
        elseif axis == :ancestor
            parent = pd
            while !isroot(parent)
                parent = parent.parent
                iscounted |= xpath(parent, xp, filter, index, position, position_index, collector, output)
            end
        elseif axis == :ancestor_or_self
            parent = pd
            iscounted = xpath(parent, xp, filter, index, position, position_index, collector, output)
            while !isroot(parent)
                parent = parent.parent
                iscounted |= xpath(parent, xp, filter, index, position, position_index, collector, output)
            end
        elseif axis == :self
            iscounted = xpath(pd, xp, filter, index, position, position_index, collector, output)
        elseif axis == :child
            for child in pd.elements
                if isa(child, ParsedData)
                    iscounted |= xpath(child, xp, filter, index, position, position_index, collector, output)
                end
            end
        elseif axis == :descendant
            iscounted |= xpath_descendant(pd, xp, filter, index, position, position_index, collector, output)
        elseif axis == :descendant_or_self
            iscounted = xpath(pd, xp, filter, index, position, position_index, collector, output)
            iscounted |= xpath_descendant(pd, xp, filter, index, position, position_index, collector, output)

        #TODO: more axes
        #elseif axis == :attribute
        #elseif axis == :following
        #elseif axis == :following-sibling
        #elseif axis == :preceding
        #elseif axis == :preceding-sibling

        #TODO: axis in xpath_types
    
        # ERROR - NO MATCH
        else
            error("encountered unsupported axis $axis")
        end
        while collector.filter !== nothing
            nodes = collector.nodes
            collector_filter = collector.filter::(Symbol,Any)
            collector_index = collector.index
            collector.filter = nothing
            collector.index = 0
            last = length(nodes)
            count = 1
            for pd = nodes
                if xpath_boolean(xpath_expr(pd, xp, collector_filter, count, last, Bool))
                    iscounted |= xpath(pd, xp, filter, collector_index, position, position_index, collector, output)
                end
                count += 1
            end
            clear!(nodes)
        end
        for i = position_index:length(position)
            if position[i] > 0
                position[i] = 0
            end
        end
    end
    return iscounted
end

function xpath_descendant(pd::ParsedData, xp::XPath, filter::Vector{(Symbol,Any)}, index::Int, position::Vector{Int}, position_index::Int, collector::XPath_Collector, output)
    iscounted = false
    for child in pd.elements
        if isa(child, ParsedData)
            iscounted |= xpath(child, xp, filter, index, position, position_index, collector, output)
            iscounted |= xpath_descendant(child, xp, filter, index, position, position_index, collector, output)
        end
    end
    iscounted
end

getindex(pd::ParsedData,x::String) = xpath(pd,x)
getindex(pd::Vector{ParsedData},x::String) = xpath(pd, x)

