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
#    "comment" => :comment,
    "text" => :text,
#    "processing-instruction" => :processing_instruction,
    "node" => :node]

const xpath_functions = (String=>(Symbol,Int,Int))[ # (name, min args, max args)
    "last" => (:last,0,0),
    "position" => (:position,0,0),
    "count" => (:count,0,1),
    "not" => (:count,1,1),
    "true" => (:count,0,0),
    "false" => (:count,0,0),
    "boolean" => (:bool,1,1),
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
    return k2, (:fn, (fntype[1]::Symbol, args)), has_fn_last
end

const xpath_separators = Set('+','(',')','[',']','<','>','!','=','|','/','*',',')

function xpath_parse{T<:String}(xpath::T)
    k = start(xpath)
    if done(xpath,k)
        error("xpath is empty")
    end
    if xpath[end] == '/'
        error("xpath should not end with a /")
    end
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
        error("empty xpath expression")
    end
    # 1. Consume root node
    c, k2 = next(xpath,k)
    if c == '/'
        push!(parsed, (:root,nothing))
        k = k2
    end
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
            else
                error("expected name before $c at $k")
            end
        elseif j!=0
            assert(0)
        end
        if parens
            nodetype = get(xpath_types, name, nothing)
            if nodetype === nothing
                error("unknown node type $name at $k")
            end
            push!(parsed, (axis,nothing))            
            push!(parsed, (:type, nodetype::Symbol))
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
                return k, parsed
            end #if
        end #if
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
    if '0' <= xpath[i] <= '9' || xpath[i] == '-'
        # parse token as a number
        token = xpath[i:j]
        num = 0
        neg = false
        if token[1] == '-'
            neg = true
            token = token[2:end]
        end
        for x = token
            if '0' <= x <= '9'
                num = num * 10 + (x-'0')
            else
                error("invalid numeric literal $x")
            end
        end
        if neg
            num = -num
        end
        fn = (:number, num)
    elseif xpath[i] == '"' || xpath[i] == '\''
        fn = (:string, xpath[next(xpath,i)[2]:j])
    elseif c == '('
        name = xpath[i:j]
        k, fn_, has_fn_last = consume_function(xpath, k2, name)
        if fn_ === nothing
            k, fn_ = xpath_parse(xpath, i)
            fn_ = (:xpath, fn_)
        end
        fn = fn_::(Symbol,Any)
    else
        k, fn_ = xpath_parse(xpath, i)
        fn = (:xpath, fn_)
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

        # lowest precedence (0)
        if c1 == 'o' && c2 == 'r'
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
            if done(xpath,k2)
                error("unexpected end to xpath")
            end
            c3,k2 = next(xpath,k2)
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
    
        # highest precedence (5) 
        else
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
        fn = (op, (fn, fn2))
        has_fn_last |= has_fn_last2
    end
    return k, fn, has_fn_last
end
 
isroot(pd::ParsedData) = (pd.parent == pd)

type XPath{T<:String}
    # an XPath filter is a series of XPath segments implemented as
    # (:cmd, data) pairs. For example,
    # "//A/..//*[2]" should be parsed as:
    # [(:root,nothing), (:descendant_or_self,nothing), (:child,nothing), (:name,SubString("A",1,1)),
    #  (:parent,nothing), (:descendant_or_self,nothing), (:child,nothing), (:filter,(:number,2))]
    # All data strings are expected to be of type SubString{T}
    #
    # An XPath may be reused by clearing the output vector
    filter::Vector{(Symbol,Any)}
    output::Vector{ParsedData}
    index::Int
    collector::Vector{ParsedData}
    collector_index::Int
    position_count::Vector{Int}
    position_index::Int
    function XPath(filter)
        new(filter, ParsedData[], 0, ParsedData[], 0, Int[], 0)
    end
end
show(xp::XPath) = show("XPath(",filter,')')

xpath{T<:String}(filter::T) = XPath{T}(xpath_parse(filter))

xpath{T<:String}(pd::ParsedData, filter::T) = xpath(pd, xpath(filter))

function xpath{T<:String}(pd::Vector{ParsedData}, filter::T)
    xp = xpath(filter)
    for ele in pd
        xpath(ele, xp)
    end
    return xp.output
end

function xpath(pd::ParsedData, filter::XPath)
    assert(filter.index == 0)
    assert(length(filter.collector) == 0)
    assert(filter.collector_index == 0)
    assert(filter.position_index == 0)
    assert(all(filter.position_count .== 1))
    xpath(pd, filter, 1)
    assert(filter.index == 0)
    assert(filter.collector_index == 0)
    assert(filter.position_index == 0)
    assert(all(filter.position_count .== 1))
    return filter.output
end

function xpath{T<:String}(pd::ParsedData, xp::XPath{T}, position::Int)
    #return value is whether the node is counted for next position filter in sequence
    #implements axes: child, descendant, parent, ancestor, self, root, descendant-or-self, ancestor-or-self
    #implements filters: position, name, attribute, attribute=, 
    if xp.index == length(xp.filter)
        if !contains(xp.output,pd)
            push!(xp.output, pd)
        end
        return true
    end
    iscounted = true
    xp.index += 1
    axis = xp.filter[xp.index][1]::Symbol
    name = xp.filter[xp.index][2]

    # FILTERS
    if axis == :name
        isfilter = true
        if name::SubString{T} == pd.name
            iscounted = xpath(pd, xp, position)
        else
            iscounted = false
        end
    elseif axis == :position
        isfilter = true
        op, pos = name::(Symbol, Int)
        if pos > 0
            if (op == :(=)  && position == pos) ||
               (op == :(!=) && position != pos) ||
               (op == :(<)  && position <  pos) ||
               (op == :(<=) && position <= pos) ||
               (op == :(>)  && position >  pos) ||
               (op == :(>=) && position >= pos)
                if xp.position_index == length(xp.position_count)
                    push!(xp.position_count, 1)
                end
                xp.position_index += 1
                count = xp.position_count[xp.position_index]
                if xpath(pd, xp, count)
                    xp.position_count[xp.position_index] += 1
                end
                xp.position_index -= 1
            end
        else
            if xp.collector_index == 0
                xp.collector = ParsedData[]
                xp.collector_index = xp.index
            else
                assert(xp.collector_index == xp.index)
            end
            push!(xp.collector, pd)
        end
    elseif axis == :attribute
        isfilter = true
        attr = name::SubString{T}
        if haskey(pd.attr, attr)
            iscounted = xpath(pd, xp, position)
        else
            iscounted = false
        end
    elseif axis == :attribute_eq
        isfilter = true
        attr, val = name::(SubString{T}, SubString{T})
        if get(pd.attr, attr, nothing) == val
            iscounted = xpath(pd, xp, position)
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
            xpath(root, xp, 1)
        elseif axis == :parent
            parent = pd.parent
            xpath(parent, xp, 1)
        elseif axis == :ancestor
            parent = pd
            count = 1
            while !isroot(parent)
                parent = pd.parent
                if xpath(parent, xp, count)
                    count += 1
                end
            end
        elseif axis == :ancestor_or_self
            parent = pd
            xpath(parent, xp, 1)
            count = 2
            while !isroot(parent)
                parent = pd.parent
                if xpath(parent, xp, count)
                    count += 1
                end
            end
        elseif axis == :self
            xpath(pd, xp, 1)
        elseif axis == :child
            count = 1
            for child in pd.elements
                if isa(child, ParsedData)
                    if xpath(child, xp, count)
                        count += 1
                    end
                end
            end
        elseif axis == :descendant
            xpath_descendant(pd, xp, 1)
        elseif axis == :descendant_or_self
            xpath(pd, xp, 1)
            xpath_descendant(pd, xp, 2)
    
        # ERROR - NO MATCH
        else
            error("encountered unsupported axis $axis")
        end
        for i = xp.position_index+1:length(xp.position_count)
            xp.position_count[i] = 1
        end
        while xp.collector_index != 0
            index = xp.index
            assert(xp.collector_index != 0)
            xp.index = xp.collector_index
            xp.collector_index = 0
            collector = xp.collector
            valid = true
            axis = xp.filter[xp.index][1]::Symbol
            op, pos = xp.filter[xp.index][2]::(Symbol,Int)
            assert(axis == :position)
            assert(pos <= 0)
            count = 1
            pos = length(collector) + pos
            if     (op == :(=))  range =   pos
            elseif (op == :(!=)) range =     1 : length(collector)
            elseif (op == :(<))  range =     1 : pos-1
            elseif (op == :(<=)) range =     1 : pos
            elseif (op == :(>))  range = pos+1 : length(collector)
            elseif (op == :(>=)) range =   pos : length(collector)
            end
            for i in range
                if i < 1 || i > length(collector)
                    continue
                end
                if (op != :(!=) || i != pos)
                    if xpath(collector[i], xp, count)
                       count += 1
                    end
                end
            end
            xp.index = index
        end
    end
    xp.index -= 1
    return iscounted
end

function xpath_descendant(pd::ParsedData, xp::XPath, count::Int)
    for child in pd.elements
        if isa(child, ParsedData)
            if xpath(child, xp, count)
                count += 1
            end
            count = xpath_descendant(child, xp, count)
        end
    end
    return count
end

getindex(pd::ParsedData,x::String) = xpath(pd,x)
getindex(pd::Vector{ParsedData},x::String) = xpath(pd, x)

