# Run the installed package's test suite once per simdutf kernel this
# machine supports, with SIMDUTF_FORCE_IMPLEMENTATION set before each R
# process starts (design §10). test-info.R asserts that zuutf_info()$kernel
# is the forced name, so a run that fell back to the "unsupported" stub
# fails instead of passing vacuously.
#
#   Rscript tools/kernel-matrix.R
#
# Run from the package root after R CMD INSTALL. ZUUTF_INSTALL_SECONDS, when
# set, is the measured install time, reported with the object size and the
# export list for design §12.2; ZUUTF_CXX_VERSION names the compiler. Writes
# a table to $GITHUB_STEP_SUMMARY when it is set.

install_seconds <- Sys.getenv("ZUUTF_INSTALL_SECONDS", "?")

Sys.unsetenv("SIMDUTF_FORCE_IMPLEMENTATION")
info <- zuutf::zuutf_info()
kernels <- info$kernels
cat("simdutf", info$simdutf, "| default kernel:", info$kernel, "\n")
print(kernels)

rscript <- file.path(R.home("bin"), "Rscript")
test_expr <- paste0(
  "testthat::test_dir('tests/testthat', package = 'zuutf', ",
  "load_package = 'installed', stop_on_failure = TRUE, ",
  "reporter = testthat::SummaryReporter$new())"
)

results <- character()
for (k in kernels$name[kernels$supported]) {
  cat("\n==> SIMDUTF_FORCE_IMPLEMENTATION=", k, "\n", sep = "")
  Sys.setenv(SIMDUTF_FORCE_IMPLEMENTATION = k)
  active <- system2(
    rscript,
    c("-e", shQuote("cat(zuutf::zuutf_info()$kernel)")),
    stdout = TRUE
  )
  cat("    kernel in use:", active, "\n")
  status <- system2(rscript, c("-e", shQuote(test_expr)))
  results[[k]] <- if (identical(active, k) && status == 0L) "pass" else "FAIL"
  cat("    ", k, ": ", results[[k]], "\n", sep = "")
}
Sys.unsetenv("SIMDUTF_FORCE_IMPLEMENTATION")

# Build facts for design §12.2.
so <- getLoadedDLLs()[["zuutf"]][["path"]]
sysname <- Sys.info()[["sysname"]]
exports <- tryCatch(
  {
    if (sysname == "Windows") {
      dump <- system2("objdump", c("-p", shQuote(so)), stdout = TRUE)
      start <- grep("[Ordinal/Name Pointer] Table", dump, fixed = TRUE)
      rows <- if (length(start)) dump[-seq_len(start[1L])] else character()
      rows <- trimws(rows[grepl("^\\s*\\[\\s*[0-9]+\\]", rows)])
      sub("^.*[[:space:]]", "", rows)
    } else {
      a <- if (sysname == "Darwin") "-gU" else c("-D", "--defined-only")
      sub("^.*[[:space:]]", "", system2("nm", c(a, shQuote(so)), stdout = TRUE))
    }
  },
  error = function(e) NA_character_
)

if (sysname == "Windows") {
  # the raw import table, so a format change shows up in the log
  dump <- system2("objdump", c("-p", shQuote(so)), stdout = TRUE)
  at <- grep("DLL Name:", dump, fixed = TRUE)
  if (length(at)) {
    cat("\nobjdump -p import table (first block):\n")
    writeLines(dump[at[1L] + 0:6])
  }
}

facts <- c(
  platform = R.version$platform,
  compiler = Sys.getenv("ZUUTF_CXX_VERSION", "?"),
  "install time (s)" = install_seconds,
  "shared object (KB)" = format(round(file.size(so) / 1024)),
  "exported symbols" = format(length(exports)),
  "exported, not R_init_zuutf" = paste(
    setdiff(exports, c("R_init_zuutf", "_R_init_zuutf", "_init", "_fini")),
    collapse = " "
  )
)
cat("\n")
print(facts)

summary <- Sys.getenv("GITHUB_STEP_SUMMARY")
if (nzchar(summary)) {
  lines <- c(
    "### Kernel matrix",
    "",
    "| Kernel | Supported | Result |",
    "|---|---|---|",
    sprintf(
      "| `%s` | %s | %s |",
      kernels$name,
      kernels$supported,
      ifelse(kernels$name %in% names(results), results[kernels$name], "not run")
    ),
    "",
    "### Build facts (design §12.2)",
    "",
    "| | |",
    "|---|---|",
    sprintf("| %s | %s |", names(facts), facts)
  )
  cat(lines, file = summary, sep = "\n", append = TRUE)
}

if (!length(results) || any(results != "pass")) {
  stop(
    "kernel matrix failed: ",
    paste(names(results), results, collapse = ", ")
  )
}
