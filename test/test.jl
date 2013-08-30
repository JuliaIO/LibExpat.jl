using LibExpat
using Base.Test

pd = xp_parse(open(readall, "t_s1.txt"))
@test isa(pd, ETree)
println("PASSED 1")

ret = find(pd, "/ListBucketResult")
@test isa(ret, Array)
@test length(ret) == 1
@test isa(ret[1], ETree)
println("PASSED 1.1")

ret = find(pd, "/ListBucketResult/Name")
@test isa(ret, Array)
println("PASSED 2")

ret = find(pd, "/ListBucketResult/Name#string")
@test ret == "bucket"
println("PASSED 3")

ret = find(pd, "/ListBucketResult/Contents")
@test isa(ret, Array)
@test length(ret) == 2
@test isa(ret[1], ETree)
@test isa(ret[2], ETree)
println("PASSED 4")

@test_throws find(pd, "/ListBucketResult/Contents#string")
println("PASSED 5")

ret = split(strip(find(pd, "/ListBucketResult/Contents[1]#string")),'\n')
@test ret[1] == "C1C1C1"
println("PASSED 6")

@test (find(pd, "/ListBucketResult/Contents[1]#string") == find(pd, "Contents[1]#string"))
println("PASSED 6.1")

ret = split(strip(find(pd, "/ListBucketResult/Contents[2]#string")),'\n')
@test ret[1] == "C2C2C2"
println("PASSED 7")

ret = find(pd, "/ListBucketResult/Contents[1]/Owner/ID")
@test isa(ret, Array)
@test length(ret) == 1
@test isa(ret[1], ETree)
println("PASSED 8")

ret = find(pd, "/ListBucketResult/Contents[1]/Owner/ID#string")
@test ret == "11111111111111111111111111111111"
println("PASSED 9")

ret = find(pd, "/ListBucketResult/Contents[1]/Owner/ID{idk}")
@test ret == "IDKV1"
println("PASSED 10")

ret = find(pd, "/ListBucketResult/Contents[2]/Owner/ID{idk}")
@test ret == "IDKV2"
println("PASSED 11")
 
@test (find(pd, "/ListBucketResult/Contents[2]/Owner/ID{idk}") == find(pd, "Contents[2]/Owner/ID{idk}"))
println("PASSED 11.1")

@test (find(pd, "/I/Do/NOT/Exist") == [])
println("PASSED 12")

@test (find(pd, "/I/Do/NOT/Exist[1]") == nothing)
println("PASSED 12.1")

@test (find(pd, "/ListBucketResult/Contents[2]/Owner/JUNK#string") == nothing)
println("PASSED 12.2")

pd = xp_parse(open(readall, "utf8.xml"))
@test isa(pd, ParsedData)
println("PASSED 13")


pd = xp_parse(open(readall, "wiki.xml"))
@test isa(pd, ParsedData)
ret = find(pd, "/page/revision/id#string")
@test ret == "557462847"
println("PASSED 14")

