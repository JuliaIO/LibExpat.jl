using LibExpat
using Base.Test


pd = xp_parse(open(readall, "t_s1.txt"))
@test isa(pd, ParsedData)
println("PASSED 1")

ret = find(pd, "ListBucketResult")
@test isa(ret, Array)
@test length(ret) == 1
@test isa(ret[1], ParsedData)
println("PASSED 1")

ret = find(pd, "ListBucketResult/Name")
@test isa(ret, Array)
println("PASSED 2")

ret = find(pd, "ListBucketResult/Name#text")
@test ret == "bucket"
println("PASSED 3")

ret = find(pd, "ListBucketResult/Contents")
@test isa(ret, Array)
@test length(ret) == 2
@test isa(ret[1], ParsedData)
@test isa(ret[2], ParsedData)
println("PASSED 4")

@test_fails find(pd, "ListBucketResult/Contents#text")
println("PASSED 5")

ret = find(pd, "ListBucketResult/Contents[1]#text")
@test strip(ret) == "C1C1C1"
println("PASSED 6")

ret = find(pd, "ListBucketResult/Contents[2]#text")
@test strip(ret) == "C2C2C2"
println("PASSED 7")

ret = find(pd, "ListBucketResult/Contents[1]/Owner/ID")
@test isa(ret, Array)
@test length(ret) == 1
@test isa(ret[1], ParsedData)
println("PASSED 8")

ret = find(pd, "ListBucketResult/Contents[1]/Owner/ID#text")
@test ret == "11111111111111111111111111111111"
println("PASSED 9")

ret = find(pd, "ListBucketResult/Contents[1]/Owner/ID{idk}")
@test ret == "IDKV1"
println("PASSED 10")

ret = find(pd, "ListBucketResult/Contents[2]/Owner/ID{idk}")
@test ret == "IDKV2"
println("PASSED 11")
 
