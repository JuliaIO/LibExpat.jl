LibExpat - Julia wrapper for libexpat
=====================================

Usage
=====

Has only three relevant APIs

- ```xp_parse(s::String)``` returns a parsed object of type ```ParsedData```. 

- ```find(pd::ParsedData, element_path::String)``` is used to search for elements within the parsed data object as returned by ```xp_parse```

- ```(pd::ParsedData)[xpath::String]``` or ```xpath(pd::ParsedData, xpath::String)``` is also used to search for elements within the parsed
data object as returned by ```xp_parse```, but using a subset of the xpath specification


Examples for ```element_path``` are:

- ```"foo/bar/baz"``` returns an array of elements, i.e. ParsedData objects with tag ```"baz"``` under ```foo/bar```

- ```"foo//baz"``` returns an array of elements, i.e. ParsedData objects with tag ```"baz"``` anywhere under ```foo```

- ```"foo/bar/baz[1]"``` returns a ```ParsedData``` object representing the first element of type ```"baz"```

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


You can also navigate the returned ParsedData object directly, i.e., without using ```find```. 
The relevant members of ParsedData are:

```
type ParsedData
    name        # XML Tag 
    attr        # Dict of tag attributes as name-value pairs 
    elements    # Vector of child nodes (ParsedData or String)
end
```

The xpath search consists of two parts: the parser and the search. Calling ```xpath(xp::String)``` will construct an XPath object that can be passed as the second argument to the xpath search (and reused by clearing ```xp.output``` between uses). This allows the construction of complex XPath expressions that are not currently valid in the parser, or simply reuse of the parsed output.

The parser accepts most of the abbreviated path specifications and simple filters (abbreviated-form position and attribute selectors). It does not accept any extraneous whitespace and all attribute values must be contained in single quotes ```'```.

The search engine, accepts all node path axes (child, descendant, parent, ancestor, self, root, descendant-or-self, ancestor-or-self) and several simple filters (position ```> < >= <= = !=```, name, attribute, attribute=). It adds last() to the value of any position selector less than 1, allowing reverse filtering.
