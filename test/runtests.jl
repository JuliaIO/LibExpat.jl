using LibExpat
using Base.Test
using Compat

const DATADIR = joinpath(@__DIR__, "data")

pd = xp_parse(open(readstring, joinpath(DATADIR,"t_s1.txt")))
@test isa(pd, ETree)
println("PASSED 1")

ret = LibExpat.find(pd, "/ListBucketResult")
@test isa(ret, Array)
@test length(ret) == 1
@test isa(ret[1], ETree)
println("PASSED 1.1")

ret = LibExpat.find(pd, "/ListBucketResult/Name")
@test isa(ret, Array)
println("PASSED 2")

ret = LibExpat.find(pd, "/ListBucketResult/Name#string")
@test ret == "bucket"
println("PASSED 3")

ret = LibExpat.find(pd, "/ListBucketResult/Contents")
@test isa(ret, Array)
@test length(ret) == 2
@test isa(ret[1], ETree)
@test isa(ret[2], ETree)
println("PASSED 4")

@test_throws ErrorException LibExpat.find(pd, "/ListBucketResult/Contents#string")
println("PASSED 5")

ret = split(strip(LibExpat.find(pd, "/ListBucketResult/Contents[1]#string")),'\n')
@test ret[1] == "C1C1C1"
println("PASSED 6")

@test (LibExpat.find(pd, "/ListBucketResult/Contents[1]#string") == LibExpat.find(pd, "Contents[1]#string"))
println("PASSED 6.1")

ret = split(strip(LibExpat.find(pd, "/ListBucketResult/Contents[2]#string")),'\n')
@test ret[1] == "C2C2C2"
println("PASSED 7")

ret = LibExpat.find(pd, "/ListBucketResult/Contents[1]/Owner/ID")
@test isa(ret, Array)
@test length(ret) == 1
@test isa(ret[1], ETree)
println("PASSED 8")

ret = LibExpat.find(pd, "/ListBucketResult/Contents[1]/Owner/ID#string")
@test ret == "11111111111111111111111111111111"
println("PASSED 9")

ret = LibExpat.find(pd, "/ListBucketResult/Contents[1]/Owner/ID{idk}")
@test ret == "IDKV1"
println("PASSED 10")

ret = LibExpat.find(pd, "/ListBucketResult/Contents[2]/Owner/ID{idk}")
@test ret == "IDKV2"
println("PASSED 11")

@test (LibExpat.find(pd, "/ListBucketResult/Contents[2]/Owner/ID{idk}") == LibExpat.find(pd, "Contents[2]/Owner/ID{idk}"))
println("PASSED 11.1")

@test (LibExpat.find(pd, "/I/Do/NOT/Exist") == [])
println("PASSED 12")

@test (LibExpat.find(pd, "/I/Do/NOT/Exist[1]") == nothing)
println("PASSED 12.1")

@test (LibExpat.find(pd, "/ListBucketResult/Contents[2]/Owner/JUNK#string") == nothing)
println("PASSED 12.2")

pd = xp_parse(open(readstring, joinpath(DATADIR,"utf8.xml")))
@test isa(pd, ETree)
println("PASSED 13")


pd = xp_parse(open(readstring, joinpath(DATADIR,"wiki.xml")))
@test isa(pd, ETree)
ret = LibExpat.find(pd, "/page/revision/id#string")
@test ret == "557462847"
println("PASSED 14")


# Check streaming parse functionality
found_start_element = false
found_end_element = false
start_element_name = ""
first_attr_start_element = ""
first_attrval_start_element = ""
end_element_name = ""

cbs = XPCallbacks()
cbs.start_element = function (h, name, attrs)
    global found_start_element = true
    global start_element_name = name
    global first_attr_start_element = collect(keys(attrs))[1]
    global first_attrval_start_element = attrs[first_attr_start_element]
end

cbs.end_element = function (h, name)
    global found_end_element = true
    global end_element_name = name
end

parse("<test id=\"someid\">somecontent</test>", cbs)

@test found_start_element
println("PASSED 15.1")
@test found_end_element
println("PASSED 15.2")
@test (start_element_name == "test")
println("PASSED 15.3")
@test (first_attr_start_element == "id")
println("PASSED 15.4")
@test (first_attrval_start_element == "someid")
println("PASSED 15.5")
@test (end_element_name == "test")
println("PASSED 15.6")

# Check streaming file functionality with more callbacks
cdata_started = false
cdata_ended = false
cdata_section = ""
comment = ""
in_cdata_section = false

cbs = XPCallbacks()

cbs.start_cdata = function (h)
    global in_cdata_section = true
    global cdata_started = true
end

cbs.end_cdata = function (h)
    global in_cdata_section = false
    global cdata_ended = true
end

cbs.comment = function (h, txt)
    global comment = strip(txt)
end

cbs.character_data = function (h, data)
    if in_cdata_section
        global cdata_section = string(cdata_section, data)
    end
end

parsefile(joinpath(DATADIR, "graph.graphml"), cbs)

@test cdata_started
println("PASSED 16.1")
@test cdata_ended
println("PASSED 16.2")
@test (strip(cdata_section) == "<Some CDATA section>")
println("PASSED 16.3")
@test (comment == "This is just a comment.")
println("PASSED 16.4")
