type XPCallbacks
    start_cdata::Function
    end_cdata::Function
    comment::Function
    character_data::Function
    default::Function
    default_expand::Function
    start_element::Function
    end_element::Function
    start_namespace::Function
    end_namespace::Function

    # Create an XPCallbacks instance filled with nop callbacks
    function XPCallbacks()
        start_cdata = (handler::XPStreamHandler) -> nothing
        end_cdata = (handler::XPStreamHandler) -> nothing
        comment = (handler::XPStreamHandler, txt::String) -> nothing
        character_data = (handler::XPStreamHandler, txt::String) -> nothing
        default = (handler::XPStreamHandler, txt::String) -> nothing
        default_expand = (handler::XPStreamHandler, txt::String) -> nothing
        start_element = (handler::XPStreamHandler, name::String, attrs_in::Dict{String,String}) -> nothing
        end_element = (handler::XPStreamHandler, name::String) -> nothing
        start_namespace = (handler::XPStreamHandler, prefix::String, uri::String) -> nothing
        end_namespace = (handler::XPStreamHandler, prefix::String) -> nothing

        new(start_cdata, end_cdata, comment, character_data, default,
            default_expand, start_element, end_element, start_namespace,
            end_namespace)
    end
end


type XPStreamHandler{D}
    cbs::XPCallbacks
    parser::XML_Parser
    data::D
end


function streaming_start_cdata(p_cbs::Ptr{Void})
    @DBG_PRINT ("Found StartCdata")
    h = unsafe_pointer_to_objref(p_cbs)::XPStreamHandler

    h.cbs.start_cdata(h)
    return
end
cb_streaming_start_cdata = cfunction(streaming_start_cdata, Void, (Ptr{Void},))


function streaming_end_cdata(p_cbs::Ptr{Void})
    @DBG_PRINT ("Found EndCdata")
    h = unsafe_pointer_to_objref(p_cbs)::XPStreamHandler

    h.cbs.end_cdata(h)
    return;
end
cb_streaming_end_cdata = cfunction(streaming_end_cdata, Void, (Ptr{Void},))


function streaming_cdata(p_cbs::Ptr{Void}, s::Ptr{Uint8}, len::Cint)
    h = unsafe_pointer_to_objref(p_cbs)::XPStreamHandler

    txt = bytestring(s, @compat(Int(len)))

    @DBG_PRINT ("Found CData : " * txt)
    h.cbs.character_data(h, txt)

    return;
end
cb_streaming_cdata = cfunction(streaming_cdata, Void, (Ptr{Void},Ptr{Uint8}, Cint))


function streaming_start_element(p_cbs::Ptr{Void}, name::Ptr{Uint8}, attrs_in::Ptr{Ptr{Uint8}})
    h = unsafe_pointer_to_objref(p_cbs)::XPStreamHandler
    txt::String = bytestring(name)
    attrs::Dict{String,String} = attrs_in_to_dict(attrs_in)

    h.cbs.start_element(h, txt, attrs)

    return
end
cb_streaming_start_element = cfunction(streaming_start_element, Void, (Ptr{Void},Ptr{Uint8}, Ptr{Ptr{Uint8}}))


function streaming_end_element(p_h::Ptr{Void}, name::Ptr{Uint8})
    h = unsafe_pointer_to_objref(p_h)::XPStreamHandler
    txt::String = bytestring(name)
    @DBG_PRINT ("End element: $txt, current element: $(xph.pdata.name) ")

    h.cbs.end_element(h, txt)

    return
end
cb_streaming_end_element = cfunction(streaming_end_element, Void, (Ptr{Void},Ptr{Uint8}))

function streaming_comment(p_h::Ptr{Void}, data::Ptr{Uint8})
    h = unsafe_pointer_to_objref(p_h)::XPStreamHandler
    txt = bytestring(data)
    @DBG_PRINT ("Found comment : " * txt)

    h.cbs.comment(h, txt)

    return
end
cb_streaming_comment = cfunction(streaming_comment, Void, (Ptr{Void},Ptr{Uint8}))


function streaming_default(p_h::Ptr{Void}, data::Ptr{Uint8}, len::Cint)
    xph = unsafe_pointer_to_objref(p_h)::XPStreamHandler
    txt = bytestring(data)
    @DBG_PRINT ("Default : " * txt)

    h.cbs.default(h, txt)

    return;
end
cb_streaming_default = cfunction(streaming_default, Void, (Ptr{Void},Ptr{Uint8}, Cint))


function streaming_default_expand(p_h::Ptr{Void}, data::Ptr{Uint8}, len::Cint)
    h = unsafe_pointer_to_objref(p_h)::XPStreamHandler
    txt = bytestring(data)
    @DBG_PRINT ("Default Expand : " * txt)

    h.cbs.default_expand(h, txt)

    return;
end
cb_streaming_default_expand = cfunction(streaming_default_expand, Void, (Ptr{Void},Ptr{Uint8}, Cint))


function streaming_start_namespace(p_h::Ptr{Void}, prefix::Ptr{Uint8}, uri::Ptr{Uint8})
    h = unsafe_pointer_to_objref(p_h)::XPStreamHandler
    prefix = bytestring(prefix)
    uri = bytestring(uri)
    @DBG_PRINT ("start namespace prefix : $prefix, uri: $uri")

    h.cbs.start_namespace(h, prefix, uri)

    return;
end
cb_streaming_start_namespace = cfunction(streaming_start_namespace, Void, (Ptr{Void},Ptr{Uint8}, Ptr{Uint8}))


function streaming_end_namespace(p_h::Ptr{Void}, prefix::Ptr{Uint8})
    h = unsafe_pointer_to_objref(p_h)::XPStreamHandler
    prefix = bytestring(prefix)
    @DBG_PRINT ("end namespace prefix : $prefix")

    h.cbs.end_namespace(h, prefix)

    return;
end
cb_streaming_end_namespace = cfunction(streaming_end_namespace, Void, (Ptr{Void},Ptr{Uint8}))


# Unsupported callbacks: External Entity, NotationDecl, Not Stand Alone, Processing, UnparsedEntityDecl, StartDocType
# SetBase and GetBase


function make_parser(cbs::XPCallbacks,data=nothing,sep='\0')
    p::XML_Parser = (sep == '\0') ? XML_ParserCreate(C_NULL) : XML_ParserCreateNS(C_NULL, sep);
    if (p == C_NULL) error("XML_ParserCreate failed") end

    h = XPStreamHandler(cbs, p, data)
    p_h = pointer_from_objref(h)
    XML_SetUserData(p, p_h);

    XML_SetCdataSectionHandler(p, cb_streaming_start_cdata, cb_streaming_end_cdata)
    XML_SetCharacterDataHandler(p, cb_streaming_cdata)
    XML_SetCommentHandler(p, cb_streaming_comment)
    XML_SetDefaultHandler(p, cb_streaming_default)
    XML_SetDefaultHandlerExpand(p, cb_streaming_default_expand)
    XML_SetElementHandler(p, cb_streaming_start_element, cb_streaming_end_element)
#    XML_SetExternalEntityRefHandler(p, f_ExternaEntity)
    XML_SetNamespaceDeclHandler(p, cb_streaming_start_namespace, cb_streaming_end_namespace)
#    XML_SetNotationDeclHandler(p, f_NotationDecl)
#    XML_SetNotStandaloneHandler(p, f_NotStandalone)
#    XML_SetProcessingInstructionHandler(p, f_ProcessingInstruction)
#    XML_SetUnparsedEntityDeclHandler(p, f_UnparsedEntityDecl)
#    XML_SetStartDoctypeDeclHandler(p, f_StartDoctypeDecl)

    return h
end


function stop(h::XPStreamHandler)
    XML_StopParser(h.parser, XML_FALSE)
#    XML_ParserFree(h.parser)
end


function pause(h::XPStreamHandler)
    XML_StopParser(h.parser, XML_TRUE)
end


function resume(h::XPStreamHandler)
    XML_ResumeParser(h.parser)
end


function free(h::XPStreamHandler)
    XML_ParserFree(h.parser)
end

function parsefile(filename::String,callbacks::XPCallbacks; bufferlines=1024, data=nothing)
    h = make_parser(callbacks, data)
    # TODO: Support suspending for files too
    suspended = false
    file = open(filename, "r")
    try
        io = IOBuffer()
        while !eof(file)
            i::Int = 0
            truncate(io, 0)
            while i < bufferlines && !eof(file)
                write(io, readline(file))
                i += 1
            end
            txt = bytestring(io)
            rc = XML_Parse(h.parser, txt, length(txt.data), 0)
            if (rc != XML_STATUS_OK) && (XML_GetErrorCode(h.parser) != XML_ERROR_ABORTED)
                # Do not fail if the user aborted the parsing
                error("Error parsing document : $rc")
            end
            if XML_GetErrorCode(h.parser) == XML_ERROR_ABORTED
                break
            end
        end
        rc = XML_Parse(h.parser, "", length(""), 1)
        #if (rc == XML_STATUS_SUSPENDED)
        #    suspended = true
        #    return XPStreamHandler(callbacks,  parser)
        #end
        if (rc != XML_STATUS_OK) && (XML_GetErrorCode(h.parser) != XML_ERROR_ABORTED)
            # Do not fail if the user aborted the parsing
            error("Error parsing document : $rc")
        end
    catch e
        stre = string(e)
        (err, line, column, pos) = xp_geterror(h.parser)
        @DBG_PRINT ("$e, $err, $line, $column, $pos")
        rethrow("$e, $err, $line, $column, $pos")
    finally
        if !suspended
            XML_ParserFree(h.parser)
        end
        close(file)
    end
end

function parse(txt::String,callbacks::XPCallbacks; data=nothing)
    h = make_parser(callbacks, data)
    suspended = false

    try
        rc = XML_Parse(h.parser, txt, length(txt.data), 1)
        if (rc == XML_STATUS_SUSPENDED)
            suspended = true
            return h
        end
        if (rc != XML_STATUS_OK) && (XML_GetErrorCode(h.parser) != XML_ERROR_ABORTED)
            # Do not fail if the user aborted the parsing
            error("Error parsing document : $rc")
        end
    catch e
        stre = string(e)
        (err, line, column, pos) = xp_geterror(h.parser)
        @DBG_PRINT ("$e, $err, $line, $column, $pos")
        rethrow("$e, $err, $line, $column, $pos")

    finally
        if !suspended
            XML_ParserFree(h.parser)
        end
    end
end

