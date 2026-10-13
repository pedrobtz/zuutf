# Design §11: zuutf against its baselines on large inputs, once per kernel
# the machine supports.
#
#   Rscript tools/run-benchmarks.R [MB]        (default 256)
#
# Run from the package root with zuutf installed (and base64enc for the
# Base64 rows). Each kernel is forced with SIMDUTF_FORCE_IMPLEMENTATION in a
# fresh R process, since simdutf picks a kernel once per process. Prints a
# table, and appends it to $GITHUB_STEP_SUMMARY when that is set. Not a test:
# nothing here fails on a slow number.

args <- commandArgs(trailingOnly = TRUE)
mb <- if (length(args)) as.numeric(args[[1]]) else 256
child <- Sys.getenv("ZUUTF_BENCH_CHILD") == "1"

time_best <- function(expr, reps = 3L) {
  f <- substitute(expr)
  env <- parent.frame()
  min(vapply(seq_len(reps), function(i) {
    gc(FALSE)
    system.time(eval(f, env))[["elapsed"]]
  }, numeric(1)))
}

if (child) {
  library(zuutf)
  set.seed(20261013)
  n <- mb * 2^20
  kernel <- zuutf_info()$kernel

  # mostly ASCII with some 2-, 3- and 4-byte code points, as text tends to be
  pool <- c(rep(0x61:0x7a, 40), 0xe9, 0x4e2d, 0x1f600, 0x3b1)
  text <- intToUtf8(sample(pool, n / 1.15, TRUE))
  Encoding(text) <- "UTF-8"
  utf8 <- charToRaw(text)
  utf16 <- utf_convert(utf8, "UTF-8", "UTF-16LE")
  binary <- as.raw(sample(0:255, n, TRUE))
  b64 <- base64_encode(binary)

  rows <- list()
  add <- function(op, base, ours) {
    rows[[length(rows) + 1L]] <<- data.frame(
      kernel = kernel, operation = op,
      baseline_s = base, zuutf_s = ours, speedup = base / ours,
      stringsAsFactors = FALSE
    )
  }
  add("utf_valid() on raw UTF-8", time_best(validUTF8(text)),
      time_best(utf_valid(utf8)))
  add("utf_decode(from = \"UTF-16LE\")",
      time_best(iconv(list(utf16), "UTF-16LE", "UTF-8")),
      time_best(utf_decode(utf16, "UTF-16LE")))
  add("utf_convert(\"UTF-8\", \"UTF-16LE\")",
      time_best(iconv(list(utf8), "UTF-8", "UTF-16LE", toRaw = TRUE)),
      time_best(utf_convert(utf8, "UTF-8", "UTF-16LE")))
  if (requireNamespace("base64enc", quietly = TRUE)) {
    add("base64_decode()", time_best(base64enc::base64decode(b64)),
        time_best(base64_decode(b64)))
    add("base64_encode()", time_best(base64enc::base64encode(binary)),
        time_best(base64_encode(binary)))
  }
  out <- do.call(rbind, rows)
  write.csv(out, Sys.getenv("ZUUTF_BENCH_OUT"), row.names = FALSE)
  quit(save = "no")
}

info <- zuutf::zuutf_info()
kernels <- info$kernels$name[info$kernels$supported]
rscript <- file.path(R.home("bin"), "Rscript")
self <- normalizePath("tools/run-benchmarks.R")
results <- list()
for (k in kernels) {
  out <- tempfile(fileext = ".csv")
  Sys.setenv(SIMDUTF_FORCE_IMPLEMENTATION = k, ZUUTF_BENCH_CHILD = "1",
             ZUUTF_BENCH_OUT = out)
  status <- system2(rscript, c(shQuote(self), mb))
  Sys.unsetenv(c("SIMDUTF_FORCE_IMPLEMENTATION", "ZUUTF_BENCH_CHILD", "ZUUTF_BENCH_OUT"))
  if (status != 0L || !file.exists(out)) {
    stop("benchmarks failed for kernel ", k)
  }
  results[[k]] <- read.csv(out, stringsAsFactors = FALSE)
}
table <- do.call(rbind, results)
rownames(table) <- NULL
table$baseline_s <- round(table$baseline_s, 3)
table$zuutf_s <- round(table$zuutf_s, 3)
table$speedup <- round(table$speedup, 1)
cat(sprintf("%s, %s, %g MB\n", R.version$platform, info$simdutf, mb))
print(table)

summary <- Sys.getenv("GITHUB_STEP_SUMMARY")
if (nzchar(summary)) {
  lines <- c(
    sprintf("### Benchmarks: %s, %g MB (design §11)", R.version$platform, mb), "",
    "| Kernel | Operation | Baseline (s) | zuutf (s) | Speed-up |",
    "|---|---|---|---|---|",
    sprintf("| `%s` | %s | %s | %s | %s |", table$kernel, table$operation,
            table$baseline_s, table$zuutf_s, table$speedup)
  )
  cat(lines, file = summary, sep = "\n", append = TRUE)
}
