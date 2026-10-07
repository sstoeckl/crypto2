# Weekly availability check of every data source crypto2 depends on.
#
# Each check calls a package function (CoinMarketCap) or fetches an endpoint
# directly (CoinGecko, Hugging Face) and validates the shape of the answer.
#   ok   -- works as expected
#   warn -- refused by Cloudflare / rate-limited / suspiciously small, i.e.
#           possibly specific to this machine (CI runners are often blocked)
#   fail -- endpoint gone (404/410), schema changed, or call errored
# The script exits with status 1 if any check fails. Run it locally with
#   Rscript .github/scripts/check_endpoints.R
# after installing the package; on GitHub Actions the table is written to
# the job summary.

suppressPackageStartupMessages(library(crypto2))
cg_url <- crypto2:::cg_url
ua <- httr::user_agent(crypto2:::cg_user_agent())

results <- list()
record <- function(source, name, status, detail) {
  results[[length(results) + 1L]] <<- data.frame(
    source = source, check = name, status = status, detail = detail)
  cat(sprintf("[%-4s] %-11s %-42s %s\n", status, source, name, detail))
}

# Run a package call; `validate` returns NULL (ok) or a failure message.
check_call <- function(source, name, expr, validate, warn_if = NULL) {
  t0 <- Sys.time()
  out <- tryCatch(suppressMessages(force(expr)), error = function(e) e)
  secs <- sprintf("%.0fs", as.numeric(difftime(Sys.time(), t0, units = "secs")))
  if (inherits(out, "error")) {
    return(record(source, name, "fail", paste("error:", conditionMessage(out))))
  }
  msg <- validate(out)
  if (!is.null(msg)) return(record(source, name, "fail", msg))
  w <- if (!is.null(warn_if)) warn_if(out)
  if (!is.null(w)) return(record(source, name, "warn", w))
  record(source, name, "ok", paste(NROW(out), "rows,", secs))
}

# Fetch an endpoint; `validate` gets the response text.
check_http <- function(source, name, url, validate = function(txt) NULL,
                       method = "GET") {
  resp <- tryCatch(
    if (method == "HEAD") httr::HEAD(url, ua, httr::timeout(60))
    else httr::GET(url, ua, httr::timeout(60)),
    error = function(e) e)
  Sys.sleep(2)
  if (inherits(resp, "error")) {
    return(record(source, name, "warn", paste("unreachable:", conditionMessage(resp))))
  }
  sc <- httr::status_code(resp)
  if (sc == 403 && !is.null(httr::headers(resp)[["cf-mitigated"]])) {
    return(record(source, name, "warn", "refused by Cloudflare from this machine"))
  }
  if (sc == 429) return(record(source, name, "warn", "rate-limited (429)"))
  if (sc != 200) return(record(source, name, "fail", paste("HTTP", sc)))
  if (method == "HEAD") return(record(source, name, "ok", "HTTP 200"))
  msg <- validate(httr::content(resp, as = "text", encoding = "UTF-8"))
  if (!is.null(msg)) return(record(source, name, "fail", msg))
  record(source, name, "ok", "HTTP 200, schema as expected")
}

has_cols <- function(cols) function(x) {
  miss <- setdiff(cols, names(x))
  if (length(miss)) paste("missing columns:", paste(miss, collapse = ", "))
}
min_rows <- function(n, cols = character()) function(x) {
  if (NROW(x) < n) return(sprintf("only %d rows (expected >= %d)", NROW(x), n))
  has_cols(cols)(x)
}
json_daily <- function(field) function(txt) {
  j <- tryCatch(jsonlite::fromJSON(txt), error = function(e) NULL)
  m <- j[[field]]
  if (!is.matrix(m) || nrow(m) < 1000) return(paste("no daily", field, "series"))
  if (stats::median(diff(m[, 1])) != 86400000) return("series is no longer daily")
}

# ---- CoinMarketCap (through the package functions) -----------------------
cmc <- "CMC"
check_call(cmc, "crypto_list(active)", crypto_list(),
           min_rows(5000, c("id", "slug", "symbol")))
check_call(cmc, "crypto_list(incl. inactive)", crypto_list(only_active = FALSE),
           min_rows(9000, c("id", "slug", "is_active")))
check_call(cmc, "crypto_listings(latest)", crypto_listings(limit = 10),
           min_rows(10, c("id", "slug", "price", "market_cap")))
check_call(cmc, "crypto_listings(new)", crypto_listings(which = "new", limit = 5),
           min_rows(5, c("id", "slug")))
check_call(cmc, "crypto_listings(historical 2024-01-07)",
           crypto_listings(which = "historical", start_date = "20240107",
                           end_date = "20240107", quote = FALSE),
           min_rows(1, c("id", "slug", "cmc_rank")),
           warn_if = function(x) if (nrow(x) < 9002)
             sprintf("%d of 9,002 coins: CMC served an incomplete day to this machine", nrow(x)))
btc <- data.frame(id = 1L, slug = "bitcoin", name = "Bitcoin", symbol = "BTC")
check_call(cmc, "crypto_history(BTC, 5 days)",
           crypto_history(coin_list = btc, start_date = format(Sys.Date() - 6, "%Y%m%d"),
                          end_date = format(Sys.Date() - 1, "%Y%m%d")),
           min_rows(4, c("timestamp", "open", "high", "low", "close", "market_cap")))
check_call(cmc, "crypto_info(BTC)", crypto_info(coin_list = btc),
           min_rows(1, c("id", "slug", "description")))
check_call(cmc, "crypto_global_quotes(latest)", crypto_global_quotes(),
           min_rows(1))
check_call(cmc, "exchange_list()", exchange_list(), min_rows(100, c("id", "slug")))
check_call(cmc, "fiat_list()", fiat_list(), min_rows(1))

# ---- CoinGecko website (history) -----------------------------------------
cgw <- "CG website"
check_http(cgw, "price_charts/export/bitcoin/usd.csv",
           cg_url("price_charts/export/bitcoin/usd.csv"),
           function(txt) if (is.null(crypto2:::cg_parse_export_csv(txt))) "CSV header changed")
check_http(cgw, "etl2/price_charts/bitcoin/usd/max.json",
           cg_url("etl2/price_charts/bitcoin/usd/max.json"), json_daily("stats"))
check_http(cgw, "etl2/market_cap/bitcoin/usd/max.json",
           cg_url("etl2/market_cap/bitcoin/usd/max.json"), json_daily("stats"))
check_http(cgw, "etl2/price_charts/ethereum/btc/max.json",
           cg_url("etl2/price_charts/ethereum/btc/max.json"), json_daily("stats"))
check_http(cgw, "etl2/ohlc/bitcoin/series/usd/30_days.json",
           cg_url("etl2/ohlc/bitcoin/series/usd/30_days.json"), function(txt) {
             m <- tryCatch(jsonlite::fromJSON(txt)$ohlc, error = function(e) NULL)
             if (!is.matrix(m) || ncol(m) != 5) return("no OHLC array")
             if (stats::median(diff(m[, 1])) != 4 * 3600 * 1000) return("OHLC no longer 4-hourly")
           })

# ---- CoinGecko public API, no key (lists, snapshot, metadata) -------------
cga <- "CG API"
check_http(cga, "coins/list", cg_url("coins/list", host = "api"), function(txt) {
  x <- tryCatch(jsonlite::fromJSON(txt), error = function(e) NULL)
  if (NROW(x) < 10000 || !all(c("id", "symbol", "name") %in% names(x))) "unexpected /coins/list"
})
check_http(cga, "coins/markets",
           paste0(cg_url("coins/markets", host = "api"), "?vs_currency=usd&per_page=250&page=1"),
           function(txt) {
             x <- tryCatch(jsonlite::fromJSON(txt), error = function(e) NULL)
             need <- c("id", "current_price", "market_cap", "total_volume", "image")
             if (NROW(x) != 250 || !all(need %in% names(x))) "unexpected /coins/markets"
           })
check_http(cga, "coins/bitcoin", cg_url("coins/bitcoin", host = "api"), function(txt) {
  x <- tryCatch(jsonlite::fromJSON(txt), error = function(e) NULL)
  if (!all(c("id", "symbol", "name", "links", "description") %in% names(x))) "unexpected /coins/{id}"
})

# ---- Hugging Face (id mapping, crosswalk) -----------------------------------
hf <- "Hugging Face"
check_http(hf, "cg_id_mapping archive",
           cg_url(rawToChar(base64enc::base64decode("ZGF0YS9fc3RhdGljLnBhcnF1ZXQ=")), host = "hf"),
           method = "HEAD")
check_call(hf, "crypto_crosswalk()", crypto_crosswalk(refresh = TRUE, quiet = TRUE),
           min_rows(10000, c("uid", "cmc_id", "cg_id", "match_confidence")))

# ---- Report ------------------------------------------------------------------
res <- do.call(rbind, results)
icon <- c(ok = "✅", warn = "⚠️", fail = "❌")
md <- c(sprintf("## crypto2 data sources, %s UTC", format(Sys.time(), "%Y-%m-%d %H:%M", tz = "UTC")),
        "", sprintf("%d ok, %d warnings, %d failures", sum(res$status == "ok"),
                    sum(res$status == "warn"), sum(res$status == "fail")), "",
        "| | Source | Check | Detail |", "|---|---|---|---|",
        sprintf("| %s | %s | `%s` | %s |", icon[res$status], res$source, res$check,
                gsub("\\|", "/", res$detail)))
summary_file <- Sys.getenv("GITHUB_STEP_SUMMARY")
if (nzchar(summary_file)) cat(md, file = summary_file, sep = "\n", append = TRUE)
for (i in which(res$status == "warn")) {
  if (nzchar(summary_file)) cat(sprintf("::warning title=%s::%s\n", res$check[i], res$detail[i]))
}
if (any(res$status == "fail")) {
  cat("\nFAILED:", paste(res$check[res$status == "fail"], collapse = "; "), "\n")
  quit(status = 1)
}
