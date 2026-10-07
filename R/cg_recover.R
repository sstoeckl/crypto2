#' Fetch CoinGecko history by numeric ID (incl. partial survivorship-bias
#' correction)
#'
#' Companion to [cg_history()] that addresses coins by their **numeric
#' CoinGecko ID** instead of their slug. Useful in two scenarios:
#'
#' 1. Coins that have been **delisted** and whose slug no longer resolves.
#' 2. Cronjob-style accumulation: when you persist `cg_list()` snapshots
#'    over time, the **union of all numeric IDs ever observed** is the
#'    survivorship-bias-corrected universe. `cg_history_by_id()` lets you
#'    refetch each historical ID directly without needing its current
#'    slug to still resolve.
#'
#' Important caveats -- please read:
#' * **The numeric-ID space is sparse, not dense.** Blind iteration over
#'   `1:N` does NOT recover the full universe -- most numeric IDs in that
#'   range have no data. The default `ids = NULL` therefore uses the
#'   active universe from `cg_list()`, not a numeric range. To recover
#'   delisted coins you must supply the IDs explicitly (e.g., the union
#'   of accumulated `cg_list()` snapshots, or the historic mapping from
#'   [cg_id_mapping()]).
#' * **Slug recovery for delisted coins is not generally available on the
#'   free tier.** Active coins get their slug/name joined back in from
#'   `cg_list()`; rows whose numeric ID is no longer in the active universe
#'   come back with `slug = NA` and `name = NA`. Use the `id` column as
#'   the join key in downstream code. For a one-shot complete recovery of
#'   the full historic universe see `vignette("coingecko-pro-backfill")`.
#'
#' @param ids Integer vector of numeric IDs to fetch. Default `NULL` ->
#'   uses `cg_list()$id` (active universe). To extend coverage to
#'   delisted coins, supply the union of historically-observed IDs from
#'   your accumulated snapshots.
#' @param what Subset of streams to fetch. Any combination of
#'   `"price"` (close + volume), `"market_cap"`, and `"ohlc"`. Default all
#'   three. Coverage is the same as for [cg_history()]: full history for
#'   close, volume and market cap in USD, OHLC for the last 30 days. OHLC
#'   needs the coin's slug, so ids missing from `coin_list` return none.
#' @param vs_currency Quote currency, default `"usd"`. Other currencies are
#'   limited to the last 365 days and need the coin's slug, so ids missing
#'   from `coin_list` return no price series.
#' @param start_date,end_date Client-side date filter applied after fetch.
#'   `NULL` returns full history.
#' @param coin_list Optional `cg_list()` output used to join `slug` /
#'   `name` / `symbol` onto recovered rows for coins still in the active
#'   universe. If `NULL`, calls `cg_list()` automatically. Set
#'   to `FALSE` to skip the join (rows then have only `id`).
#' @param sleep,wait,max_retries Rate-limit knobs. Defaults `0.6 / 60 / 3`
#'   match `cg_history()`.
#' @param date_convention Either `"end_of_day"` (the default) or `"raw"`.
#'   See [cg_history()] for the explanation -- this argument applies the
#'   same -1 day shift to midnight-UTC ticks so dates align with the
#'   CMC / CRSP / Compustat end-of-day convention.
#' @param quiet If `FALSE`, prints a progress bar.
#' @param finalWait Sleep 60 s after the last call (mirrors
#'   `crypto_history()`).
#'
#' @return Tibble with one row per (id, date) using crypto2-compatible
#'   column names. Columns:
#'   \item{id}{CoinGecko numeric id (always populated).}
#'   \item{slug, name, symbol}{Coin identifiers -- `NA` for ids no longer
#'     in the active universe (i.e. delisted on the slug side).}
#'   \item{timestamp}{POSIXct UTC midnight of the trading day.}
#'   \item{ref_cur_id, ref_cur_name}{Quote currency.}
#'   \item{open, high, low, close, volume, market_cap}{Daily values.}
#'
#' @examples
#' \dontrun{
#' # Scan first 200 numeric IDs (will include both active and delisted coins)
#' h <- cg_history_by_id(ids = 1:200, what = c("price", "market_cap"))
#'
#' # Full sweep -- survivorship-bias-free price history of the entire
#' # CoinGecko universe. Slow (10+ hours). Run via cronjob package.
#' h_all <- cg_history_by_id()
#' }
#'
#' @importFrom dplyr bind_rows left_join mutate select arrange filter
#' @importFrom tibble tibble
#' @importFrom progress progress_bar
#' @importFrom cli cat_bullet
#' @export
cg_history_by_id <- function(ids = NULL,
                             what = c("price", "market_cap", "ohlc"),
                             vs_currency = "usd",
                             start_date = NULL, end_date = NULL,
                             coin_list = NULL,
                             sleep = 0.6, wait = 60, max_retries = 3,
                             quiet = FALSE, finalWait = FALSE,
                             date_convention = c("end_of_day", "raw")) {
  what <- match.arg(what, choices = c("price", "market_cap", "ohlc"),
                    several.ok = TRUE)
  date_convention <- match.arg(date_convention)
  vs <- tolower(vs_currency)

  if (is.null(ids)) {
    if (is.null(coin_list) || isFALSE(coin_list)) {
      message(cli::cat_bullet(
        "ids = NULL -> pulling cg_list() to define the universe",
        bullet = "pointer", bullet_col = "cyan"))
      coin_list <- cg_list()
    }
    if (!"id" %in% names(coin_list)) {
      stop("`ids` is NULL and `coin_list` has no `id` column; nothing to fetch.",
           call. = FALSE)
    }
    ids <- coin_list$id[!is.na(coin_list$id)]
  }
  ids <- as.integer(ids)
  ids <- ids[!is.na(ids) & ids > 0L]
  if (!length(ids)) {
    warning("cg_history_by_id(): no valid ids supplied.", call. = FALSE)
    return(tibble::tibble())
  }

  web_client <- cg_make_client(sleep = sleep, wait = wait,
                               max_retries = max_retries)
  api_client <- cg_make_client(sleep = max(sleep, getOption("crypto2.cg_sleep", 2.5)),
                               wait = wait, max_retries = max_retries)
  cg_warn_history_coverage(vs, what, start_date)

  # Slug lookup: joined onto the output, and needed for the non-USD path
  lookup <- NULL
  if (!isFALSE(coin_list)) {
    if (is.null(coin_list)) coin_list <- cg_list()
    if ("id" %in% names(coin_list) && "slug" %in% names(coin_list)) {
      lookup <- coin_list[!is.na(coin_list$id),
                          c("id", "slug", "name", "symbol"), drop = FALSE]
      lookup <- lookup[!duplicated(lookup$id), , drop = FALSE]
    } else {
      warning("cg_history_by_id(): `coin_list` lacks `id` / `slug` columns; ",
              "skipping slug join.", call. = FALSE)
    }
  }
  slugs <- if (is.null(lookup)) rep(NA_character_, length(ids)) else
    lookup$slug[match(ids, lookup$id)]

  n <- length(ids)
  pb <- if (!quiet) {
    progress::progress_bar$new(
      format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
      total = n, clear = FALSE)
  } else NULL
  if (!quiet) {
    message(cli::cat_bullet(
      sprintf("Recovering by numeric ID (%s) across %d ids",
              paste(what, collapse = "+"), n),
      bullet = "pointer", bullet_col = "green"))
  }

  results  <- vector("list", n)
  price_ok <- ohlc_ok <- rep(NA, n)
  for (i in seq_along(ids)) {
    if (!quiet) pb$tick()
    r <- tryCatch(
      cg_fetch_daily(key = ids[i], slug = slugs[i],
                     vs = vs, what = what, web_client = web_client,
                     api_client = api_client,
                     date_convention = date_convention),
      error = function(e) list(data = NULL, price_ok = FALSE, ohlc_ok = NA))
    price_ok[i] <- r$price_ok
    ohlc_ok[i]  <- r$ohlc_ok
    if (is.null(r$data)) next
    results[[i]] <- r$data %>%
      dplyr::mutate(
        timestamp    = as.POSIXct(date, tz = "UTC"),
        id           = ids[i],
        ref_cur_id   = vs,
        ref_cur_name = toupper(vs),
        time_open    = as.POSIXct(NA),
        time_high    = as.POSIXct(NA),
        time_low     = as.POSIXct(NA),
        time_close   = as.POSIXct(NA)
      )
  }
  cg_report_daily_failures(
    "cg_history_by_id", as.character(ids), price_ok, ohlc_ok,
    source_alive = function() cg_source_alive(vs, web_client, api_client))
  results <- Filter(Negate(is.null), results)
  if (!length(results)) {
    if (!any(price_ok %in% FALSE)) warning("cg_history_by_id(): no data returned.", call. = FALSE)
    return(tibble::tibble())
  }
  hist <- dplyr::bind_rows(results)
  hist <- if (is.null(lookup)) {
    dplyr::mutate(hist, slug = NA_character_,
                  name = NA_character_, symbol = NA_character_)
  } else {
    dplyr::left_join(hist, lookup, by = "id")
  }

  hist <- hist %>%
    dplyr::select(id, slug, name, symbol, timestamp,
                  ref_cur_id, ref_cur_name,
                  open, high, low, close, volume, market_cap,
                  time_open, time_high, time_low, time_close) %>%
    dplyr::arrange(id, timestamp)

  if (!is.null(start_date)) {
    sd <- as.POSIXct(as.Date(start_date), tz = "UTC")
    hist <- dplyr::filter(hist, timestamp >= sd)
  }
  if (!is.null(end_date)) {
    ed <- as.POSIXct(as.Date(end_date) + 1, tz = "UTC")
    hist <- dplyr::filter(hist, timestamp < ed)
  }

  if (isTRUE(finalWait)) {
    pb2 <- progress::progress_bar$new(
      format = "Final wait [:bar] :percent eta: :eta",
      total = 60, clear = FALSE, width = 60)
    for (i in 1:60) { pb2$tick(); Sys.sleep(1) }
  }

  hist
}
