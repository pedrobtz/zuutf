# Symbol tables of the installed shared object, for test-abi.R and
# test-vendor.R. Read with nm on Linux and macOS and objdump -p on Windows
# (both ship with Rtools), never from the source: what matters is what the
# linker produced.

zuutf_dll_path <- function() {
  dll <- getLoadedDLLs()[["zuutf"]]
  skip_if(is.null(dll), "zuutf's shared object is not loaded")
  path <- dll[["path"]]
  skip_if(!file.exists(path), "zuutf's shared object is not on disk")
  path
}

run_tool <- function(tool, args) {
  exe <- Sys.which(tool)
  skip_if(!nzchar(exe), paste(tool, "is not available"))
  out <- suppressWarnings(
    system2(exe, args, stdout = TRUE, stderr = FALSE)
  )
  skip_if(
    !is.character(out) || length(out) == 0L,
    paste(tool, "gave no output")
  )
  out
}

# The imported names in objdump -p output: under each "DLL Name:" line, a
# header line naming "Member-Name", then one row per import up to a blank
# line, with the name last.
pe_imports <- function(dump) {
  dump <- sub("\r$", "", dump)
  names <- character()
  in_block <- FALSE
  for (line in dump) {
    if (grepl("Member-Name", line, fixed = TRUE)) {
      in_block <- TRUE
    } else if (in_block && !nzchar(trimws(line))) {
      in_block <- FALSE
    } else if (in_block) {
      names <- c(names, sub("^.*[[:space:]]", "", trimws(line)))
    }
  }
  names
}

# objdump -p output for a Windows DLL.
pe_dump <- function() {
  run_tool("objdump", c("-p", shQuote(zuutf_dll_path())))
}

# Names the shared object exports, without Mach-O's leading underscore.
exported_symbols <- function() {
  sysname <- Sys.info()[["sysname"]]
  if (sysname == "Windows") {
    dump <- pe_dump()
    start <- grep("[Ordinal/Name Pointer] Table", dump, fixed = TRUE)
    if (length(start) == 0L) {
      return(character())
    }
    rows <- dump[-seq_len(start[1L])]
    rows <- rows[grepl("^\\s*\\[\\s*[0-9]+\\]", rows)]
    # rows read "[   0] +base[   1]  0000 R_init_zuutf"; the name is last
    return(sub("^.*[[:space:]]", "", trimws(rows)))
  }
  args <- if (sysname == "Darwin") "-gU" else c("-D", "--defined-only")
  syms <- run_tool("nm", c(args, shQuote(zuutf_dll_path())))
  names <- sub("^.*[[:space:]]", "", syms)
  # crti.o's _init and _fini, which musl's linker exports and glibc's does
  # not; dropped by exact name before the Mach-O underscore is stripped.
  names <- setdiff(names, c("_init", "_fini"))
  if (sysname == "Darwin") {
    names <- sub("^_", "", names)
  }
  names
}

# Names the shared object needs from elsewhere: undefined symbols on Linux
# and macOS, the import table on Windows.
referenced_symbols <- function() {
  sysname <- Sys.info()[["sysname"]]
  if (sysname == "Windows") {
    return(pe_imports(pe_dump()))
  }
  syms <- run_tool("nm", c("-u", shQuote(zuutf_dll_path())))
  names <- sub("^.*[[:space:]]", "", trimws(syms))
  if (sysname == "Darwin") {
    names <- sub("^_", "", names)
  }
  sub("@.*$", "", names)
}

# Is this build instrumented (covr, gcov, a sanitizer)? Their runtimes
# export and import symbols of their own, so the exact-set assertions skip
# there. Asked of the binary, not of an environment variable, because
# coverage.yml's native job sets none.
is_instrumented_build <- function() {
  if (identical(Sys.getenv("R_COVR"), "true")) {
    return(TRUE)
  }
  if (Sys.info()[["sysname"]] == "Windows") {
    return(FALSE)
  }
  syms <- tryCatch(
    c(exported_symbols(), referenced_symbols()),
    condition = function(e) character()
  )
  any(grepl("gcov|__llvm_prof|__asan_|__ubsan_|__tsan_|__msan_", syms))
}

# libstdc++'s template instantiations, which GCC exports as weak,
# vague-linkage symbols whatever the visibility flags say (design §12.2):
# mangled names in namespaces std and __gnu_cxx, their typeinfo, vtables and
# guard variables. An unoptimised build (gctorture's) leaves inline members
# such as __gnu_cxx::char_traits<char>::length out of line, so they appear
# there and nowhere else.
libstdcxx_instantiation <- function(names) {
  grepl("^_Z(T[ISV]|GV)?N?K?(St|9__gnu_cxx)", names)
}
