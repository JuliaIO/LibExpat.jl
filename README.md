LibExpat - Julia wrapper for libexpat
=====================================

Usage
=====

Has only two relevant APIs

- ```xp_parse(s::String)``` returns a parsed object of type ```ParsedData```. 

- ```find(pd::ParsedData, element_path::String)``` is used to search for elements within the parsed data object as returned by ```xp_parse```


Examples for ```element_path``` are:

- ```"foo/bar/baz"``` returns an array of elements, i.e. ParsedData objects with tag ```"baz"``` under ```foo/bar```
- ```"foo/bar/baz[1]"``` returns a ```ParsedData``` object representing the first element of type ```"baz"```
- ```"foo/bar/baz[1]{qux}"``` returns a String representing the attribute ```"qux"``` of the first element of type ```"baz"```

- ```"foo/bar[2]/baz[1]{qux}"``` in the case there is more than one ```"bar"``` element, this picks up ```"baz"``` from the 2nd ```"bar"```

- ```"foo/bar{qux}"``` returns a String representing the attribute ```"qux"``` of ```foo/bar```
- ```"foo/bar/baz[1]#text"``` returns a String representing the parsed content for the given element path. 
      NOTE: All whitespace is preserved in the concatenated string.
- ```"foo/bar/baz[1]#cdata"``` returns a String representing the unparsed content (i.e. within CDATA sections) for the given element path. 
      NOTE: All whitespace is preserved in the concatenated string.

If only one sub-element exists, the index is assumed to be 1 and may be omitted.
- ```"foo/bar/baz[2]{qux}"``` is the same as ```"foo[1]/bar[1]/baz[2]{qux}"```




