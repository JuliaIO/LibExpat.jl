macro c(ret_type, func, arg_types, lib)
    local args_in = Any[Symbol(string('a',x)) for x in 1:length(arg_types.args)]
    quote
      $(esc(func))($(args_in...)) = ccall( ($(string(func)), $(esc(lib))), $(esc(ret_type)), $(esc(arg_types)), $(args_in...) )
    end
end

macro ctypedef(fake_t,real_t)
    quote
      const $(esc(fake_t)) = $(esc(real_t))
    end
end

@ctypedef XML_Char UInt8
@ctypedef XML_LChar UInt8
@ctypedef XML_Index Int32
@ctypedef XML_Size UInt32
@ctypedef XML_Parser Ptr{Nothing}
@ctypedef XML_Bool UInt8
# enum XML_Status
const XML_STATUS_ERROR = 0
const XML_STATUS_OK = 1
const XML_STATUS_SUSPENDED = 2
# end
# enum XML_Error
const XML_ERROR_NONE = 0
const XML_ERROR_NO_MEMORY = 1
const XML_ERROR_SYNTAX = 2
const XML_ERROR_NO_ELEMENTS = 3
const XML_ERROR_INVALID_TOKEN = 4
const XML_ERROR_UNCLOSED_TOKEN = 5
const XML_ERROR_PARTIAL_CHAR = 6
const XML_ERROR_TAG_MISMATCH = 7
const XML_ERROR_DUPLICATE_ATTRIBUTE = 8
const XML_ERROR_JUNK_AFTER_DOC_ELEMENT = 9
const XML_ERROR_PARAM_ENTITY_REF = 10
const XML_ERROR_UNDEFINED_ENTITY = 11
const XML_ERROR_RECURSIVE_ENTITY_REF = 12
const XML_ERROR_ASYNC_ENTITY = 13
const XML_ERROR_BAD_CHAR_REF = 14
const XML_ERROR_BINARY_ENTITY_REF = 15
const XML_ERROR_ATTRIBUTE_EXTERNAL_ENTITY_REF = 16
const XML_ERROR_MISPLACED_XML_PI = 17
const XML_ERROR_UNKNOWN_ENCODING = 18
const XML_ERROR_INCORRECT_ENCODING = 19
const XML_ERROR_UNCLOSED_CDATA_SECTION = 20
const XML_ERROR_EXTERNAL_ENTITY_HANDLING = 21
const XML_ERROR_NOT_STANDALONE = 22
const XML_ERROR_UNEXPECTED_STATE = 23
const XML_ERROR_ENTITY_DECLARED_IN_PE = 24
const XML_ERROR_FEATURE_REQUIRES_XML_DTD = 25
const XML_ERROR_CANT_CHANGE_FEATURE_ONCE_PARSING = 26
const XML_ERROR_UNBOUND_PREFIX = 27
const XML_ERROR_UNDECLARING_PREFIX = 28
const XML_ERROR_INCOMPLETE_PE = 29
const XML_ERROR_XML_DECL = 30
const XML_ERROR_TEXT_DECL = 31
const XML_ERROR_PUBLICID = 32
const XML_ERROR_SUSPENDED = 33
const XML_ERROR_NOT_SUSPENDED = 34
const XML_ERROR_ABORTED = 35
const XML_ERROR_FINISHED = 36
const XML_ERROR_SUSPEND_PE = 37
const XML_ERROR_RESERVED_PREFIX_XML = 38
const XML_ERROR_RESERVED_PREFIX_XMLNS = 39
const XML_ERROR_RESERVED_NAMESPACE_URI = 40
# end
# enum XML_Content_Type
const XML_CTYPE_EMPTY = 1
const XML_CTYPE_ANY = 2
const XML_CTYPE_MIXED = 3
const XML_CTYPE_NAME = 4
const XML_CTYPE_CHOICE = 5
const XML_CTYPE_SEQ = 6
# end
# enum XML_Content_Quant
const XML_CQUANT_NONE = 0
const XML_CQUANT_OPT = 1
const XML_CQUANT_REP = 2
const XML_CQUANT_PLUS = 3
# end
@ctypedef XML_Content Nothing
@ctypedef XML_ElementDeclHandler Ptr{Nothing}
@ctypedef XML_AttlistDeclHandler Ptr{Nothing}
@ctypedef XML_XmlDeclHandler Ptr{Nothing}
mutable struct XML_Memory_Handling_Suite
    malloc_fcn::Ptr{Nothing}
    realloc_fcn::Ptr{Nothing}
    free_fcn::Ptr{Nothing}
end
@ctypedef XML_StartElementHandler Ptr{Nothing}
@ctypedef XML_EndElementHandler Ptr{Nothing}
@ctypedef XML_CharacterDataHandler Ptr{Nothing}
@ctypedef XML_ProcessingInstructionHandler Ptr{Nothing}
@ctypedef XML_CommentHandler Ptr{Nothing}
@ctypedef XML_StartCdataSectionHandler Ptr{Nothing}
@ctypedef XML_EndCdataSectionHandler Ptr{Nothing}
@ctypedef XML_DefaultHandler Ptr{Nothing}
@ctypedef XML_StartDoctypeDeclHandler Ptr{Nothing}
@ctypedef XML_EndDoctypeDeclHandler Ptr{Nothing}
@ctypedef XML_EntityDeclHandler Ptr{Nothing}
@ctypedef XML_UnparsedEntityDeclHandler Ptr{Nothing}
@ctypedef XML_NotationDeclHandler Ptr{Nothing}
@ctypedef XML_StartNamespaceDeclHandler Ptr{Nothing}
@ctypedef XML_EndNamespaceDeclHandler Ptr{Nothing}
@ctypedef XML_NotStandaloneHandler Ptr{Nothing}
@ctypedef XML_ExternalEntityRefHandler Ptr{Nothing}
@ctypedef XML_SkippedEntityHandler Ptr{Nothing}
mutable struct XML_Encoding
    map::Nothing
    data::Ptr{Nothing}
    convert::Ptr{Nothing}
    release::Ptr{Nothing}
end
@ctypedef XML_UnknownEncodingHandler Ptr{Nothing}
# enum XML_Parsing
const XML_INITIALIZED = 0
const XML_PARSING = 1
const XML_FINISHED = 2
const XML_SUSPENDED = 3
# end
mutable struct XML_ParsingStatus
  parsing::Int32
  finalBuffer::XML_Bool
end
# enum XML_ParamEntityParsing
const XML_PARAM_ENTITY_PARSING_NEVER = 0
const XML_PARAM_ENTITY_PARSING_UNLESS_STANDALONE = 1
const XML_PARAM_ENTITY_PARSING_ALWAYS = 2
# end
mutable struct XML_Expat_Version
    major::Int32
    minor::Int32
    micro::Int32
end
# enum XML_FeatureEnum
const XML_FEATURE_END = 0
const XML_FEATURE_UNICODE = 1
const XML_FEATURE_UNICODE_WCHAR_T = 2
const XML_FEATURE_DTD = 3
const XML_FEATURE_CONTEXT_BYTES = 4
const XML_FEATURE_MIN_SIZE = 5
const XML_FEATURE_SIZEOF_XML_CHAR = 6
const XML_FEATURE_SIZEOF_XML_LCHAR = 7
const XML_FEATURE_NS = 8
const XML_FEATURE_LARGE_SIZE = 9
const XML_FEATURE_ATTR_INFO = 10
# end
mutable struct XML_Feature
    feature::Int32
    name::Ptr{XML_LChar}
    value::Int32
end
