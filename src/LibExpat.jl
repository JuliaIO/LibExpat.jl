module LibExpat

import Base: getindex

include("lX_common_h.jl")
include("lX_defines_h.jl")
include("lX_expat_h.jl")
include("lX_exports_h.jl")

@c Ptr{XML_LChar} XML_ErrorString (Cint,) libexpat

export ParsedData, XPHandle, xp_make_parser, xp_geterror, xp_close, xp_parse, find

DEBUG = false

macro DBG_PRINT (s)
    quote
        if (DEBUG) 
            println($s); 
        end
    end
end

type ParsedData
    # XML Tag
    name::String
    # Dict of tag attributes as name-value pairs
    attr::Dict{String,String}
    # All text portions (concatenated) including newline
    text::String
    # Dict of child elements.
        # Key -> tag of element
        # Value -> Array of ParsedData objects
    elements::Dict{String, Vector{ParsedData}}
    # all text within a CDATA section, concatenated, includes all whitespace
    cdata::String
    # Only used while parsing, set to nothing due to
    # inability of show() to handle mutually referencing data structures
    parent::Union(ParsedData,Nothing)
    
    ParsedData() = ParsedData("")
    ParsedData(name) = new(
        name,
        Dict{String, String}(),
        "",
        Dict{String, Vector{ParsedData}}(),
        "",
        nothing)
end

getindex(pd::ParsedData,x::String) = getindex(pd.elements,x)
function getindex(pd::Vector{ParsedData},x::String)
    children = ParsedData[]
    for ele = pd
        childs = get(ele.elements,x,nothing)
        if childs !== nothing
            append!(children,childs)
        end
    end
    length(children) == 0 && error("key: $x not found")
    return children
end

type XPHandle
  parser 
  pdata
  in_cdata
  
  XPHandle() = new(nothing, ParsedData(""), false)
end


function xp_make_parser(sep='\0') 
    xph = XPHandle()
    p::XML_Parser = (sep == '\0') ? XML_ParserCreate(C_NULL) : XML_ParserCreateNS(C_NULL, sep);
    xph.parser = p

    if (p == C_NULL) error("XML_ParserCreate failed") end

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

    return xph;

end



function xp_geterror(xph::XPHandle)
    p = xph.parser
    ec = XML_GetErrorCode(p)
    
    if ec != 0 
        @DBG_PRINT (XML_GetErrorCode(p))
        @DBG_PRINT (bytestring(XML_ErrorString(XML_GetErrorCode(p))))
        
        return  ( bytestring(XML_ErrorString(XML_GetErrorCode(p))), 
                XML_GetCurrentLineNumber(p), 
                XML_GetCurrentColumnNumber(p) + 1, 
                XML_GetCurrentByteIndex(p) + 1
            )
     else
        return  ( "", 0, 0, 0)
     end 
     
end



function xp_close (xph::XPHandle) 
  if (xph.parser != nothing)    XML_ParserFree(xph.parser) end
  xph.parser = nothing
end


function start_cdata (p_xph::Ptr{Void}) 
    xph = unsafe_pointer_to_objref(p_xph)
#    @DBG_PRINT ("Found StartCdata")
    xph.in_cdata = true
    return
end
cb_start_cdata = cfunction(start_cdata, Void, (Ptr{Void},))

function end_cdata (p_xph::Ptr{Void}) 
    xph = unsafe_pointer_to_objref(p_xph)
#    @DBG_PRINT ("Found EndCdata")
    xph.in_cdata = false
    return;
end
cb_end_cdata = cfunction(end_cdata, Void, (Ptr{Void},))


function cdata (p_xph::Ptr{Void}, s::Ptr{Uint8}, len::Cint)
    xph = unsafe_pointer_to_objref(p_xph)
  
    txt = bytestring(s, int64(len))
    if (xph.in_cdata == true)
        xph.pdata.cdata = xph.pdata.cdata * txt
    else
        xph.pdata.text = xph.pdata.text * txt
    end
    
#    @DBG_PRINT ("Found CData : " * txt)
    return;
end
cb_cdata = cfunction(cdata, Void, (Ptr{Void},Ptr{Uint8}, Cint))


function comment (p_xph::Ptr{Void}, data::Ptr{Uint8}) 
    xph = unsafe_pointer_to_objref(p_xph)
    txt = bytestring(data)
    @DBG_PRINT ("Found comment : " * txt)
    return;
end
cb_comment = cfunction(comment, Void, (Ptr{Void},Ptr{Uint8}))


function default (p_xph::Ptr{Void}, data::Ptr{Uint8}, len::Cint)
    xph = unsafe_pointer_to_objref(p_xph)
    txt = bytestring(data)
#    @DBG_PRINT ("Default : " * txt)
    return;
end
cb_default = cfunction(default, Void, (Ptr{Void},Ptr{Uint8}, Cint))


function default_expand (p_xph::Ptr{Void}, data::Ptr{Uint8}, len::Cint)
    xph = unsafe_pointer_to_objref(p_xph)
    txt = bytestring(data)
#    @DBG_PRINT ("Default Expand : " * txt)
    return;
end
cb_default_expand = cfunction(default_expand, Void, (Ptr{Void},Ptr{Uint8}, Cint))


function start_element (p_xph::Ptr{Void}, name::Ptr{Uint8}, attrs_in::Ptr{Ptr{Uint8}})
    xph = unsafe_pointer_to_objref(p_xph)
    name = bytestring(name)
#    @DBG_PRINT ("Start Elem name : $name,  current element: $(xph.pdata.name) ")
    
    new_elem = ParsedData()
    new_elem.parent = xph.pdata 
    
    new_elem.name = name

    if haskey(xph.pdata.elements, name)
        push!(xph.pdata.elements[name], new_elem)
#         print ("Added $name to $(xph.pdata.name)")
#         par = xph.pdata.parent
#         while par != nothing
#             print (".$(par.name)")
#             par = par.parent
#         end
#         println ("")
        
        @DBG_PRINT ("Added $name to $(xph.pdata.name)")
        
    else
        # New entry
        xph.pdata.elements[name] = ParsedData[new_elem]
        @DBG_PRINT ("New child $name in $(xph.pdata.name)")
    end

    xph.pdata = new_elem
    
    if (attrs_in != C_NULL)
        i = 1
        attr = unsafe_load(attrs_in, i)
        while (attr != C_NULL)
            k = bytestring(attr)
            
            i=i+1
            attr = unsafe_load(attrs_in, i)
            
            if (attr == C_NULL) error("Attribute does not have a name!") end
            v = bytestring(attr)
            
            new_elem.attr[k] = v

            @DBG_PRINT ("$k, $v in $name")
            
            i=i+1
            attr = unsafe_load(attrs_in, i)
        end
    end
    
    return
end
cb_start_element = cfunction(start_element, Void, (Ptr{Void},Ptr{Uint8}, Ptr{Ptr{Uint8}}))


function end_element (p_xph::Ptr{Void}, name::Ptr{Uint8})
    xph = unsafe_pointer_to_objref(p_xph)
    txt = bytestring(name)
#    @DBG_PRINT ("End element: $txt, current element: $(xph.pdata.name) ")
    
    parent = xph.pdata.parent
    xph.pdata.parent = nothing
    xph.pdata = parent
    
    return;
end
cb_end_element = cfunction(end_element, Void, (Ptr{Void},Ptr{Uint8}))


function start_namespace (p_xph::Ptr{Void}, prefix::Ptr{Uint8}, uri::Ptr{Uint8}) 
    xph = unsafe_pointer_to_objref(p_xph)
    prefix = bytestring(prefix)
    uri = bytestring(uri)
    @DBG_PRINT ("start namespace prefix : $prefix, uri: $uri")
    return;
end
cb_start_namespace = cfunction(start_namespace, Void, (Ptr{Void},Ptr{Uint8}, Ptr{Uint8}))


function end_namespace (p_xph::Ptr{Void}, prefix::Ptr{Uint8})
    xph = unsafe_pointer_to_objref(p_xph)
    prefix = bytestring(prefix)
    @DBG_PRINT ("end namespace prefix : $prefix")
    return;
end
cb_end_namespace = cfunction(end_namespace, Void, (Ptr{Void},Ptr{Uint8}))


# Unsupported callbacks: External Entity, NotationDecl, Not Stand Alone, Processing, UnparsedEntityDecl, StartDocType
# SetBase and GetBase



function xp_parse(txt::String)
    xph = nothing
    xph = xp_make_parser()
    
    try
        rc = XML_Parse(xph.parser, txt, length(txt), 1)
        if (rc != XML_STATUS_OK) error("Error parsing document : $rc") end
        return xph.pdata
    catch e
        stre = string(e)
        (err, line, column, pos) = xp_geterror(xph)
        @DBG_PRINT ("$e, $err, $line, $column, $pos")
        rethrow("$e, $err, $line, $column, $pos")
    
    finally
        if (xph != nothing) xp_close(xph) end
    end
end


function find(pd::ParsedData, path::String)
    # What are we looking for?
    what = :node
    attr = ""

    pathext = split(path, "#")
    if (length(pathext)) > 2 error("Invalid path syntax") 
    elseif (length(pathext) == 2)
        if (pathext[2] == "text")
            what = :text
        elseif (pathext[2] == "cdata")
            what = :cdata
        else
            error("Unknown extension : [$(pathext[2])]")
        end
    end

    nodes = split(pathext[1], "/")
    for n in nodes
        # Check to see if it is an index into an array has been requested, else default to 1
        m =  match(r"([\:\w]+)\s*(\[\s*(\d+)\s*\])?\s*(\{\s*(\w+)\s*\})?", n)
        
        idx = nothing
        if ((m == nothing) || (length(m.captures) != 5))
            error("Invalid name $n")
        else
            node = m.captures[1]
            
            if m.captures[3] != nothing
                idx = int(m.captures[3])
            end
            
            if m.captures[5] != nothing
                if (n != nodes[end]) error("Attribute request must only be present on the final node") end
                what = :attr
                attr = m.captures[5]
            end
        end

        if haskey(pd.elements, node)
            pd_arr = pd.elements[node]

            if (idx == nothing)
                if (length(pd_arr) == 1)
                    pd = pd_arr[1]
                else
                    if (n != nodes[end]) || (what != :node)
                        error("More than one instance of $node, please specify an index")
                        
                    # NOTE : The 'else' of this is handled cleanly below
                    end
                end
            else
                pd = pd_arr[idx]
            end

            if (n == nodes[end])
                if what == :node
                    if (idx == nothing) 
                        # If caller did not specify an index, return a list of leaf nodes.
                        return pd_arr
                    else
                        return pd
                    end
                
                elseif what == :text
                    return pd.text
                
                elseif what == :cdata
                    return pd.cdata
                
                elseif what == :attr
                    return pd.attr[attr]
                    
                else
                    error("Unknown request type")
                end
            end
        else
            return nothing
        end
    end
    
    return nothing
end 


end
