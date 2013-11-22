LibExpat - Julia wrapper for libexpat
=====================================

Usage
=====

Has only three relevant APIs

- ```xp_parse(s::String)``` returns a parsed object of type ```ETree``` (used to be called ```ParsedData```). 

- ```find(pd::ETree, element_path::String)``` is used to search for elements within the parsed data object as returned by ```xp_parse```

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


You can also navigate the returned ETree object directly, i.e., without using ```find```. 
The relevant members of ETree are:

```
type ETree
    name        # XML Tag 
    attr        # Dict of tag attributes as name-value pairs 
    elements    # Vector of child nodes (ETree or String)
end
```

The xpath search consists of two parts: the parser and the search. Calling ```xpath"some/xpath[expression]"``` ```xpath(xp::String)``` will construct an XPath object that can be passed as the second argument to the xpath search. The search can be used via ```parseddata[xpath"string"]``` or ```xpath(parseddata, xpath"string")``` (the use of the xpath string macro is not essential, but is recommended for performance, and the ability to use $ interpolation with automatic quoting, when it is implemented)

The parser handles most of the xpath 1.0 specification. The following features are currently missing:
 * accessing parents of attributes
 * several xpath functions (namespace-uri, lang, processing-instructions, and comment). name and local-name do not account for xmlns namespaces.
 * parenthesized expressions
 * xmlns namespace parsing
 * correct ordering of output
 * several xpath axes (namespace, following, following-sibling, preceding, preceding-sibling)
 * $QName string interpolation
 * &quot; and &apos;
 
IJulia Demonstration Notebook
=============================
[LibExpat IJulia Demo ](http://nbviewer.ipython.org/urls/raw.github.com/amitmurthy/LibExpat.jl/master/libexpat_test.ipynb)

