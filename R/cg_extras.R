#' CoinGecko URL builder
#'
#' Builds a full URL for one of the four key-free CoinGecko hosts used by this
#' package. The website-host endpoints (`web`, `web_en`) are the website's own
#' internal JSON routes (not documented), discovered via reverse-engineering the
#' page HTML. The documented host (`api`) is the public Demo-tier API
#' (`api.coingecko.com/api/v3/`), which is rate-limited to ~30 req/min but
#' supports slug-based addressing for the basic universe and per-coin detail.
#'
#' @param path Path to append (no leading slash).
#' @param host One of `"api"` (documented), `"web"` (website, locale-free,
#'   used by `/price_charts/`, `/market_cap/`, `/ohlc/`, `/coins/...`),
#'   `"web_en"` (website, `/en/` prefixed, used by `/historical_data`,
#'   `/financials_chart_data`, etc.). Default `"web"`.
#'
#' @return Full URL string.
#' @keywords internal
#'
cg_url <- function(path, host = c("web", "web_en", "api")) {
  host <- match.arg(host)
  base <- switch(host,
    api    = "https://api.coingecko.com/api/v3/",
    web    = "https://www.coingecko.com/",
    web_en = "https://www.coingecko.com/en/"
  )
  paste0(base, sub("^/", "", path))
}

#' Default browser-like User-Agent for the website host
#'
#' Set via `options(crypto2.cg_user_agent = "...")` to override.
#' @keywords internal
cg_user_agent <- function() {
  getOption(
    "crypto2.cg_user_agent",
    paste0(
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) ",
      "AppleWebKit/537.36 (KHTML, like Gecko) ",
      "Chrome/126.0.0.0 Safari/537.36"
    )
  )
}

#' Safe HTTP GET with browser-like User-Agent
#'
#' Wraps `httr::GET` with a Chrome User-Agent (defeats Cloudflare's cheapest
#' bot heuristic), follows redirects, and returns the response body as text.
#' Errors are swallowed and converted into `NULL` so callers can keep going
#' through batch loops without one bad request killing the whole pipeline.
#'
#' @param url Full URL to GET.
#' @param query Optional named list of query parameters.
#' @param accept Default `"application/json, text/plain, */*"`. Override to
#'   `"text/html"` etc. as needed.
#' @return Raw response body as a length-1 character vector, or `NULL` on
#'   any error / non-2xx status.
#' @keywords internal
#'
#' @importFrom httr GET status_code content user_agent add_headers timeout
#'
cg_get <- function(url, query = NULL,
                   accept = "application/json, text/plain, */*") {
  resp <- tryCatch(
    httr::GET(
      url,
      query = query,
      httr::user_agent(cg_user_agent()),
      httr::add_headers(
        Accept = accept,
        `Accept-Language` = "en-US,en;q=0.9",
        `Cache-Control` = "no-cache"
      ),
      httr::timeout(60)
    ),
    error = function(e) NULL
  )
  if (is.null(resp)) return(NULL)
  sc <- httr::status_code(resp)
  if (sc < 200 || sc >= 300) return(NULL)
  httr::content(resp, as = "text", encoding = "UTF-8")
}

#' Parse JSON or return NULL on failure
#'
#' Convenience wrapper around `jsonlite::fromJSON` that returns `NULL` instead
#' of erroring out — matches the failure semantics of `cg_get()`.
#'
#' @param txt JSON text (length-1 character).
#' @param ... Passed to `jsonlite::fromJSON`.
#' @keywords internal
#' @importFrom jsonlite fromJSON
cg_parse_json <- function(txt, ...) {
  if (is.null(txt) || !nzchar(txt)) return(NULL)
  tryCatch(
    suppressWarnings(jsonlite::fromJSON(txt, ...)),
    error = function(e) NULL
  )
}

#' Build a slow + insistent wrapper around `cg_get`
#'
#' Combines `purrr::slowly` (rate limiting) and `purrr::insistently` (retry
#' with backoff) to produce an HTTP client suitable for batch jobs.
#'
#' @param sleep Seconds between successive successful calls (default 0.6 →
#'   roughly 100 req/min, polite for the website host; the documented host
#'   needs `sleep = 2.1` to stay under the 30 req/min cap).
#' @param wait Seconds to wait before retry on failure (default 30).
#' @param max_retries Max retry attempts on failure (default 3).
#' @keywords internal
#' @importFrom purrr slowly insistently rate_delay rate_backoff possibly
cg_make_client <- function(sleep = 0.6, wait = 30, max_retries = 3) {
  rate_slow  <- purrr::rate_delay(sleep)
  rate_retry <- purrr::rate_backoff(pause_base = wait,
                                    pause_cap = wait * 4,
                                    max_times = max_retries,
                                    jitter = TRUE)
  purrr::possibly(
    purrr::insistently(
      purrr::slowly(cg_get, rate = rate_slow, quiet = TRUE),
      rate = rate_retry, quiet = TRUE
    ),
    otherwise = NULL
  )
}

#' Extract a coin's numeric CoinGecko ID from its image URL
#'
#' The documented Demo-tier API does not expose CoinGecko's internal numeric
#' coin ID, but the `image` URL in every coin response embeds it as
#' `https://coin-images.coingecko.com/coins/images/{numeric_id}/...`. The
#' numeric ID is required for some undocumented website-host endpoints
#' (notably `/ohlc/{numeric_id}/series/...` and the batched
#' `/coins/price_percentage_change?ids=...`).
#'
#' @param image_url Character vector of CoinGecko image URLs.
#' @return Integer vector of the same length, `NA_integer_` where extraction
#'   failed.
#' @keywords internal
cg_numeric_id_from_image <- function(image_url) {
  m <- regmatches(
    image_url,
    regexpr("(?<=/coins/images/)\\d+", image_url, perl = TRUE)
  )
  out <- rep(NA_integer_, length(image_url))
  ok <- lengths(regmatches(
    image_url,
    regexpr("(?<=/coins/images/)\\d+", image_url, perl = TRUE)
  )) > 0
  # simpler form using regmatches+regexpr is awkward; do it row by row
  for (i in seq_along(image_url)) {
    if (is.na(image_url[i]) || !nzchar(image_url[i])) next
    mm <- regmatches(image_url[i], regexpr("(?<=/coins/images/)\\d+",
                                            image_url[i], perl = TRUE))
    if (length(mm) == 1L) out[i] <- as.integer(mm)
  }
  out
}

#' Convert CoinGecko millisecond timestamps to POSIXct (UTC)
#'
#' @param ms Numeric vector of Unix milliseconds.
#' @return POSIXct vector, UTC.
#' @keywords internal
cg_ms_to_posix <- function(ms) {
  as.POSIXct(as.numeric(ms) / 1000, origin = "1970-01-01", tz = "UTC")
}
