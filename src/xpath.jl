#TODO: accessing parents of attributes
#TODO: implement remaining xpath functions
#TODO: parenthesized expressions
#TODO: xmlns namespace parsing
#TODO: correct ordering of output
#TODO: $QName string interpolation
#TODO: &quot; and &apos;

# XPath Spec: http://www.w3.org/TR/xpath/

import Base: typeseq, |

const xpath_axes = Dict(
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
    "self" => :self)

const xpath_types = Dict(
    "comment" => (:comment,AbstractString),
    "text" => (:text,AbstractString),
#    "processing-instruction" => (:processing_instruction, ??),
    "node" => (:node,Any))

const xpath_functions = Dict( # (name, min args, max args)
    #node-set
    "last" => (:last,0,0,Int),
    "position" => (:position,0,0,Int),
    "count" => (:count,1,1,Int),
    "local-name" => (:local_name,0,1,AbstractString),
    #"namespace-uri" => (:namespace_uri,0,1,AbstractString),
    "name" => (:name,0,1,AbstractString),

    #string
    "string" => (:string_fn,0,1,AbstractString),
    "concat" => (:concat,2,typemax(Int),AbstractString),
    "starts-with" => (:startswith,2,2,Bool),
    "contains" => (:contains,2,2,Bool),
    "substring-before" => (:substring_before,2,2,AbstractString),
    "substring-after" => (:substring_after,2,2,AbstractString),
    "substring" => (:substring,2,3,AbstractString),
    "string-length" => (:string_length,0,1,Int),
    "normalize-space" => (:normalize_space,0,1,AbstractString),
    "translate" => (:translate,3,3,AbstractString),

    #boolean
    "boolean" => (:bool,1,1,Bool),
    "not" => (:not,1,1,Bool),
    "true" => (:true_,0,0,Bool),
    "false" => (:false_,0,0,Bool),
    #"lang" => (:lang,1,1,Bool),

    #number
    "number" => (:number_fn,0,1,Number),
    "sum" => (:sum,1,1,Float64),
    "floor" => (:floor,1,1,Int),
    "ceiling" => (:ceiling,1,1,Int),
    "round" => (:round,1,1,Float64))

macro xpath_str(xpath)
    xp, returntype = xpath_parse(xpath, true)
    :( XPath{$(typeof(xpath)), $(returntype)}($(xp)) )
end
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

const xpath_separators = Set(['+','(',')','[',']','<','>','!','=','|','/','*',','])

function xpath_parse{T<:AbstractString}(xpath::T, ismacro=false)
    k = start(xpath)
    k, parsed, returntype, has_last_fn = xpath_parse_expr(xpath, k, 0, ismacro)
    if !done(xpath,k)
        error("failed to parse to the end of the xpath (stopped at $k)")
    end
    return parsed, returntype
end

#function xpath_parse_filters{T<:AbstractString}(xpath::T)
#    k = consume_whitespace(xpath, start(xpath))
#    c,k = next(xpath,k)
#    if c != '['
#        error("expected first character of xpath filter to be a '['")
#    end
#    k, parsed, returntype, has_last_fn = xpath_parse_expr(xpath, k, 0, false)
#    if done(xpath,k)
#        error("unexpected end to xpath filter, expected a ']' (stopped at $k)")
#    end
#    c,k = next(xpath,k)
#    if !done(xpath,consume_whitespace(xpath,k)) || c != ']'
#        error("failed to parse to the end of the xpath filter (stopped at $k)")
#    end
#    return parsed, returntype
#end

macro xpath_parse(arg1, arg2)
    :(
        if $(esc(:ismacro))
            a2 = $(esc(arg2))
            if !isa(a2,Expr) && !isa(a2,AbstractString)
                a2 = Expr(:quote,a2)
            end
            $(esc(:parsed)) = Expr(:call, :push!, $(esc(:parsed)), Expr(:tuple,Expr(:quote,$(esc(arg1))),a2))
        else
            push!($(esc(:parsed))::Vector{SymbolAny}, ($(esc(arg1)),$(esc(arg2))))
        end
    )
end
macro xpath_fn(arg1, arg2)
    :(
        if $(esc(:ismacro))
            a2 = $(esc(arg2))
            if !isa(a2,Expr) && !isa(a2,AbstractString)
                a2 = Expr(:quote,a2)
            end
            Expr(:tuple,Expr(:quote,$(esc(arg1))),a2)
        else
            ($(esc(arg1)),$(esc(arg2)))
        end
    )
end

function xpath_parse{T<:AbstractString}(xpath::T, k, ismacro)
    if ismacro
        parsed = :(SymbolAny[])
    else
        parsed = SymbolAny[]
    end
    k = consume_whitespace(xpath, k)
    if done(xpath,k)
        error("empty xpath expressions is not valid")
    end
    # 1. Consume root node
    c, k2 = next(xpath,k)
    if c == '/'
        @xpath_parse :root :node
        k = k2
    end
    returntype::DataType = ETree
    first::Bool = true
    while !done(xpath,k)
        # i..j has text, k is current character
        havename::Bool = false
        axis::Symbol = :child
        colonpos::Int = 0
        doublecolon::Bool = false
        dot::Bool = false
        parens::Bool = false
        name::T = ""
        c, k2 = next(xpath,k)
        i = k
        j = 0
        if c == '/'
            @xpath_parse :descendant_or_self :node
            returntype = Any
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
                if colonpos != 0
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
                    colonpos = 0
                    doublecolon = true
                    i = k2
                    j = 0
                else # colon == 0
                    colonpos = k
                end #if
            else # c != ":"
                if colonpos != 0
                    j = colonpos
                    colonpos = 0
                end #if
                # 2b. Consume node name
                if j == 0 && c == '*'
                    havename = true
                    name = "*"
                    i = k = k2
                    break
                elseif isspace(c) || in(c, xpath_separators)
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
                            error("unexpected character before ) in nodetype() expression at $k2")
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
            @xpath_parse axis nodetype[1]::Symbol
            returntype = nodetype[2]::DataType
        elseif name[1] == '.'
            if doublecolon
                error("xml names may not begin with a . (at $k)")
            elseif length(name) == 2 && name[2] == '.'
                @xpath_parse :parent :element
                returntype = ETree
            elseif length(name) == 1
                @xpath_parse :self :node
            else
                error("xml names may not begin with a . (at $k)")
            end
        elseif name[1] == '@' || axis == :attribute
            if axis != :attribute
                k2 = consume_whitespace(name, 2)
                name = name[k2:end]
            end
            if name == "*"
                @xpath_parse :attribute nothing
            else
                @xpath_parse :attribute name
            end
            returntype = AbstractString
        elseif name[1] == '$'
            @xpath_parse axis :element
            @xpath_parse :name Expr(:call, :string, esc(Symbol(name[2:end])))
        else
            @xpath_parse axis :element
            if name != "*"
                @xpath_parse :name name
            end
            returntype = ETree
        end #if
        while !done(xpath,k)
            c, k2 = next(xpath,k)
            if isspace(c)
                k = k2
                continue
            elseif c == '/'
                if done(xpath,k)
                    error("xpath should not end with a /")
                #elseif returntype !== ETree # this is a valid XPath
                #    error("xpath has an unexpected / at $k -- previous selector does not return a Node")
                end
                k = k2
                break
            elseif c == '|'
                k, parsed2, rt2 = xpath_parse(xpath, k2, ismacro)
                if rt2 !== returntype
                    returntype = Any
                    #error("xpath return types on either side of | don't appear to match")
                end
                if ismacro
                    parsed = :( push!(SymbolAny[], (:(|), ($(parsed), $(parsed2)))) )
                else
                    parsed = push!(SymbolAny[], (:(|), (parsed, parsed2)))
                end
                return k, parsed, returntype
            elseif c == '['
                i = k
                k = k2
                k, filter, rettype, has_last_fn = xpath_parse_expr(xpath, k, 0, ismacro)
                if has_last_fn
                    @xpath_parse :filter_with_last filter
                else
                    @xpath_parse :filter filter
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
                return k, parsed, returntype #hope something else can parse it
            end #if
        end #while
    end # while
    return k, parsed, returntype
end # function

function xpath_parse_expr{T<:AbstractString}(xpath::T, k, precedence::Int, ismacro)
    i = k = consume_whitespace(xpath, k)
    j = 0
    prevtokenspecial = true
    while !done(xpath, k)
        c, k2 = next(xpath, k)
        if prevtokenspecial && c == '*'
            nothing
        elseif c == '@' || c == ':'
            prevtokenspecial = true
            k = k2
            continue
        elseif c == '"' || c == '\''
            c2::Char = 0
            escape = false
            while c2 != c && !escape
                if ismacro && c2 == '\\' && !escape
                    escape = true
                else
                    escape = false
                end
                j = k
                k = k2
                if done(xpath, k)
                    error("unterminated string literal $c at $k")
                end
                c2, k2 = next(xpath, k)
            end
            k = k2
            break
        elseif isspace(c) || in(c, xpath_separators)
            if c == '/'
                j = k
            end
            break
        end
        prevtokenspecial = false
        j = k
        k = k2
    end
    if j == 0
        error("expected expression at $k")
    end
    k = consume_whitespace(xpath, k)
    if done(xpath, k)
        c = '\0'
        k2 = k
    else
        c, k2 = next(xpath, k)
    end
    has_fn_last::Bool = false
    #if ismacro
    #    fn::Expr
    #else
    #    fn::SymbolAny
    #end
    if '0' <= xpath[i] <= '9' || xpath[i] == '-'
        # parse token as a number
        num = parse(Float64,xpath[i:j])
        fn = @xpath_fn :number num
        returntype = Number
    elseif xpath[i] == '"' || xpath[i] == '\''
        if ismacro
            str = PipeBuffer()
            sexpr = Expr(:call, :string)
            escape = false
            var = parenvar = false
            substr_k = next(xpath, i)[2]
            j = next(xpath, j)[2]
            while substr_k != j
                c, substr_k = next(xpath,substr_k)
                if var == true
                    if nb_available(str) == 0
                        if !parenvar && c == '('
                            parenvar = true
                            continue
                        end
                        if !isalpha(c) && c!="_"
                            error("invalid interpolation syntax at $substr_k")
                        end
                        write(str,c)
                        continue
                    elseif !isalnum(c) && c!='_' && c!='!'
                        push!(sexpr.args, Expr(:call,:string,esc(Symbol(String(take!(str))))))
                        var = false
                        if parenvar
                            if c != ')' # we aren't interested in writing a general purpose string parser
                                error("invalid interpolation syntax at $substr_k")
                            end
                            continue
                        end
                    else
                        write(str,c)
                        continue
                    end
                end
                if c == '\\'
                    if escape
                        write(str,c)
                    else
                        escape = true
                    end
                else
                    escape = false
                    if c == '$'
                        var = true
                        parenvar = false
                        nb_available(str) != 0 && push!(sexpr.args, String(take!(str)))
                    else
                        write(str,c)
                    end
                end
            end
            if var == true
                (nb_available(str) != 0 && !parenvar) || error("invalid interpolation syntax at $j")
                push!(sexpr.args, Expr(:call,:string,esc(Symbol(String(take!(str))))))
            else
                nb_available(str) != 0 && push!(sexpr.args, String(take!(str)))
            end
            if length(sexpr.args) == 1
                sexpr = ""
            elseif length(sexpr.args) == 2
                sexpr = sexpr.args[2]
            end
        else
            sexpr = xpath[next(xpath,i)[2]:j]
        end
        fn = @xpath_fn :string sexpr
        returntype = AbstractString
    else
        if c == '('
            name = xpath[i:j]
            k, fn_, returntype, has_fn_last = consume_function(xpath, k2, name, ismacro)
        else
            fn_ = nothing
        end
        if fn_ === nothing
            k, fn_, returntype = xpath_parse(xpath, i, ismacro)
            if typeseq(returntype, Any)
                fn_ = @xpath_fn :xpath_any fn_
            elseif typeseq(returntype, ETree)
                fn_ = @xpath_fn :xpath fn_
            elseif typeseq(returntype, AbstractString)
                if !ismacro && length(fn_) == 1 && fn_[1][1]::Symbol == :attribute
                    fn_ = fn_[1]
                else
                    fn_ = @xpath_fn :xpath_str fn_
                end
            else
                assert(false)
            end
            returntype = Vector{returntype}
        end
        if ismacro
            fn = fn_::Expr
        else
            fn = fn_::SymbolAny
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
            returntype = Bool

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
            returntype = Bool

        elseif c1 == '='
            op_precedence = 2
            op = :(=)
            k = k1
            returntype = Bool
        elseif c1 == '!' && c2 == '='
            op_precedence = 2
            op = :(!=)
            k = k2
            returntype = Bool

        elseif c1 == '>'
            op_precedence = 3
            if c2 == '='
                op = :(>=)
                k = k2
            else
                op = :(>)
                k = k1
            end
            returntype = Bool
        elseif c1 == '<'
            op_precedence = 3
            if c2 == '='
                op = :(<=)
                k = k2
            else
                op = :(<)
                k = k1
            end
            returntype = Bool

        elseif c1 == '+'
            op_precedence = 4
            op = :(+)
            k = k1
            returntype = Number
        elseif c1 == '-'
            op_precedence = 4
            op = :(-)
            k = k1
            returntype = Number

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
            returntype = Number
        end
        if precedence > op_precedence
            k = i #restore k
            break
        end
        k, fn2, rt2, has_fn_last2 = xpath_parse_expr(xpath, k, op_precedence+1, ismacro)
        k = consume_whitespace(xpath, k)

        if ismacro
            fn = Expr(:tuple,:(:binop),Expr(:tuple,Expr(:quote,op), fn, fn2))
        else
            fn = (:binop, (op, fn, fn2))
        end
        has_fn_last |= has_fn_last2
    end
    return k, fn, returntype, has_fn_last
end

function consume_function(xpath, k, name, ismacro)
    #consume a function call
    k = consume_whitespace(xpath, k)
    if done(xpath,k)
        error("unexpected end to xpath after (")
    end
    fntype = get(xpath_functions, name, nothing)
    if fntype === nothing
        return k, nothing, Void, false
    end
    minargs = fntype[2]::Int
    maxargs = fntype[3]::Int
    fnreturntype = fntype[4]::DataType
    if ismacro
        args = :(SymbolAny[])
    else
        args = SymbolAny[]
    end

    c, k2 = next(xpath,k)
    if c == ','
        error("unexpected , in functions args at $k")
    end
    has_fn_last::Bool = (fntype[1] == :last)
    len_args = 0
    while c != ')'
        k, arg, returntype, has_fn_last2 = xpath_parse_expr(xpath, k, 0, ismacro)
        if ismacro
            args = Expr(:call, :push!, args, arg)
        else
            push!(args, arg)
        end
        len_args += 1
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
    if !(minargs <= len_args <= maxargs)
        error("incorrect number of arguments for function $name (found $(length(args)))")
    end
    if ismacro
        fn = Expr(:tuple, Expr(:quote, fntype[1]::Symbol), args)
    else
        fn = (fntype[1]::Symbol, args)
    end
    return k2, fn, fnreturntype, has_fn_last
end



isroot(pd::ETree) = (pd.parent == pd)

immutable XPath{T<:AbstractString,
                returntype <: Union{Vector{ETree},
                      Vector{AbstractString},
                      Vector{Any},
                      Bool,
                      Number,
                      Int,
                      AbstractString,
                      Any}}
    # an XPath filter is a series of XPath segments implemented as
    # (:cmd, data) pairs. For example,
    # "//A/..//*[2]" should be parsed as:
    # [(:root,:element), (:descendant_or_self,:node), (:child,:element), (:name,"A")),
    #  (:parent,:element), (:descendant_or_self,:node), (:child,:element), (:filter,(:number,2))]
    # All data strings are expected to be of type T
    filter::SymbolAny
end

type XPath_Collector
    nodes::Vector{ETree}
    filter::Any
    index::Int
    function XPath_Collector()
        new(ETree[], nothing, 0)
    end
end

xpath{T<:AbstractString}(filter::T) = (xp = xpath_parse(filter); XPath{T,xp[2]}(xp[1]))

function xpath{T,returntype}(pd::Vector, xp::XPath{T,Vector{returntype}})
    output = returntype[]
    for ele in pd
        add = xpath_expr(ele, xp, xp.filter, 1, -1, Vector{returntype})::Vector{returntype}
        output = append!(output, setdiff(add, output))
    end
    return output::Vector{returntype}
end
function xpath{T,returntype}(pd::Vector, xp::XPath{T,returntype})
    output = returntype[]
    for ele in pd
        push!(output, xpath_expr(pd, xp, xp.filter, 1, -1, returntype)::returntype)
    end
    return output
end
xpath{T,returntype}(pd, xp::XPath{T,returntype}) = xpath_expr(pd, xp, xp.filter, 1, -1, returntype)::returntype
xpath{T<:AbstractString}(pd, filter::T) = xpath(pd, xpath(filter))

function xpath_combined_checked(pd1::XPath, pd2::XPath)
    a1 = pd1.filter[1]
    a2 = pd2.filter[1]
    if a1 == a2
        filt = a1
    else
        if !(( a1 == :xpath || a1 == :xpath_str || a1 == :xpath_any) &&
            (a2 == :xpath || a2 == :xpath_str || a2 == :xpath_any))
            error("can't combine xpath expressions that don't return XML nodes")
        end
        filt = :xpath_any
    end
    xp = SymbolAny[]
    push!(xp, (:(|),(pd1.filter[2], pd2.filter[2])))
    return (filt, xp)
end
|{T,S}(pd1::XPath{T}, pd2::XPath{S}) =
    XPath{Union{T,S},Any}( xpath_combined_checked(pd1,pd2) )
|{T,S,ret1<:Vector,ret2<:Vector}(pd1::XPath{T,ret1}, pd2::XPath{S,ret2}) =
    XPath{Union{T,S},Vector{Any}}( xpath_combined_checked(pd1,pd2) )
|{T,S,ret<:Vector}(pd1::XPath{T,ret}, pd2::XPath{S,ret}) =
    XPath{Union{T,S},ret}( xpath_combined_checked(pd1,pd2) )
|{T,S,ret}(pd1::XPath{T,ret}, pd2::XPath{S,ret}) =
    XPath{Union{T,S},ret}( xpath_combined_checked(pd1,pd2) )
#*{T,S,ret}(pd::XPath{T,ret}, filters::S) = XPath{Union{T,S},ret}( ??? )


xpath_boolean(a::Bool) = a
xpath_boolean(a::Int) = a != 0
xpath_boolean(a::Float64) = a != 0 && !isnan(a)
xpath_boolean(a::AbstractString) = !isempty(a)
xpath_boolean(a::Vector) = !isempty(a)
xpath_boolean(a::ETree) = true

xpath_number(a::Bool) = a ? 1 : 0
xpath_number(a::Int) = a
xpath_number(a::Float64) = a
xpath_number(a::AbstractString) = try parse(Float64,a) catch ex NaN end
xpath_number(a::Vector) = xpath_number(xpath_string(a))
xpath_number(a::ETree) = xpath_number(xpath_string(a))

xpath_string(a::Bool) = string(a)
xpath_string(a::Int) = string(a)
function xpath_string(a::Float64)
    if a == 0
        return "0"
    elseif isinf(a)
        return (a < 0 ?  "-Infinity" : "Infinity")
    elseif isinteger(a)
        return string(Int(a))
    else
        return string(a)
    end
end
xpath_string(a::AbstractString) = a
xpath_string(a::Vector) = length(a) == 0 ? "" : xpath_string(a[1])
xpath_string(a::ETree) = string_value(a)

function xpath_normalize(s::AbstractString)
    normal = IOBuffer()
    space = false
    first = false
    for c in s
        if isspace(c)
            if !space && first
                space = true
            end
        else
            if space
                write(normal,' ')
                space = false
            end
            if !first
                first = true
            end
            write(normal,c)
        end
    end
    String(take!(normal))
end

function xpath_translate(a::AbstractString,b::AbstractString,c::AbstractString)
    b = collect(b)
    c = collect(c)
    tr = IOBuffer()
    for ch in a
        i = findfirst(b,ch)
        if i == 0
            write(tr, ch)
        elseif i <= length(c)
            write(tr, c[i])
        end
    end
    String(take!(tr))
end

function xpath_expr{T<:AbstractString}(pd, xp::XPath{T}, filter::Tuple{Symbol,Any}, position::Int, last::Int, output_hint::DataType)
    op = filter[1]::Symbol
    args = filter[2]
    if op == :attribute
        if !isa(pd, ETree)
            return AbstractString[]
        elseif isa(args, Void)
            return pd.attr
        else
            attr = get(pd.attr, args::T, nothing)
            if attr === nothing
                return AbstractString[]
            else
                return AbstractString[attr]
            end
        end
    elseif op == :number
        return args::Number
    elseif op == :string
        return args::AbstractString
    elseif op == :position
        assert(position > 0)
        return position
    elseif op == :last
        assert(last >= 0)
        return last
    elseif op == :count
        result = xpath_expr(pd, xp, args[1]::SymbolAny, position, last, Vector)::Vector
        return length(result)
    elseif op == :not
        return !(xpath_boolean(xpath_expr(pd, xp, args[1]::SymbolAny, position, last, Bool))::Bool)
    elseif op == :true_
        return true
    elseif op == :false_
        return false
    elseif op == :bool
        return xpath_boolean(xpath_expr(pd, xp, args[1]::SymbolAny, position, last, Bool))::Bool
    elseif op == :binop
        op = args[1]::Symbol
        if op == :and
            a = xpath_boolean(xpath_expr(pd, xp, args[2]::SymbolAny, position, last, Bool))::Bool
            if a
                return xpath_boolean(xpath_expr(pd, xp, args[3]::SymbolAny, position, last, Bool))::Bool
            end
            return false
        elseif op == :or
            a = xpath_boolean(xpath_expr(pd, xp, args[2]::SymbolAny, position, last, Bool))::Bool
            if a
                return true
            end
            return xpath_boolean(xpath_expr(pd, xp, args[3]::SymbolAny, position, last, Bool))::Bool
        end
        a = xpath_expr(pd, xp, args[2]::SymbolAny, position, last, Any)
        b = xpath_expr(pd, xp, args[3]::SymbolAny, position, last, Any)
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
                    if isa(a, ETree)
                        if isa(b, ETree)
                            #nothing
                        elseif isa(b, Int) || isa(b, Float64)
                            a = xpath_number(a)
                        elseif isa(b, Bool)
                            a = xpath_boolean(a)
                        elseif isa(b, AbstractString)
                            a = xpath_string(a)
                        else
                            assert(false)
                        end
                    elseif isa(b, ETree)
                        if isa(a, Int) || isa(a, Float64)
                            b = xpath_number(b)
                        elseif isa(a, Bool)
                            b = xpath_boolean(b)
                        elseif isa(a, AbstractString)
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
        if typeseq(output_hint, Bool)
            return xpath(pd, :node, xp, args::Vector{SymbolAny}, 1, Int[], 1, XPath_Collector(), Bool)::Bool
        elseif typeseq(output_hint,Vector{ETree}) || typeseq(output_hint,Vector) || typeseq(output_hint,Any)
            out = ETree[]
            xpath(pd, :node, xp, args::Vector{SymbolAny}, 1, Int[], 1, XPath_Collector(), out)
            return out
        else
            assert(false, "unexpected output hint $output_hint")
        end
    elseif op == :xpath_str
        if typeseq(output_hint, Bool)
            return xpath(pd, :node, xp, args::Vector{SymbolAny}, 1, Int[], 1, XPath_Collector(), Bool)::Bool
        elseif typeseq(output_hint,Vector{AbstractString}) || typeseq(output_hint,Vector) || typeseq(output_hint,Any)
            out = AbstractString[]
            xpath(pd, :node, xp, args::Vector{SymbolAny}, 1, Int[], 1, XPath_Collector(), out)
            return out
        else
            assert(false)
        end
    elseif op == :xpath_any
        if typeseq(output_hint, Bool)
            return xpath(pd, :node, xp, args::Vector{SymbolAny}, 1, Int[], 1, XPath_Collector(), Bool)::Bool
        elseif typeseq(output_hint,Vector{Any}) || typeseq(output_hint,Vector) || typeseq(output_hint,Any)
            out = Any[]
            xpath(pd, :node, xp, args::Vector{SymbolAny}, 1, Int[], 1, XPath_Collector(), out)
            return out
        else
            assert(false, "unexpected output hint $output_hint")
        end
    elseif op == :string_fn
        if length(args) == 0
            a = xpath_string(pd)::AbstractString
        else
            a = xpath_string(xpath_expr(pd, xp, args[1]::SymbolAny, position, last, Any))::AbstractString
        end
        return a
    elseif op == :contains
        a = xpath_string(xpath_expr(pd, xp, args[1]::SymbolAny, position, last, Any))::AbstractString
        b = xpath_string(xpath_expr(pd, xp, args[2]::SymbolAny, position, last, Any))::AbstractString
        return !(isempty(search(a, b)))::Bool
    elseif op == :startswith
        a = xpath_string(xpath_expr(pd, xp, args[1]::SymbolAny, position, last, Any))::AbstractString
        b = xpath_string(xpath_expr(pd, xp, args[2]::SymbolAny, position, last, Any))::AbstractString
        return startswith(a,b)::Bool
    elseif op == :name
        if !isempty(args)
            a = xpath_expr(pd, xp, args[1]::SymbolAny, position, last, Vector)::Vector
            if isempty(a)
                return ""
            else
                return xpath_string(a[1])::AbstractString
            end
        else
            return xpath_string(pd)::AbstractString
        end
    elseif op == :concat
        a = IOBuffer()
        for arg = args
            write(a, xpath_string(xpath_expr(pd, xp, arg::SymbolAny, position, last, Any))::AbstractString)
        end
        return String(take!(a))::AbstractString
    elseif op == :substring_before
        a = xpath_string(xpath_expr(pd, xp, args[1]::SymbolAny, position, last, Any))::AbstractString
        b = xpath_string(xpath_expr(pd, xp, args[2]::SymbolAny, position, last, Any))::AbstractString
        i = first(search(a,b))
        if i < 1
            return ""
        else
            return a[1:prevind(a,i)]::AbstractString
        end
    elseif op == :substring_after
        a = xpath_string(xpath_expr(pd, xp, args[1]::SymbolAny, position, last, Any))::AbstractString
        b = xpath_string(xpath_expr(pd, xp, args[2]::SymbolAny, position, last, Any))::AbstractString
        i = last(search(a,b))
        if i < 1
            return ""
        else
            return a[nextind(a,i):end]::AbstractString
        end
    elseif op == :substring
        a = xpath_string(xpath_expr(pd, xp, args[1]::SymbolAny, position, last, Any))::AbstractString
        b = parse(Int, xpath_number(xpath_expr(pd, xp, args[2]::SymbolAny, position, last, Any)))::Int
        if length(args) > 2
            c = parse(Int, xpath_number(xpath_expr(pd, xp, args[3]::SymbolAny, position, last, Any)))::Int
            return a[chr2ind(a,b):chr2ind(a,c)]
        else
            return a[chr2ind(a,b):end]
        end
    elseif op == :string_length
        if isempty(args)
            a = xpath_string(pd)::AbstractString
        else
            a = xpath_string((xpath_expr(pd, xp, args[1]::SymbolAny, position, last, Any)))::AbstractString
        end
        return length(a)::Int
    elseif op == :normalize_space
        if isempty(args)
            a = xpath_string(pd)::AbstractString
        else
            a = xpath_string((xpath_expr(pd, xp, args[1]::SymbolAny, position, last, Any)))::AbstractString
        end
        return xpath_normalize(a)::AbstractString
    elseif op == :translate
        a = xpath_string(xpath_expr(pd, xp, args[1]::SymbolAny, position, last, Any))::AbstractString
        b = xpath_string(xpath_expr(pd, xp, args[2]::SymbolAny, position, last, Any))::AbstractString
        c = xpath_string(xpath_expr(pd, xp, args[3]::SymbolAny, position, last, Any))::AbstractString
        return xpath_translate(a,b,c)::AbstractString
    elseif op == :number_fn
        if isempty(args)
            return xpath_number(pd)::Number
        else
            return xpath_number(xpath_expr(pd, xp, args[1]::SymbolAny, position, last, Any))::Number
        end
    elseif op == :sum
        a = 0.0
        for n in xpath_expr(pd, xp, args[1]::SymbolAny, position, last, Vector)::Vector
            a += xpath_number(n)
        end
        return a::Float64
    elseif op == :floor
        a = ifloor(xpath_number(xpath_expr(pd, xp, args[1]::SymbolAny, position, last, Any))::Number)
        return a::Int
    elseif op == :ceiling
        a = iceil(xpath_number(xpath_expr(pd, xp, args[1]::SymbolAny, position, last, Any))::Number)
        return a::Int
    elseif op == :round
        a = xpath_number(xpath_expr(pd, xp, args[1]::SymbolAny, position, last, Any))::Number
        if -0.5 <= a < -0.0 || a === -0.0
            return -0.0
        else
            return floor(a+0.5)
        end
    else
        error("invalid or unimplmented op $op")
    end
    assert(false)
end

function xpath_output(pd::ETree, output)
    if isa(output,Vector)
        if !in(pd, output)
            push!(output, pd)
        end
    end
    xpath_boolean(pd)::Bool
end
function xpath_output(string::AbstractString, output)
    if isa(output,Vector)
        if !in(string, output)
            push!(output, string)
        end
    end
    xpath_boolean(string)::Bool
end
function xpath_output(strings::Vector{AbstractString}, output)
    if isa(output,Vector)
        for string in strings
            if !in(string, output)
                push!(output, string)
            end
        end
    end
    xpath_boolean(strings)::Bool
end

macro xpath(node)
    esc( :( iscounted |= xpath($(node), name::Symbol, xp, filter, index, position, position_index, collector, output) ) )
end
macro xpath_descendant(node)
    esc( :( iscounted |= xpath_descendant($(node), name::Symbol, xp, filter, index, position, position_index, collector, output) ) )
end
function xpath{T<:AbstractString}(pd, nodetype_filter::Symbol, xp::XPath{T}, filter::Vector{SymbolAny}, index::Int, position::Vector{Int}, position_index::Int, collector::XPath_Collector, output)
    #return value is whether the node is "true" for the input to a boolean function
    #implements axes: child, descendant, parent, ancestor, self, root, descendant-or-self, ancestor-or-self
    #implements filters: name
    if nodetype_filter === :element
        if !isa(pd, ETree)
            return false
        end
    elseif nodetype_filter === :comment
        error("xpath comments are not currently saved as part of the xml")
    elseif nodetype_filter === :text
        if !isa(pd, AbstractString)
            return false
        end
    else
        assert(nodetype_filter === :node)
    end
    if index > length(filter)
        return xpath_output(pd, output)
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
        bool = xpath_expr(pd, xp, name::SymbolAny, p, -1, Bool)
        if isa(bool, Int)
            iscounted = bool::Int == p
        elseif isa(bool, Float64)
            iscounted = bool::Float64 == p
        elseif isa(bool, Vector{ETree})
            iscounted = length(bool::Vector{ETree}) != 0
        else
            iscounted = xpath_boolean(bool)::Bool
        end
        if iscounted
            position_index += 1
            iscounted = false
            name = :node
            @xpath pd
        end

    elseif axis == :filter_with_last
        if collector.filter === nothing
            assert(collector.index == 0)
            collector.nodes = ETree[]
            collector.filter = name::SymbolAny
            collector.index = index
        else
            assert(collector.filter === name)
            assert(collector.index === index)
        end
        push!(collector.nodes, pd)
        iscounted = false

    elseif axis == :attribute
        attrs = xpath_expr(pd, xp, filter[index-1]::SymbolAny, -1, -1, Vector{AbstractString})::Vector{AbstractString}
        name = :node
        @xpath attrs

    elseif axis == :name
        if name::T == pd.name
            name = :node
            @xpath pd
        else
            iscounted = false
        end

    elseif axis == :(|)
        filter1 = name[1]::Vector{SymbolAny}
        filter2 = name[2]::Vector{SymbolAny}
        index = 1
        name = :node
        filter = filter1
        @xpath pd
        filter = filter2
        @xpath pd

    # AXES
    else
        if !isa(pd, ETree)
            return false
        end
        if axis == :root
            root = pd
            while !isroot(root)
                root = root.parent
            end
            @xpath root
        elseif axis == :parent
            @xpath pd.parent
        elseif axis == :ancestor
            parent = pd
            while !isroot(parent)
                parent = parent.parent
                @xpath parent
            end
        elseif axis == :ancestor_or_self
            parent = pd
            @xpath parent
            while !isroot(parent)
                parent = parent.parent
                @xpath parent
            end
        elseif axis == :self
            @xpath pd
        elseif axis == :child
            if name::Symbol == :node
                for (key,attr) in pd.attr
                    @xpath attr
                end
            end
            for child in pd.elements
                if isa(child, ETree)
                    @xpath child::ETree
                elseif isa(child, AbstractString)
                    @xpath child::AbstractString
                else
                    assert(false)
                end
            end
        elseif axis == :descendant
            @xpath_descendant pd
        elseif axis == :descendant_or_self
            @xpath pd
            @xpath_descendant pd

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
            collector_filter = collector.filter::SymbolAny
            index = collector.index
            name = :node
            collector.filter = nothing
            collector.index = 0
            last = length(nodes)
            count = 1
            for pd = nodes
                if xpath_boolean(xpath_expr(pd, xp, collector_filter, count, last, Bool))
                    @xpath pd
                end
                count += 1
            end
            empty!(nodes)
        end
        for i = position_index:length(position)
            if position[i] > 0
                position[i] = 0
            end
        end
    end
    return iscounted
end

function xpath_descendant(pd::ETree, name::Symbol, xp::XPath, filter::Vector{SymbolAny}, index::Int, position::Vector{Int}, position_index::Int, collector::XPath_Collector, output)
    iscounted = false
    for child in pd.elements
        if name::Symbol == :node
            for (key,attr) in pd.attr
                @xpath attr
            end
        end
        if isa(child, ETree)
            @xpath child::ETree
            @xpath_descendant child::ETree
        elseif isa(child, AbstractString)
            @xpath child::AbstractString
        else
            assert(false)
        end
    end
    iscounted
end

getindex(pd::ETree,x::AbstractString) = xpath(pd,x)
getindex(pd::ETree,x::XPath) = xpath(pd,x)
getindex(pd::Vector{ETree},x::AbstractString) = xpath(pd, x)
getindex(pd::Vector{ETree},x::XPath) = xpath(pd, x)
