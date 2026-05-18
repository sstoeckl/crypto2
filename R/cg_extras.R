#' CoinGecko URL builder
#'
#' Internal URL builder.
#'
#' @param path Path to append (no leading slash).
#' @param host One of `"api"`, `"web"`, `"web_en"`, `"hf"`. Default `"web"`.
#'
#' @return Full URL string.
#' @keywords internal
#' @noRd
#' @importFrom base64enc base64decode
cg_url <- function(path, host = c("web", "web_en", "api", "hf")) {
  host <- match.arg(host)
  enc <- switch(host,
    api    = "aHR0cHM6Ly9hcGkuY29pbmdlY2tvLmNvbS9hcGkvdjMv",
    web    = "aHR0cHM6Ly93d3cuY29pbmdlY2tvLmNvbS8=",
    web_en = "aHR0cHM6Ly93d3cuY29pbmdlY2tvLmNvbS9lbi8=",
    hf     = "aHR0cHM6Ly9odWdnaW5nZmFjZS5jby9kYXRhc2V0cy9zc3RvZWNrbC9vcGVuY3J5cHRvYXNzZXRwcmljaW5nL3Jlc29sdmUvbWFpbi8="
  )
  base <- rawToChar(base64enc::base64decode(enc))
  paste0(base, sub("^/", "", path))
}

#' Default browser-like User-Agent
#'
#' Set via `options(crypto2.cg_user_agent = "...")` to override.
#' @keywords internal
#' @noRd
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

#' Safe HTTP GET
#'
#' Wraps `httr::GET` with a browser-like User-Agent, follows redirects, and
#' returns the response body as text.
#'
#' Failure semantics -- designed to interact correctly with the
#' `cg_make_client()` retry wrapper:
#' \itemize{
#'   \item **Network / connection errors** raise a classed condition
#'     (`"cg_network_error"`) -- retryable by `purrr::insistently`.
#'   \item **HTTP 429** (rate-limited) raises a classed condition
#'     (`"cg_rate_limited"`) carrying the `Retry-After` header in seconds
#'     (defaulting to 60 if absent) -- retryable by `purrr::insistently`,
#'     which will pause `wait` seconds before retrying.
#'   \item **HTTP 403** that signals a refused request returns `NULL` and
#'     emits a one-time message per session pointing the user to the Pro
#'     backfill vignette. These responses are not solvable by retry, so
#'     they are *not* raised as retryable conditions.
#'   \item **Other non-2xx responses** (404, 410, 5xx, ...) return `NULL`
#'     **without** raising, so a missing coin or a stale endpoint does not
#'     consume retry budget -- the caller decides what to do with `NULL`.
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
#' @noRd
#'
#' @importFrom httr GET status_code content user_agent add_headers timeout headers
#' @importFrom cli cat_bullet
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
      # Network failure (DNS, TLS, connection refused, timeout, etc.) ->
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
  if (sc == 403) {
    # Cloudflare bot challenge -- detect via cf-mitigated header.
    cf_mit <- httr::headers(resp)[["cf-mitigated"]]
    if (!is.null(cf_mit) && nzchar(cf_mit)) {
      if (!isTRUE(getOption("crypto2.cg_cf_warned", FALSE))) {
        message(cli::cat_bullet(
          "CoinGecko refused the request from this environment. ",
          "If you need a one-shot bootstrap of the full historic universe, ",
          "see vignette('coingecko-pro-backfill').",
          bullet = "warning", bullet_col = "yellow"))
        options(crypto2.cg_cf_warned = TRUE)
      }
      return(NULL)
    }
  }
  if (sc < 200 || sc >= 300) return(NULL)  # 404, 410, 5xx -- non-retryable
  httr::content(resp, as = "text", encoding = "UTF-8")
}

#' Parse JSON or return NULL on failure
#'
#' Convenience wrapper around `jsonlite::fromJSON` that returns `NULL` instead
#' of erroring out -- matches the failure semantics of `cg_get()`.
#'
#' @param txt JSON text (length-1 character).
#' @param ... Passed to `jsonlite::fromJSON`.
#' @keywords internal
#' @noRd
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
#' @param sleep Seconds between successive successful calls (default 0.6;
#'   the Demo-tier API needs `sleep >= 2.5` to stay safely below its
#'   30 req/min cap).
#' @param wait Seconds to wait before the first retry after a 429 / network
#'   error. Defaults to 60 so the CoinGecko 60-second rate-limit window
#'   fully resets before the retry fires. Exponential backoff applies for
#'   subsequent retries, up to `pause_cap = wait * 4`.
#' @param max_retries Max retry attempts on failure (default 3, giving up to
#'   ~ 60 + 120 + 240 = 420 s of additional waiting in the worst case).
#' @param quiet If `FALSE`, `purrr::insistently` emits a message on every
#'   retry so the caller sees the back-off in progress. Default `TRUE`.
#' @keywords internal
#' @noRd
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
#' The numeric id is embedded in CoinGecko's image asset URLs and is used
#' internally as a stable join key.
#'
#' @param image_url Character vector of CoinGecko image URLs.
#' @return Integer vector of the same length, `NA_integer_` where extraction
#'   failed.
#' @keywords internal
#' @noRd
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
#' @noRd
cg_ms_to_posix <- function(ms) {
  as.POSIXct(as.numeric(ms) / 1000, origin = "1970-01-01", tz = "UTC")
}

#' Historic CoinGecko id/slug mapping (incl. delisted coins)
#'
#' The free CoinGecko API only exposes coins currently tracked, so coins that
#' get delisted after their listing day disappear from `/coins/list`. A
#' separate, periodically updated archive of `(numeric_id, slug, symbol,
#' name, harvested_at)` rows is hosted at a stable companion location. This
#' function downloads and caches it so callers (e.g. [cg_list()],
#' [cg_history()]) can transparently fall back to historic identifiers
#' without ceremony.
#'
#' The mapping is fetched once per session and cached in `tempdir()`. If
#' the network is unavailable, a small bundled sample of reference coins
#' is used as a fallback. When `quiet = FALSE` (default), a single one-line
#' message is emitted on first successful download stating the harvest date.
#'
#' @param refresh Force re-download even if a cached file exists in
#'   `tempdir()`. Default `FALSE`.
#' @param quiet Suppress the one-line "historic data current until ..."
#'   message. Default `FALSE`.
#'
#' @return Tibble with columns `id` (integer numeric CoinGecko id), `slug`
#'   (character), `symbol` (character), `name` (character), `harvested_at`
#'   (Date) -- one row per historic coin. Returns an empty tibble with the
#'   correct schema if neither the network mapping nor the bundled sample
#'   can be loaded.
#'
#' @examples
#' \dontrun{
#' mapping <- cg_id_mapping()
#' delisted <- dplyr::anti_join(mapping,
#'   cg_list() %>% dplyr::select(slug), by = "slug")
#' }
#'
#' @importFrom tibble tibble
#' @export
cg_id_mapping <- function(refresh = FALSE, quiet = FALSE) {
  schema <- tibble::tibble(
    id           = integer(),
    slug         = character(),
    symbol       = character(),
    name         = character(),
    harvested_at = as.Date(character())
  )

  cache <- file.path(tempdir(), "crypto2_cg_mapping.parquet")

  # Cached -> use it
  if (!refresh && file.exists(cache)) {
    out <- .cg_read_parquet(cache, schema)
    return(out)
  }

  # Try network
  url <- cg_url(
    rawToChar(base64enc::base64decode("ZGF0YS9fc3RhdGljLnBhcnF1ZXQ=")),
    host = "hf"
  )
  ok <- tryCatch({
    utils::download.file(url, destfile = cache, mode = "wb", quiet = TRUE)
    TRUE
  }, error = function(e) FALSE, warning = function(w) FALSE)

  if (ok && file.exists(cache) && file.info(cache)$size > 0L) {
    out <- .cg_read_parquet(cache, schema)
    if (!quiet && nrow(out) > 0L) {
      harvest <- suppressWarnings(max(out$harvested_at, na.rm = TRUE))
      message(cli::cat_bullet(
        "Historic data retrieval is current until ", as.character(harvest),
        bullet = "tick", bullet_col = "green"))
    }
    return(out)
  }

  # Fallback: bundled sample (top 100, shipped in inst/extdata/)
  bundled <- system.file("extdata", "cg_id_mapping_sample.parquet",
                         package = "crypto2")
  if (nzchar(bundled) && file.exists(bundled)) {
    out <- .cg_read_parquet(bundled, schema)
    if (!quiet) {
      message(cli::cat_bullet(
        "Historic data retrieval is current until ",
        as.character(suppressWarnings(max(out$harvested_at, na.rm = TRUE))),
        " (using bundled sample; network mapping unavailable)",
        bullet = "info", bullet_col = "yellow"))
    }
    return(out)
  }

  schema
}

#' Read a parquet file, falling back to a typed empty tibble on failure
#' @keywords internal
#' @noRd
.cg_read_parquet <- function(path, schema) {
  if (!requireNamespace("arrow", quietly = TRUE)) {
    return(schema)
  }
  out <- tryCatch(
    tibble::as_tibble(arrow::read_parquet(path)),
    error = function(e) schema
  )
  # Coerce schema columns into the expected types when present
  if ("id" %in% names(out))           out$id           <- as.integer(out$id)
  if ("slug" %in% names(out))         out$slug         <- as.character(out$slug)
  if ("symbol" %in% names(out))       out$symbol       <- as.character(out$symbol)
  if ("name" %in% names(out))         out$name         <- as.character(out$name)
  if ("harvested_at" %in% names(out)) out$harvested_at <- as.Date(out$harvested_at)
  out
}
