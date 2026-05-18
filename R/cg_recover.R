#' Fetch CoinGecko history by numeric ID (incl. partial survivorship-bias
#' correction)
#'
#' Companion to [cg_history()] that addresses coins by their internal
#' **numeric ID** instead of their slug. Useful in two scenarios:
#'
#' 1. Coins that have been **delisted** from CoinGecko's slug routing
#'    (i.e., `api.coingecko.com/api/v3/coins/{slug}` now returns 404) but
#'    whose numeric ID still serves data on the website-host endpoints.
#'    This holds at least for low/early IDs.
#' 2. Cronjob-style accumulation: when you persist `cg_list()` snapshots
#'    over time, the **union of all numeric IDs ever observed** is the
#'    survivorship-bias-corrected universe. `cg_history_by_id()` lets you
#'    refetch each historical ID directly without needing its current
#'    slug to still resolve.
#'
#' Important caveats -- please read:
#' * **The numeric-ID space is sparse, not dense.** CoinGecko's
#'   auto-increment counter has been allocated up to ~102 million, but
#'   only ~15 000 IDs are actually populated as of mid 2026.
#'   **Blind iteration over `1:N` does NOT recover the full universe** --
#'   most numeric IDs in that range return 404. The default `ids = NULL`
#'   therefore uses the active universe from `cg_list()`, NOT a numeric
#'   range. To recover delisted coins you must supply the IDs explicitly
#'   (e.g., the union of accumulated `cg_list()` snapshots).
#' * **Slug recovery for delisted coins is not available** through any
#'   free-tier endpoint. Active coins get their slug/name joined back in
#'   from `cg_list()`; rows whose numeric ID is no longer in the active
#'   universe come back with `slug = NA` and `name = NA`. Use the `id`
#'   column as the join key in downstream code.
#' * **It is empirically true** that some low/early numeric IDs continue
#'   to serve historical data even when their slug has been removed from
#'   the public API. The exact coverage policy is undocumented and may
#'   change without notice.
#'
#' @param ids Integer vector of numeric IDs to fetch. Default `NULL` ->
#'   uses `cg_list()$id` (active universe). To extend coverage to
#'   delisted coins, supply the union of historically-observed IDs from
#'   your accumulated snapshots.
#' @param what Subset of streams to fetch. Any combination of
#'   `"price"`, `"market_cap"`, and `"ohlc"`. Default all three.
#' @param vs_currency Quote currency, default `"usd"`.
#' @param start_date,end_date Client-side date filter applied after fetch.
#'   `NULL` returns full history.
#' @param coin_list Optional `cg_list()` output used to join `slug` /
#'   `name` / `symbol` onto recovered rows for coins still in the active
#'   universe. If `NULL`, calls `cg_list(top_n = 0)` automatically. Set
#'   to `FALSE` to skip the join (rows then have only `id`).
#' @param sleep,wait,max_retries Passed to [cg_make_client()]. Defaults
#'   `0.6 / 60 / 3` match `cg_history()`.
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
                             quiet = FALSE, finalWait = FALSE) {
  what <- match.arg(what, choices = c("price", "market_cap", "ohlc"),
                    several.ok = TRUE)
  vs <- tolower(vs_currency)

  if (is.null(ids)) {
    if (is.null(coin_list) || isFALSE(coin_list)) {
      message(cli::cat_bullet(
        "ids = NULL -> pulling cg_list() to define the universe",
        bullet = "pointer", bullet_col = "cyan"))
      coin_list <- cg_list(top_n = 0)
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

  client <- cg_make_client(sleep = sleep, wait = wait,
                           max_retries = max_retries)

  fetch_one <- function(numeric_id) {
    out <- NULL

    if ("price" %in% what) {
      pj <- cg_parse_json(client(cg_url(
        sprintf("price_charts/%d/%s/max.json", numeric_id, vs))))
      if (!is.null(pj) && length(pj$stats)) {
        pr <- tibble::tibble(
          timestamp = cg_ms_to_posix(pj$stats[, 1]),
          close     = as.numeric(pj$stats[, 2])
        )
        pr <- floor_daily_(pr, "close")
        if (!is.null(pj$total_volumes) && length(pj$total_volumes)) {
          vol <- tibble::tibble(
            timestamp = cg_ms_to_posix(pj$total_volumes[, 1]),
            volume    = as.numeric(pj$total_volumes[, 2])
          )
          vol <- floor_daily_(vol, "volume")
          pr <- dplyr::full_join(pr, vol, by = "date")
        } else {
          pr$volume <- NA_real_
        }
        out <- pr
      }
    }

    if ("market_cap" %in% what) {
      mj <- cg_parse_json(client(cg_url(
        sprintf("market_cap/%d/%s/max.json", numeric_id, vs))))
      if (!is.null(mj) && length(mj$stats)) {
        mc <- tibble::tibble(
          timestamp  = cg_ms_to_posix(mj$stats[, 1]),
          market_cap = as.numeric(mj$stats[, 2])
        )
        mc <- floor_daily_(mc, "market_cap")
        out <- if (is.null(out)) mc else dplyr::full_join(out, mc, by = "date")
      }
    }

    if ("ohlc" %in% what) {
      oj <- cg_parse_json(client(cg_url(
        sprintf("ohlc/%d/series/%s/max.json", numeric_id, vs))))
      if (!is.null(oj) && !is.null(oj$ohlc) && length(oj$ohlc)) {
        ohlc <- tibble::tibble(
          timestamp = cg_ms_to_posix(oj$ohlc[, 1]),
          open      = as.numeric(oj$ohlc[, 2]),
          high      = as.numeric(oj$ohlc[, 3]),
          low       = as.numeric(oj$ohlc[, 4]),
          close_o   = as.numeric(oj$ohlc[, 5])
        )
        ohlc <- floor_daily_(ohlc, c("open","high","low","close_o"))
        if (is.null(out)) {
          out <- ohlc %>% dplyr::mutate(close = close_o) %>% dplyr::select(-close_o)
        } else {
          out <- dplyr::full_join(out, ohlc, by = "date") %>%
            dplyr::mutate(close = ifelse(is.na(close_o), close, close_o)) %>%
            dplyr::select(-close_o)
        }
      }
    }

    if (is.null(out) || !nrow(out)) return(NULL)

    expected_cols <- c("open", "high", "low", "close", "volume", "market_cap")
    for (cc in setdiff(expected_cols, names(out))) out[[cc]] <- NA_real_

    out %>%
      dplyr::mutate(
        timestamp    = as.POSIXct(date, tz = "UTC"),
        id           = numeric_id,
        ref_cur_id   = vs,
        ref_cur_name = toupper(vs),
        time_open    = as.POSIXct(NA),
        time_high    = as.POSIXct(NA),
        time_low     = as.POSIXct(NA),
        time_close   = as.POSIXct(NA)
      ) %>%
      dplyr::select(
        id, timestamp, ref_cur_id, ref_cur_name,
        open, high, low, close, volume, market_cap,
        time_open, time_high, time_low, time_close
      )
  }

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

  results <- vector("list", n)
  for (i in seq_along(ids)) {
    if (!quiet) pb$tick()
    results[[i]] <- tryCatch(fetch_one(ids[i]), error = function(e) NULL)
  }
  results <- Filter(Negate(is.null), results)
  if (!length(results)) {
    warning("cg_history_by_id(): no data returned.", call. = FALSE)
    return(tibble::tibble())
  }
  hist <- dplyr::bind_rows(results)

  # Slug join (if requested)
  if (!isFALSE(coin_list)) {
    if (is.null(coin_list)) coin_list <- cg_list(top_n = 0)
    if ("id" %in% names(coin_list) && "slug" %in% names(coin_list)) {
      lookup <- coin_list[!is.na(coin_list$id),
                          c("id", "slug", "name", "symbol"), drop = FALSE]
      hist <- dplyr::left_join(hist, lookup, by = "id")
    } else {
      warning("cg_history_by_id(): `coin_list` lacks `id` / `slug` columns; ",
              "skipping slug join.", call. = FALSE)
      hist <- dplyr::mutate(hist, slug = NA_character_,
                            name = NA_character_, symbol = NA_character_)
    }
  } else {
    hist <- dplyr::mutate(hist, slug = NA_character_,
                          name = NA_character_, symbol = NA_character_)
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

# Internal: collapse a (timestamp, value...) tibble to daily bars on the
# UTC calendar. Shared between cg_history() and cg_history_by_id() -- the
# CoinGecko website endpoints intermix daily bars with a final rolling
# "now" point in the same series, so we floor to date and keep the last
# observation per day for each value column.
#
# (Exposed only inside the package as floor_daily_; cg_history's local
# floor_daily() variant predates this helper and remains for now to keep
# that file self-contained.)
floor_daily_ <- function(df, value_cols) {
  if (is.null(df) || !nrow(df)) return(df)
  df$date <- as.Date(df$timestamp, tz = "UTC")
  df <- df[order(df$date, df$timestamp), , drop = FALSE]
  df <- df[!duplicated(df$date, fromLast = TRUE), , drop = FALSE]
  df[, c("date", value_cols), drop = FALSE]
}
