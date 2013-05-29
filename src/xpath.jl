
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
                push!(parsed, (:parent,null))
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
            push!(parsed, (:child,section))
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
            filter = xpath_parse_expr(SubString(xpath, first+1, last-1))::(Symbol,Any)
            push!(parsed, (:filter, filter))
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
    parsed, T
end

function xpath_parse_expr(xpath::String)
    # parse as a number
    if '0' <= xpath[1] <= '9' 
        value = 0
        count = 1
        invalid = false
        for x = xpath
            if '0' <= x <= '9'
                value += x * count
                count *= 10
            else
                invalid = true
            end
        end
        if !invalid
            return (:position,value)
        end

    # parse as a attribute
    elseif xpath[1] == '@'
        eq = search(xpath,'=')
        if eq != 0
            qt = search(xpath,'\'',eq+1)
            qtend = search(xpath,'\'',qt+1)
            if qtend == length(xpath)
                return (:attribute_eq, (SubString(xpath,1,eq-1), SubString(xpath,qt+1,qtend-1)))
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
            return (:child_eq, (SubString(xpath,1,eq-1), SubString(xpath,qt+1,qtend-1)))
        end
    elseif search(xpath,' ') == 0
        return (:child, xpath)
    end
    
    assert(false, "complex xpath filter parsing is not implemented")
end

macro vectorize1(fn)
    quote
        function $(esc(fn))(pds::Vector{ParsedData})
            nodes = ParsedData[]
            for pd in pds
                node = $(esc(fn))(pd)
                if !contains(nodes, node)
                    push!(nodes, node)
                end
            end
            nodes
        end
        function $(esc(fn))(pds::Vector{ParsedData},name::String)
            nodes = ParsedData[]
            for pd in pds
                node = $(esc(fn))(pd,name)
                if node !== nothing && !contains(nodes, node)
                    push!(nodes, node)
                end
            end
            nodes
        end
    end
end

function rootof(pd::ParsedData)
    while pd.parent != pd
        pd = pd.parent
    end
    pd
end
@vectorize1 rootof

parentof(pd::ParsedData) = pd.parent
function parentof(pd::ParsedData, name::String)
    pd = pd.parent
    if pd.name == name
        return pd
    else
        return nothing
    end
end
@vectorize1 parentof

function childrenof(pd::ParsedData)
    nodes = ParsedData[]
    for pd in values(pd.elements)
        append!(nodes, pd)
    end
    nodes
end
function childrenof(pds::Vector{ParsedData})
    nodes = ParsedData[]
    for pd in pds
        append!(nodes, childrenof(pd))
    end
    nodes
end
childrenof(pd::ParsedData, name::String) = get(pd.elements, name, ParsedData[])
function childrenof(pds::Vector{ParsedData}, name::String)
    nodes = ParsedData[]
    for pd in pds
        append!(nodes, childrenof(pd, name))
    end
    nodes
end

function descendantsof(pd::ParsedData)
    children = childrenof(pd)
    append!(children, descendantsof(children))
    children
end
function descendantsof(pds::Vector{ParsedData})
    nodes = ParsedData[]
    for pd in pds
        append!(nodes, descendantsof(pd))
    end
    nodes
end
function descendantsof(pd::ParsedData, name::String)
    children = childrenof(pd, name)
    append!(children, descendantsof(children, name))
    children
end
function descendantsof(pds::Vector{ParsedData}, name::String)
    nodes = ParsedData[]
    for pd in pds
        append!(nodes, descendantsof(pd, name))
    end
    nodes
end

function ancestorsof(pd::ParsedData)
    parents = ParsedData[]
    while parentof(pd) != pd
        push!(parents, pd)
        pd = parentof(pd)
    end
    parents
end
function ancestorsof(pds::Vector{ParsedData})
    parents = ParsedData[]
    for pd in pds
        while parentof(pd) != pd
            if !contains(parents, pd)
                push!(parents, pd)
                pd = parentof(pd)
            else
                break
            end
        end
    end
    parents
end
function ancestorsof(pd::ParsedData, name::String)
    parents = ParsedData[]
    while parentof(pd) != pd
        if pd.name == name
            push!(parents, pd)
        end
        pd = parentof(pd)
    end
    parents
end
function ancestorsof(pds::Vector{ParsedData}, name::String)
    parents = ParsedData[]
    for pd in pds
        while parentof(pd) != pd
            if pd.name == name && !contains(parents, pd)
                push!(parents, pd)
                pd = parentof(pd)
            else
                break
            end
        end
    end
    parents
end

xpath(pd::ParsedData, filter) = xpath([pd,], filter)
xpath(pd::Vector{ParsedData}, filter::String) = xpath(pd, xpath_parse(filter)...)
function xpath{T<:String}(pd::Vector{ParsedData}, filter::Vector{(Symbol,Any)}, ::Type{T})
    nodes = pd
    for xp in filter
        axis::Symbol = xp[1]
        name = xp[2]
        if axis == :root
            nodes = rootof(nodes)
        elseif axis == :parent
            nodes = parentof(nodes)
        elseif axis == :child
            if name !== nothing
                nodes = childrenof(nodes, name::SubString{T})
            else
                nodes = childrenof(nodes)
            end
        elseif axis == :self
            if name !== nothing
                nodes = self(nodes, name::SubString{T})
            end
        elseif axis == :descendant_or_self
            append!(nodes,
                if name !== nothing            
                    descendantsof(nodes, name::SubString{T})
                else
                    descendantsof(nodes)
                end)
        elseif axis == :ancestor_or_self
            append!(nodes,
                if name !== nothing
                    ancestorsof(nodes, name::SubString{T})
                else
                    ancestorsof(nodes)
                end)
        elseif axis == :filter
            filter = name[1]::Symbol
            erorr("xpath doesn't support filter expressions")
        else
            error("xpath doesn't know how to handle axis $axis")
        end
    end
    nodes
end

