# Julia wrapper for header: /usr/include/expat.h
# Automatically generated using Clang.jl wrap_c, version 0.0.0

@c Void XML_SetElementDeclHandler (XML_Parser, XML_ElementDeclHandler) libexpat
@c Void XML_SetAttlistDeclHandler (XML_Parser, XML_AttlistDeclHandler) libexpat
@c Void XML_SetXmlDeclHandler (XML_Parser, XML_XmlDeclHandler) libexpat
@c XML_Parser XML_ParserCreate (Ptr{XML_Char},) libexpat
@c XML_Parser XML_ParserCreateNS (Ptr{XML_Char}, XML_Char) libexpat
@c XML_Parser XML_ParserCreate_MM (Ptr{XML_Char}, Ptr{XML_Memory_Handling_Suite}, Ptr{XML_Char}) libexpat
@c XML_Bool XML_ParserReset (XML_Parser, Ptr{XML_Char}) libexpat
@c Void XML_SetEntityDeclHandler (XML_Parser, XML_EntityDeclHandler) libexpat
@c Void XML_SetElementHandler (XML_Parser, XML_StartElementHandler, XML_EndElementHandler) libexpat
@c Void XML_SetStartElementHandler (XML_Parser, XML_StartElementHandler) libexpat
@c Void XML_SetEndElementHandler (XML_Parser, XML_EndElementHandler) libexpat
@c Void XML_SetCharacterDataHandler (XML_Parser, XML_CharacterDataHandler) libexpat
@c Void XML_SetProcessingInstructionHandler (XML_Parser, XML_ProcessingInstructionHandler) libexpat
@c Void XML_SetCommentHandler (XML_Parser, XML_CommentHandler) libexpat
@c Void XML_SetCdataSectionHandler (XML_Parser, XML_StartCdataSectionHandler, XML_EndCdataSectionHandler) libexpat
@c Void XML_SetStartCdataSectionHandler (XML_Parser, XML_StartCdataSectionHandler) libexpat
@c Void XML_SetEndCdataSectionHandler (XML_Parser, XML_EndCdataSectionHandler) libexpat
@c Void XML_SetDefaultHandler (XML_Parser, XML_DefaultHandler) libexpat
@c Void XML_SetDefaultHandlerExpand (XML_Parser, XML_DefaultHandler) libexpat
@c Void XML_SetDoctypeDeclHandler (XML_Parser, XML_StartDoctypeDeclHandler, XML_EndDoctypeDeclHandler) libexpat
@c Void XML_SetStartDoctypeDeclHandler (XML_Parser, XML_StartDoctypeDeclHandler) libexpat
@c Void XML_SetEndDoctypeDeclHandler (XML_Parser, XML_EndDoctypeDeclHandler) libexpat
@c Void XML_SetUnparsedEntityDeclHandler (XML_Parser, XML_UnparsedEntityDeclHandler) libexpat
@c Void XML_SetNotationDeclHandler (XML_Parser, XML_NotationDeclHandler) libexpat
@c Void XML_SetNamespaceDeclHandler (XML_Parser, XML_StartNamespaceDeclHandler, XML_EndNamespaceDeclHandler) libexpat
@c Void XML_SetStartNamespaceDeclHandler (XML_Parser, XML_StartNamespaceDeclHandler) libexpat
@c Void XML_SetEndNamespaceDeclHandler (XML_Parser, XML_EndNamespaceDeclHandler) libexpat
@c Void XML_SetNotStandaloneHandler (XML_Parser, XML_NotStandaloneHandler) libexpat
@c Void XML_SetExternalEntityRefHandler (XML_Parser, XML_ExternalEntityRefHandler) libexpat
@c Void XML_SetExternalEntityRefHandlerArg (XML_Parser, Ptr{Void}) libexpat
@c Void XML_SetSkippedEntityHandler (XML_Parser, XML_SkippedEntityHandler) libexpat
@c Void XML_SetUnknownEncodingHandler (XML_Parser, XML_UnknownEncodingHandler, Ptr{Void}) libexpat
@c Void XML_DefaultCurrent (XML_Parser,) libexpat
@c Void XML_SetReturnNSTriplet (XML_Parser, Int32) libexpat
@c Void XML_SetUserData (XML_Parser, Ptr{Void}) libexpat
@c Int32 XML_SetEncoding (XML_Parser, Ptr{XML_Char}) libexpat
@c Void XML_UseParserAsHandlerArg (XML_Parser,) libexpat
@c Int32 XML_UseForeignDTD (XML_Parser, XML_Bool) libexpat
@c Int32 XML_SetBase (XML_Parser, Ptr{XML_Char}) libexpat
@c Ptr{XML_Char} XML_GetBase (XML_Parser,) libexpat
@c Int32 XML_GetSpecifiedAttributeCount (XML_Parser,) libexpat
@c Int32 XML_GetIdAttributeIndex (XML_Parser,) libexpat
@c Int32 XML_Parse (XML_Parser, Ptr{UInt8}, Int32, Int32) libexpat
@c Ptr{Void} XML_GetBuffer (XML_Parser, Int32) libexpat
@c Int32 XML_ParseBuffer (XML_Parser, Int32, Int32) libexpat
@c Int32 XML_StopParser (XML_Parser, XML_Bool) libexpat
@c Int32 XML_ResumeParser (XML_Parser,) libexpat
@c Void XML_GetParsingStatus (XML_Parser, Ptr{XML_ParsingStatus}) libexpat
@c XML_Parser XML_ExternalEntityParserCreate (XML_Parser, Ptr{XML_Char}, Ptr{XML_Char}) libexpat
@c Int32 XML_SetParamEntityParsing (XML_Parser, Void) libexpat
@c Int32 XML_SetHashSalt (XML_Parser, UInt32) libexpat
@c Int32 XML_GetErrorCode (XML_Parser,) libexpat
@c XML_Size XML_GetCurrentLineNumber (XML_Parser,) libexpat
@c XML_Size XML_GetCurrentColumnNumber (XML_Parser,) libexpat
@c XML_Index XML_GetCurrentByteIndex (XML_Parser,) libexpat
@c Int32 XML_GetCurrentByteCount (XML_Parser,) libexpat
@c Ptr{UInt8} XML_GetInputContext (XML_Parser, Ptr{Int32}, Ptr{Int32}) libexpat
@c Void XML_FreeContentModel (XML_Parser, Ptr{XML_Content}) libexpat
@c Ptr{Void} XML_MemMalloc (XML_Parser, Csize_t) libexpat
@c Ptr{Void} XML_MemRealloc (XML_Parser, Ptr{Void}, Csize_t) libexpat
@c Void XML_MemFree (XML_Parser, Ptr{Void}) libexpat
@c Void XML_ParserFree (XML_Parser,) libexpat
@c Ptr{XML_LChar} XML_ErrorString (Cint,) libexpat
@c Ptr{XML_LChar} XML_ExpatVersion () libexpat
@c XML_Expat_Version XML_ExpatVersionInfo () libexpat
@c Ptr{XML_Feature} XML_GetFeatureList () libexpat
