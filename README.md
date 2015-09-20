LibExpat - Julia wrapper for libexpat
=====================================

[![LibExpat on Julia release](http://pkg.julialang.org/badges/LibExpat_release.svg)](http://pkg.julialang.org/?pkg=LibExpat&ver=release)
[![LibExpat on Julia nightly](http://pkg.julialang.org/badges/LibExpat_nightly.svg)](http://pkg.julialang.org/?pkg=LibExpat&ver=nightly)
[![Build Status](https://travis-ci.org/amitmurthy/LibExpat.jl.svg?branch=master)](https://travis-ci.org/amitmurthy/LibExpat.jl)
[![Coverage Status](https://coveralls.io/repos/amitmurthy/LibExpat.jl/badge.svg?branch=master)](https://coveralls.io/r/amitmurthy/LibExpat.jl?branch=master)

Usage
=====

XPath queries on fully parsed tree
----------------------------------

Has only three relevant APIs

- ```xp_parse(s::String)``` returns a parsed object of type ```ETree``` (used to be called ```ParsedData```).

- ```LibExpat.find(pd::ETree, element_path::String)``` is used to search for elements within the parsed data object as returned by ```xp_parse```

- ```(pd::ETree)[xpath::String]``` or ```xpath(pd::ETree, xpath::String)``` is also used to search for elements within the parsed
data object as returned by ```xp_parse```, but using a subset of the xpath specification


Examples for ```element_path``` are:

- ```"foo/bar/baz"``` returns an array of elements, i.e. ETree objects with tag ```"baz"``` under ```foo/bar```

- ```"foo//baz"``` returns an array of elements, i.e. ETree objects with tag ```"baz"``` anywhere under ```foo```

- ```"foo/bar/baz[1]"``` returns a ```ETree``` object representing the first element of type ```"baz"```

- ```"foo/bar/baz[1]{qux}"``` returns a String representing the attribute ```"qux"``` of the first element of type ```"baz"``` which
has the ```"qux"``` attribute

- ```"foo/bar[2]/baz[1]{qux}"``` in the case there is more than one ```"bar"``` element, this picks up ```"baz"``` from the 2nd ```"bar"```

- ```"foo/bar{qux}"``` returns a String representing the attribute ```"qux"``` of ```foo/bar```

- ```"foo/bar/baz[1]#string"``` returns a String representing the "string-value" for the given element path. The string-value is the
concatenation of all text nodes that are descendants of the given node. NOTE: All whitespace is preserved in the concatenated string.

If only one sub-element exists, the index is assumed to be 1 and may be omitted.
- ```"foo/bar/baz[2]{qux}"``` is the same as ```"foo[1]/bar[1]/baz[2]{qux}"```

- returns an empty list or ```nothing``` if an element in the path is not found

- NOTE: If the ```element_path``` starts with a ```/``` then the search starts from pd as the root pd (the first argument)

- If ```element_path``` does NOT start with a ```/``` then the search starts with the children of the root pd (the first argument)


You can also navigate the returned ETree object directly, i.e., without using ```LibExpat.find```.
The relevant members of ETree are:

```
type ETree
    name        # XML Tag
    attr        # Dict of tag attributes as name-value pairs
    elements    # Vector of child nodes (ETree or String)
end
```

The xpath search consists of two parts: the parser and the search. Calling ```xpath"some/xpath[expression]"``` ```xpath(xp::String)``` will construct an XPath object that can be passed as the second argument to the xpath search. The search can be used via ```parseddata[xpath"string"]``` or ```xpath(parseddata, xpath"string")```. The use of the xpath string macro is not required, but is recommended for performance, and the ability to use $variable interpolation. When xpath is called as a macro, it will parse path elements starting with $ as julia variables and perform limited string interpolation:

    xpath"/a/$b/c[contains(.,'\$x$y$(z)!\'')]"

The parser handles most of the XPath 1.0 specification. The following features are currently missing:
 * accessing parents of attributes
 * several xpath functions (namespace-uri, lang, processing-instructions, and comment). name and local-name do not account for xmlns namespaces correctly.
 * parenthesized expressions
 * xmlns namespace parsing
 * correct ordering of output
 * several xpath axes (namespace, following, following-sibling, preceding, preceding-sibling)
 * &quot; and &apos; (although you can use `\'` or `\"` as escape sequences when using the `xpath""` string macro)

Streaming XML parsing
---------------------

If you do not want to store the whole tree in memory, LibExpat offers the abbility to define callbacks for streaming parsing too. To parse a document, you creata a new `XPCallbacks` instance and define all callbacks you want to receive.

```Julia
type XPCallbacks
    # These are all (yet) available callbacks, by default initialised with a dummy function.
    # Each callback will be handed as first argument a XPStreamHandler and the following other parameters:
    start_cdata     # (..) -- Start of a CDATA section
    end_cdata       # (..) -- End of a CDATA sections
    comment         # (.., comment::String) -- A comment
    character_data  # (.., txt::String) -- A character data section
    default         # (.., txt::String) -- Handler for any characters in the document which wouldn't otherwise be handled.
    default_expand  # (.., txt::String) -- Default handler that doesn't inhibit the expansion of internal entity reference.
    start_element   # (.., name::String, attrs::Dict{String,String}) -- Start of a tag/element
    end_element     # (.., name::String) -- End of a tag/element
    start_namespace # (.., prefix::String, uri::String) -- Start of a namespace declaration
    end_namespace   # (.., prefix::String) -- End of the scope of a namespace
end
```

Using an initialized `XPCallbacks` object, one can start parsing using `xp_streaming_parse` which takes the XML document as a string, the `XPCallbacks` object and an arbitrary data object which can be used to reference some context during parsing. This data object is accessible through the `data` attribute of the `XPStreamHandler` instance passed to each callback.

If your data is too large to fit into memory, as an alternative you can use `xp_streaming_parsefile` to parse the XML document line-by-line (the number of lines read and passed to expat is controlled by the keyword argument `bufferlines`).

IJulia Demonstration Notebook
=============================
[LibExpat IJulia Demo ](http://nbviewer.ipython.org/urls/raw.github.com/amitmurthy/LibExpat.jl/master/libexpat_test.ipynb)
