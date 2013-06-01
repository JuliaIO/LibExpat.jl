
const xpath_delim = Set('[','/')

function xpath_parse{T}(xpath::T)
    parsed = Array((Symbol,Any),0)
    first = 1
    if xpath[1] == '/'
        push!(parsed, (:root,nothing))
        first += 1
    end
    while first <= length(xpath)
        if xpath[first] == '/'
            push!(parsed, (:descendant_or_self,nothing))
            first += 1
            if first > length(xpath)
                break
            end
        end
        if xpath[first] == '['
            error("encountered unexpected [")
        elseif xpath[first] == '.'
            if first+1 <= length(xpath) && xpath[first+1] == '.'
                push!(parsed, (:parent,nothing))
                first += 2
            else
                #push!(parsed, (:self,nothing))
                first += 1
            end
        elseif xpath[first] == '*'
            push!(parsed, (:child,nothing))
            first += 1
        else
            last = search(xpath, xpath_delim, first+1)
            if last == 0
                last = length(xpath)+1
            end
            section = SubString(xpath, first, last-1)
            #if contains(section,"::")
            #end
            push!(parsed, (:child,nothing))
            push!(parsed, (:name,section))
            first = last
        end
        while first <= length(xpath) && xpath[first] == '['
            count = 1
            last = first
            while count > 0
                last += 1
                if xpath[last] == '['
                    count += 1
                elseif xpath[last] == ']'
                    count -= 1
                end
            end
            push!(parsed, xpath_parse_expr(SubString(xpath, first+1, last-1))::(Symbol,Any))
            first = last + 1
        end
        if first <= length(xpath)
            if xpath[first] == '/'
                first += 1
            else
                error("unexpected character while parsing xpath expression")
            end
        end
    end
    parsed
end

function xpath_parse_expr(xpath::String)
    # parse as a number
    if '0' <= xpath[1] <= '9'
        value = 0
        count = 1
        invalid = false
        for x = xpath
            if '0' <= x <= '9'
                value = value * count + (x-'0')
                count *= 10
            else
                invalid = true
            end
        end
        if !invalid
            return (:position,(:(=),value))
        end

    # parse as a attribute
    elseif xpath[1] == '@'
        eq = search(xpath,'=')
        if eq != 0
            qt = search(xpath,'\'',eq+1)
            qtend = search(xpath,'\'',qt+1)
            if qtend == length(xpath)
                return (:attribute_eq, (SubString(xpath,2,eq-1), SubString(xpath,qt+1,qtend-1)))
            end
        else
            if search(xpath,' ') == 0
                return (:attribute, SubString(xpath,2,length(xpath)))
            end
        end

    # parse as a node
    elseif (eq=search(xpath,'=')) != 0
        qt = search(xpath,'\'',eq+1)
        qtend = search(xpath,'\'',qt+1)
        if qtend == length(xpath)
            return (:has_child_eq, (SubString(xpath,1,eq-1), SubString(xpath,qt+1,qtend-1)))
        end
    elseif search(xpath,' ') == 0
        return (:has_child, xpath)
    end
    
    assert(false, "complex xpath filter parsing is not implemented")
end

isroot(pd::ParsedData) = (pd.parent == pd)

type XPath{T<:String}
    # an XPath filter is a series of XPath segments implemented as
    # (:cmd, data) pairs. For example,
    # "//A/..//*[2]" should be parsed as:
    # [(:root,nothing), (:descendant_or_self,nothing), (:child,nothing), (:name,SubString("A",1,1)),
    #  (:parent,nothing), (:descendant_or_self,nothing), (:child,nothing), (:position,(:(=),2))]
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

