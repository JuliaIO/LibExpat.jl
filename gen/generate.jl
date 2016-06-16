using Clang.cindex
using Clang.wrap_c

JULIAHOME=EnvHash()["JULIAHOME"]
EXPAT_PATH = "/usr/include/expat.h"
EXPAT_TL = "/usr/include/expat.h"
OUT_DIR = "../src/"

clang_includes = map(x->joinpath(JULIAHOME, x), [
  "deps/llvm-3.2/build/Release/lib/clang/3.2/include",
  "deps/llvm-3.2/include",
  "deps/llvm-3.2/include",
  "deps/llvm-3.2/build/include/",
  "deps/llvm-3.2/include/"
  ])
clang_extraargs = ["-D", "__STDC_LIMIT_MACROS", "-D", "__STDC_CONSTANT_MACROS"]

wc = wrap_c.init(
    ".",
    "$(OUT_DIR)lX_common_h.jl",
    clang_includes,
    clang_extraargs,
    (th, h) ->
    begin
        if search(h, "expat") == 0:-1
            return false
        else
#            println("th : $th, h : $h")
            return true
        end
        true
    end,
    h -> "libexpat",
    h ->
    begin
#        println("filename for header : $h")
        "$(OUT_DIR)lX_" * replace(last(split(h, "/")), ".", "_")  * ".jl"
    end)

wc.options.wrap_structs = true
wrap_c.wrap_c_headers(wc, [EXPAT_TL])


f = open("$(OUT_DIR)lX_defines_h.jl", "w+")
println(f, "#   Generating #define constants")

fe = open("$(OUT_DIR)lX_exports_h.jl", "w+")
println(fe, "#   Generating exports")
for e in split(open(readstring, "$(OUT_DIR)lX_expat_h.jl"), "\n")
  m = match(r"^\s*\@c\s+[\w\:\{\}\_]+\s+(\w+)", e)
  if (m != nothing)
#    println(m)
    @printf fe "export %s\n"  m.captures[1]
  end
end

for e in split(open(readstring, "$(OUT_DIR)lX_common_h.jl"), "\n")
  m = match(r"^\s*\@ctypedef\s+(\w+)", e)
  if (m != nothing)
#   println(m.captures[1])
    @printf fe "export %s\n"  m.captures[1]
  else
    m = match(r"^\s*const\s+(\w+)", e)
    if (m != nothing)
#       println(m.captures[1])
        @printf fe "export %s\n"  m.captures[1]
    end
  end
end



# Manually adding the only relevant #defines.
@printf f "const XML_TRUE = 1\n"
@printf fe "export XML_TRUE\n"

@printf f "const XML_FALSE = 0\n"
@printf fe "export XML_TRUE\n"


close(f)
close(fe)


