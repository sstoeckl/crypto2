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
#'
#' Failure semantics — designed to interact correctly with the
#' [cg_make_client()] retry wrapper:
#' \itemize{
#'   \item **Network / connection errors** raise a classed condition
#'     (`"cg_network_error"`) — retryable by `purrr::insistently`.
#'   \item **HTTP 429** (rate-limited) raises a classed condition
#'     (`"cg_rate_limited"`) carrying the `Retry-After` header in seconds
#'     (defaulting to 60 if absent) — retryable by `purrr::insistently`,
#'     which will pause `wait` seconds before retrying.
#'   \item **Other non-2xx responses** (404, 410, 5xx, …) return `NULL`
#'     **without** raising, so a missing coin or a stale endpoint does not
#'     consume retry budget — the caller decides what to do with `NULL`.
#'   \item **2xx** returns the response body as a length-1 character vector.
#' }
#'
#' @param url Full URL to GET.
#' @param query Optional named list of query parameters.
#' @param accept Default `"application/json, text/plain, */*"`. Override to
#'   `"text/html"` etc. as needed.
#' @return Raw response body as a length-1 character vector on 2xx, or
#'   `NULL` for non-retryable non-2xx (404 etc.). Raises a classed condition
#'   on retryable failures (429, network errors).
#' @keywords internal
#'
#' @importFrom httr GET status_code content user_agent add_headers timeout headers
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
    error = function(e) {
      # Network failure (DNS, TLS, connection refused, timeout, etc.) →
      # raise a classed condition so insistently() retries.
      stop(structure(
        class = c("cg_network_error", "error", "condition"),
        list(
          message = sprintf("CoinGecko network error: %s",
                            conditionMessage(e)),
          call = sys.call(-1)
        )
      ))
    }
  )
  sc <- httr::status_code(resp)
  if (sc == 429) {
    # Rate-limited. Surface as a retryable classed condition with the
    # Retry-After value preserved on the condition so the caller can
    # inspect it if desired.
    retry_after <- suppressWarnings(
      as.numeric(httr::headers(resp)[["retry-after"]])
    )
    if (is.na(retry_after) || retry_after <= 0) retry_after <- 60
    stop(structure(
      class = c("cg_rate_limited", "error", "condition"),
      list(
        message = sprintf(
          "CoinGecko 429 rate-limited; Retry-After: %ds (url: %s)",
          retry_after, url),
        call = sys.call(),
        retry_after = retry_after
      )
    ))
  }
  if (sc < 200 || sc >= 300) return(NULL)  # 404, 410, 5xx — non-retryable
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
#' Combines `purrr::slowly` (rate limiting between successful calls) and
#' `purrr::insistently` (retry with exponential backoff on retryable
#' errors) to produce an HTTP client suitable for batch jobs.
#'
#' Retry behaviour: `cg_get()` raises a classed condition for HTTP 429
#' (rate-limited) and network failures. The `insistently` wrapper catches
#' these and retries up to `max_retries` times, waiting `wait` seconds
#' before the first retry and up to `wait * 4` seconds before later
#' retries (with jitter). Non-retryable HTTP errors (404, 410, 5xx) still
#' return `NULL` immediately and do not consume retry budget.
#'
#' @param sleep Seconds between successive successful calls (default 0.6 →
#'   ~100 req/min, polite for the website host; the documented
#'   `api.coingecko.com` host needs `sleep >= 2.5` to stay safely below
#'   the 30 req/min Demo-tier cap).
#' @param wait Seconds to wait before the first retry after a 429 / network
#'   error. Defaults to 60 so the CoinGecko 60-second rate-limit window
#'   fully resets before the retry fires. Exponential backoff applies for
#'   subsequent retries, up to `pause_cap = wait * 4`.
#' @param max_retries Max retry attempts on failure (default 3, giving up to
#'   ~ 60 + 120 + 240 = 420 s of additional waiting in the worst case).
#' @param quiet If `FALSE`, `purrr::insistently` emits a message on every
#'   retry so the caller sees the back-off in progress. Default `TRUE`.
#' @keywords internal
#' @importFrom purrr slowly insistently rate_delay rate_backoff possibly
cg_make_client <- function(sleep = 0.6, wait = 60, max_retries = 3,
                           quiet = TRUE) {
  rate_slow  <- purrr::rate_delay(sleep)
  rate_retry <- purrr::rate_backoff(pause_base = wait,
                                    pause_cap = wait * 4,
                                    max_times = max_retries,
                                    jitter = TRUE)
  purrr::possibly(
    purrr::insistently(
      purrr::slowly(cg_get, rate = rate_slow, quiet = TRUE),
      rate = rate_retry, quiet = quiet
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
