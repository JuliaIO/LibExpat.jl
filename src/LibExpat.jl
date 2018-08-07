__precompile__()

module LibExpat

using Compat
using Compat.Unicode

import Base: getindex, show, parse

if Compat.Sys.iswindows()
    const libexpat = "libexpat-1"
elseif Compat.Sys.isunix()
    const libexpat = "libexpat"
end

include("lX_common_h.jl")
include("lX_defines_h.jl")
include("lX_expat_h.jl")
#include("lX_exports_h.jl")

export ETree, xp_parse, xpath, @xpath_str

# streaming
export XPCallbacks, XPStreamHandler,
       parse, stop, pause, resume, free, parsefile

const SymbolAny = Tuple{Symbol,Any}

mutable struct ETree
    # XML Tag
    name::AbstractString
    # Dict of tag attributes as name-value pairs
    attr::Dict{AbstractString,AbstractString}
    # List of child elements.
    elements::Vector{Union{ETree,AbstractString}}
    parent::ETree

    ETree() = ETree("")
    function ETree(name)
        pd=new(
            name,
            Dict{AbstractString, AbstractString}(),
            Union{ETree,AbstractString}[])
        pd.parent=pd
        pd
    end
end

Base.@deprecate_binding ParsedData ETree

function show(io::IO, pd::ETree)
    print(io,'<',pd.name)
    for (name,value) in pd.attr
        print(io,' ',name,'=','"',replace(value, '"' => "&quot;"),'"')
    end
    if length(pd.elements) == 0
        print(io,'/','>')
    else
        print(io,'>')
        for ele in pd.elements
            if isa(ele, ETree)
                show(io, ele)
            else
                print(io, replace(ele, '<' => "&lt;"))
            end
        end
        print(io,'<','/',pd.name,'>')
    end
end

string_value(pd::ETree) = String(take!(string_value(pd,IOBuffer())))
function string_value(pd::ETree, str::IOBuffer)
    for node in pd.elements
        if isa(node, AbstractString)
            write(str, node::AbstractString)
        elseif isa(node,ETree)
            string_value(node::ETree, str)
        end
    end
    str
end


mutable struct XPHandle
  parser::Union{XML_Parser,Nothing}
  pdata::ETree
  in_cdata::Bool

  XPHandle(p) = new(p, ETree(""), false)
end



function xp_geterror(p::Union{XML_Parser,Nothing})
    ec = XML_GetErrorCode(p)

    if ec != 0
        return ( unsafe_string(XML_ErrorString(XML_GetErrorCode(p))),
                XML_GetCurrentLineNumber(p),
                XML_GetCurrentColumnNumber(p) + 1,
                XML_GetCurrentByteIndex(p) + 1
            )
     else
        return ("", 0, 0, 0)
     end

end

function xp_geterror(xph::XPHandle)
    return xp_geterror(xph.parser)
end


function xp_close(xph::XPHandle)
  if (xph.parser != nothing)    XML_ParserFree(xph.parser) end
  xph.parser = nothing
end


function start_cdata(p_xph::Ptr{Nothing})
    xph = unsafe_pointer_to_objref(p_xph)::XPHandle
    xph.in_cdata = true
    return
end

function end_cdata(p_xph::Ptr{Nothing})
    xph = unsafe_pointer_to_objref(p_xph)::XPHandle
    xph.in_cdata = false
    return
end


function cdata(p_xph::Ptr{Nothing}, s::Ptr{UInt8}, len::Cint)
    xph = unsafe_pointer_to_objref(p_xph)::XPHandle

    txt = unsafe_string(s, Int(len))
    push!(xph.pdata.elements, txt)

    return
end


function comment(p_xph::Ptr{Nothing}, data::Ptr{UInt8})
    xph = unsafe_pointer_to_objref(p_xph)::XPHandle
    txt = unsafe_string(data)
    return
end


function default(p_xph::Ptr{Nothing}, data::Ptr{UInt8}, len::Cint)
    xph = unsafe_pointer_to_objref(p_xph)::XPHandle
    txt = unsafe_string(data)
    return
end


function default_expand(p_xph::Ptr{Nothing}, data::Ptr{UInt8}, len::Cint)
    xph = unsafe_pointer_to_objref(p_xph)::XPHandle
    txt = unsafe_string(data)
    return
end

function attrs_in_to_dict(attrs_in::Ptr{Ptr{UInt8}})
    attrs = Dict{AbstractString,AbstractString}()

    if (attrs_in != C_NULL)
        i = 1
        attr = unsafe_load(attrs_in, i)
        while (attr != C_NULL)
            k = unsafe_string(attr)

            i += 1
            attr = unsafe_load(attrs_in, i)

            attr == C_NULL && error("Attribute does not have a name!")
            v = unsafe_string(attr)

            attrs[k] = v
            
            i += 1
            attr = unsafe_load(attrs_in, i)
        end
    end

    return attrs
end

function start_element(p_xph::Ptr{Nothing}, name::Ptr{UInt8}, attrs_in::Ptr{Ptr{UInt8}})
    xph = unsafe_pointer_to_objref(p_xph)::XPHandle
    name = unsafe_string(name)

    new_elem = ETree(name)
    new_elem.parent = xph.pdata

    push!(xph.pdata.elements, new_elem)

    merge!(new_elem.attr, attrs_in_to_dict(attrs_in))
    xph.pdata = new_elem

    return
end


function end_element(p_xph::Ptr{Nothing}, name::Ptr{UInt8})
    xph = unsafe_pointer_to_objref(p_xph)::XPHandle
    txt = unsafe_string(name)

    xph.pdata = xph.pdata.parent

    return
end


function start_namespace(p_xph::Ptr{Nothing}, prefix::Ptr{UInt8}, uri::Ptr{UInt8})
    xph = unsafe_pointer_to_objref(p_xph)::XPHandle
    prefix = unsafe_string(prefix)
    uri = unsafe_string(uri)
    return
end


function end_namespace(p_xph::Ptr{Nothing}, prefix::Ptr{UInt8})
    xph = unsafe_pointer_to_objref(p_xph)::XPHandle
    prefix = unsafe_string(prefix)
    return
end


# Unsupported callbacks: External Entity, NotationDecl, Not Stand Alone, Processing, UnparsedEntityDecl, StartDocType
# SetBase and GetBase



function xp_parse(txt::AbstractString)
    xph = nothing
    xph = xp_make_parser()

    try
        rc = XML_Parse(xph.parser, txt, sizeof(txt), 1)
        (rc != XML_STATUS_OK) && error("Error parsing document : $rc")

        # The root element will only have a single child element in a well formed XML
        return xph.pdata.elements[1]
    catch e
        stre = string(e)
        (err, line, column, pos) = xp_geterror(xph)
        rethrow("$e, $err, $line, $column, $pos")

    finally
        (xph != nothing) && xp_close(xph)
    end
end


function find(pd::ETree, path::T) where T<:AbstractString
    # What are we looking for?
    what = :node
    attr = ""

    pathext = split(path, "#")
    if (length(pathext)) > 2 error("Invalid path syntax")
    elseif (length(pathext) == 2)
        if (pathext[2] == "string")
            what = :string
        else
            error("Unknown extension : [$(pathext[2])]")
        end
    end

    xp = SymbolAny[]
    if path[1] == '/'
        # This will treat the incoming pd as the root of the tree
        push!(xp, (:root,:element))
        pathext[1] = pathext[1][2:end]
        #else - it will start searching the children....
    end

    nodes = split(pathext[1], "/")
    idx = false
    descendant = :child
    for n in nodes
        idx = false
        if length(n) == 0
            if descendant == :descendant
                error("too many / in a row")
            end
            descendant = :descendant
            continue
        end
        # Check to see if it is an index into an array has been requested, else default to 1
        m =  match(r"([\:\w]+)\s*(\[\s*(\d+)\s*\])?\s*(\{\s*(\w+)\s*\})?", n)

        if ((m == nothing) || (length(m.captures) != 5))
            error("Invalid name $n")
        else
            node = m.captures[1]
            push!(xp, (descendant,:element))
            descendant = :child
            push!(xp, (:name, convert(T,node)))

            if m.captures[5] != nothing
                if (n == nodes[end])
                    what = :attr
                end
                attr = m.captures[5]
                push!(xp, (:filter, (:attribute, convert(T,attr))))
            end

            if m.captures[3] != nothing
                push!(xp, (:filter, (:number, Base.parse(Int, m.captures[3]))))
                idx = true
            end
        end
    end

    pd = xpath(pd, XPath{T,Vector{ETree}}((:xpath, xp)))
    if what == :node
        if idx
            if length(pd) == 1
                return pd[1]
            else
                return nothing
            end
        else
            # If caller did not specify an index, return a list of leaf nodes.
            return pd
        end
    elseif length(pd) == 0
        return nothing

    elseif length(pd) != 1
        error("More than one instance of $pd, please specify an index")

    else
        pd = pd[1]
        if what == :string
            return string_value(pd)

        elseif what == :attr
            return pd.attr[attr]

        else
            error("Unknown request type")
        end
    end

    return nothing
end

include("xpath.jl")

include("streaming.jl")

function xp_make_parser(sep='\0')
    cb_start_cdata = @cfunction(start_cdata, Nothing, (Ptr{Nothing},))
    cb_end_cdata = @cfunction(end_cdata, Nothing, (Ptr{Nothing},))
    cb_cdata = @cfunction(cdata, Nothing, (Ptr{Nothing}, Ptr{UInt8}, Cint))
    cb_comment = @cfunction(comment, Nothing, (Ptr{Nothing}, Ptr{UInt8}))
    cb_default = @cfunction(default, Nothing,  (Ptr{Nothing}, Ptr{UInt8}, Cint))
    cb_default_expand = @cfunction(default_expand, Nothing, (Ptr{Nothing}, Ptr{UInt8}, Cint))
    cb_start_element = @cfunction(start_element, Nothing, (Ptr{Nothing}, Ptr{UInt8}, Ptr{Ptr{UInt8}}))
    cb_end_element = @cfunction(end_element, Nothing, (Ptr{Nothing}, Ptr{UInt8}))
    cb_start_namespace = @cfunction(start_namespace, Nothing, (Ptr{Nothing}, Ptr{UInt8}, Ptr{UInt8}))
    cb_end_namespace = @cfunction(end_namespace, Nothing, (Ptr{Nothing}, Ptr{UInt8}))

    p::XML_Parser = (sep == '\0') ? XML_ParserCreate(C_NULL) : XML_ParserCreateNS(C_NULL, sep);
    if (p == C_NULL) error("XML_ParserCreate failed") end

    xph = XPHandle(p)
    p_xph = pointer_from_objref(xph)
    XML_SetUserData(p, p_xph);

    XML_SetCdataSectionHandler(p, cb_start_cdata, cb_end_cdata)
    XML_SetCharacterDataHandler(p, cb_cdata)
    XML_SetCommentHandler(p, cb_comment)
    XML_SetDefaultHandler(p, cb_default)
    XML_SetDefaultHandlerExpand(p, cb_default_expand)
    XML_SetElementHandler(p, cb_start_element, cb_end_element)
#    XML_SetExternalEntityRefHandler(p, f_ExternaEntity)
    XML_SetNamespaceDeclHandler(p, cb_start_namespace, cb_end_namespace)
#    XML_SetNotationDeclHandler(p, f_NotationDecl)
#    XML_SetNotStandaloneHandler(p, f_NotStandalone)
#    XML_SetProcessingInstructionHandler(p, f_ProcessingInstruction)
#    XML_SetUnparsedEntityDeclHandler(p, f_UnparsedEntityDecl)
#    XML_SetStartDoctypeDeclHandler(p, f_StartDoctypeDecl)

    return xph
end

end
