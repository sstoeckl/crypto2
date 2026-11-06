#' Get historic crypto currency market data
#'
#' Scrape the crypto currency historic market tables from
#' 'CoinMarketCap' <https://coinmarketcap.com> and display
#' the results in a dataframe/tibble. This can be used to conduct
#' analysis on the crypto financial markets or to attempt
#' to predict future market movements or trends.
#'
#' @param coin_list string if NULL retrieve all currently existing coins (`crypto_list()`),
#' or provide list of crypto currencies in the `crypto_list()` or `cryptoi_listings()` format (e.g. current and/or dead coins since 2015)
#' @param convert (default: USD) to one of available fiat prices (`fiat_list()`) or bitcoin 'BTC'. Be aware, that since 2024 only USD and BTC are available here!
#' @param limit integer Return the top n records, default is all tokens
#' @param start_date date Start date to retrieve data from
#' @param end_date date End date to retrieve data from, if not provided, today will be assumed
#' @param interval string Interval with which to sample data, default 'daily'. Must be one of `"hourly" "daily"
#'  "1h" "3h" "1d" "7d" "30d"`
#' @param requestLimit number of data points per request (default 400). CMC
#'   returns at most 400 points per request, so larger values are reduced to 400.
#' @param sleep integer (default 60) Seconds to sleep between API requests
#' @param wait waiting time before retry in case of fail (needs to be larger than 60s in case the server blocks too many attempts, default=60)
#' @param finalWait to avoid calling the web-api again with another command before 60s are over (TRUE=default)
#' @param single_id Kept for compatibility; data are always downloaded coin by
#'   coin (as of May 2024 this is necessary)
#
#' @return Crypto currency historic OHLC market data in a dataframe:
#'   \item{timestamp}{Timestamp of entry in database}
#'   \item{id}{Coin market cap unique id}
#'   \item{name}{Coin name}
#'   \item{symbol}{Coin symbol}
#'   \item{ref_cur_id}{reference Currency id}
#'   \item{ref_cur_name}{reference Currency name}
#'   \item{open}{Market open}
#'   \item{high}{Market high}
#'   \item{low}{Market low}
#'   \item{close}{Market close}
#'   \item{volume}{Volume 24 hours}
#'   \item{market_cap}{Market cap - close x circulating supply}
#'   \item{time_open}{Timestamp of open}
#'   \item{time_close}{Timestamp of close}
#'   \item{time_high}{Timestamp of high}
#'   \item{time_low}{Timestamp of low}
#'
#' This is the main function of the crypto package. If you want to retrieve
#' ALL active coins then do not pass an argument to `crypto_history()`, alternatively pass the coin name.
#'
#' CMC returns at most 400 data points per request, and nothing at all if
#' one of them is missing. CMC's data do have such holes, e.g. the hourly
#' data of all coins lack 2020-02-12 00:00 UTC. `crypto_history()` therefore
#' narrows an empty request down to the hole and retrieves the data around
#' it. Periods that CMC does not have are reported in a warning and in
#' `attr(result, "gaps")`, a tibble with columns `id`, `slug`, `from` and
#' `to` (first and last missing data point, UTC).
#'
#' @importFrom tidyr replace_na expand_grid
#' @importFrom tibble tibble as_tibble rowid_to_column
#' @importFrom cli cat_bullet
#' @importFrom lubridate mdy today
#' @importFrom stats na.omit
#' @importFrom janitor clean_names
#'
#' @import progress
#' @import purrr
#' @import dplyr
#'
#' @examples
#' \dontrun{
#'
#' # Retrieving market history for ALL crypto currencies
#' all_coins <- crypto_history(limit = 2)
#' one_coin <- crypto_history(limit = 1, convert="BTC")
#'
#' # Retrieving market history since 2020 for ALL crypto currencies
#' all_coins <- crypto_history(start_date = '2020-01-01',limit=10)
#'
#' # Retrieve 2015 history for all 2015 crypto currencies
#' coin_list_2015 <- crypto_list(only_active=TRUE) %>%
#'               dplyr::filter(first_historical_data<="2015-12-31",
#'               last_historical_data>="2015-01-01")
#' coins_2015 <- crypto_history(coin_list = coin_list_2015,
#'               start_date = "2015-01-01", end_date="2015-12-31", limit=20, interval="30d")
#' # retrieve hourly bitcoin data for 2 days
#' btc_hourly <- crypto_history(coin_list = coin_list_2015,
#'               start_date = "2015-01-01", end_date="2015-01-03", limit=1, interval="1h")
#'
#' }
#'
#' @name crypto_history
#'
#' @export
#'
crypto_history <- function(coin_list = NULL, convert="USD", limit = NULL, start_date = NULL, end_date = NULL, interval = NULL,
                           requestLimit = 400, sleep = 0, wait = 60, finalWait = FALSE, single_id=TRUE) {
  # check if convert is valid
  if (!convert %in% c("USD", "BTC")) {
    if (!convert %in% fiat_list()) {
      stop("convert must be one of the available currencies, which is BTC or available via fiat_list().")
    }
  }
  # now create convertId from convert
  convertId <- ifelse(convert=="USD",2781,1)
  # only if no coins are provided use crypto_list() to provide all actively
  # traded coins. We fetch the full latest listing (two requests) so that
  # non-ranked rows (index products etc. that CMC returns at the top of
  # /listing with cmc_rank = NA but have no historical price data) can be
  # filtered out before applying limit.
  if (is.null(coin_list)) {
    coin_listings <- crypto_listings(limit = NULL, quote = FALSE)
    coin_list <- crypto_list() %>%
      dplyr::inner_join(coin_listings %>% dplyr::select(id, cmc_rank), by = "id") %>%
      dplyr::filter(!is.na(cmc_rank)) %>%
      dplyr::arrange(cmc_rank) %>%
      dplyr::select(-cmc_rank)
    if (!is.null(limit)) coin_list <- coin_list[seq_len(min(limit, nrow(coin_list))), ]
  } else if (!is.null(limit)) {
    if (!"cmc_rank" %in% names(coin_list)) {
      coin_listings <- crypto_listings(limit = NULL, quote = FALSE)
      coin_list <- coin_list %>%
        dplyr::inner_join(coin_listings %>% dplyr::select(id, cmc_rank), by = "id") %>%
        dplyr::filter(!is.na(cmc_rank)) %>%
        dplyr::arrange(cmc_rank) %>%
        dplyr::select(-cmc_rank)
    }
    coin_list <- coin_list[seq_len(min(limit, nrow(coin_list))), ]
  }
  # create dates
  if (is.null(start_date)) { start_date <- as.Date("2013-04-28") }
  if (is.null(end_date)) { end_date <- lubridate::today() }
  # convert dates
  start_date <- convert_date(start_date)
  end_date <- convert_date(end_date)
  # check dates
  if (end_date<as.Date("2013-04-29")) stop("Attention: CMC Data is only available after 2013-04-29!")
  if (start_date<as.Date("2013-04-28")) warning("CMC Data (that will be downloaded) starts after 2013-04-29!")
  # intervals
  if (is.null(interval)) {
    interval <- 'daily'
  } else if (
    !(interval %in% c("hourly",
                      "daily", #"weekly", "monthly", "yearly",
                      "1h", #"2h",
                      "3h", #"4h", "6h", "12h",
                      "1d", #"2d", "3d",
                      "7d", #"14d", "15d",
                      "30d"#, "60d", "90d", "365d"
                      ))){
    warning('interval was not valid, using "daily". see documentation for allowed values.')
    interval <- 'daily'
  }
  # length of one data point in seconds
  step <- c(hourly = 3600, "1h" = 3600, "3h" = 3 * 3600, daily = 86400, "1d" = 86400,
            "7d" = 7 * 86400, "30d" = 30 * 86400)[[interval]]
  # extract slugs & ids
  slugs <- coin_list %>% dplyr::distinct(slug)
  ids <- coin_list %>% dplyr::distinct(id) |>  dplyr::pull(id)
  # CMC answers each request with the (at most) 400 data points that end at
  # `timeEnd` and ignores `timeStart`. Requests are therefore laid out
  # backwards from the end date, exactly `cap` points apart, so that they
  # neither overlap nor leave gaps.
  cap <- min(requestLimit, 400)
  t_start <- as.numeric(as.POSIXct(as.Date(start_date), tz = "UTC"))
  t_end <- as.numeric(as.POSIXct(as.Date(end_date), tz = "UTC")) + 86399
  n_req <- ceiling((t_end - t_start + 1) / (cap * step))
  dates <- tibble::tibble(endTime = t_end - (seq_len(n_req) - 1) * cap * step)
  id_vec <- tidyr::expand_grid(id = ids, dates)

  # define scraper_function
  scrape_web <- function(historyurl, tick = TRUE){
    page <- safeFromJSON(construct_url(historyurl,v="3.1"))
    if (tick) pb$tick()
    return(page$data)
  }
  history_url <- function(id, endTime) {
    paste0("cryptocurrency/historical?id=", id,
           "&convertId=", convertId,
           "&timeStart=", format(endTime - cap * step + 1, scientific = FALSE),
           "&timeEnd=", format(endTime, scientific = FALSE),
           "&interval=", interval)
  }
  # add history URLs
  id_vec <- id_vec %>% dplyr::mutate(historyurl = history_url(id, endTime))
  # define backoff rate
  rate <- purrr::rate_delay(pause = wait, max_times = 2)
  rate2 <- purrr::rate_delay(sleep)
  #rate_backoff(pause_base = 3, pause_cap = 70, pause_min = 40, max_times = 10, jitter = TRUE)
  # Modify function to run insistently.
  insistent_scrape <- purrr::possibly(purrr::insistently(purrr::slowly(scrape_web, rate2), rate, quiet = FALSE),otherwise=NULL)
  # Progress Bar 1
  pb <- progress_bar$new(format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
                         total = nrow(id_vec), clear = FALSE)
  message(cli::cat_bullet("Scraping historical crypto data", bullet = "pointer",bullet_col = "green"))
  data <- id_vec %>% dplyr::mutate(out = purrr::map(historyurl,.f=~insistent_scrape(.x)))
  # A request whose window covers a hole in CMC's data comes back empty, also
  # for the points around the hole that do exist. Recover them by bisecting
  # for the latest window before and the earliest window after the hole.
  open_times <- function(page) {
    as.numeric(as.POSIXct(page$quotes$timeOpen, format = "%Y-%m-%dT%H:%M:%OS", tz = "UTC"))
  }
  open_range <- function(page) {
    if (!NROW(page$quotes)) return(NULL)
    range(open_times(page))
  }
  bisect <- function(id, ok_t, empty_t) {
    best <- NULL
    while (abs(empty_t - ok_t) > step) {
      mid <- ok_t + round((empty_t - ok_t) / step / 2) * step
      page <- insistent_scrape(history_url(id, mid), tick = FALSE)
      if (NROW(page$quotes)) { ok_t <- mid; best <- page } else empty_t <- mid
    }
    best
  }
  recovered <- list()
  for (cid in ids) {
    k <- which(data$id == cid)
    ends <- data$endTime[k]
    rng <- purrr::map(data$out[k], open_range)
    for (j in which(purrr::map_lgl(rng, is.null))) {
      # data after the hole: the newer request reached back to its window start
      newer_ok <- j > 1 && !is.null(rng[[j - 1]]) && rng[[j - 1]][1] <= ends[j] + step
      if (newer_ok) recovered <- c(recovered, list(bisect(cid, ends[j - 1], ends[j])))
      # data before the hole: the older request reached up to its window end;
      # the oldest request has no older neighbour, so probe one window further
      older <- if (j < length(k)) rng[[j + 1]]
      if (j == length(k) && newer_ok) {
        page <- insistent_scrape(history_url(cid, ends[j] - cap * step), tick = FALSE)
        older <- open_range(page)
        recovered <- c(recovered, list(page))
      }
      if (!is.null(older) && older[2] > ends[j] - cap * step - step) {
        recovered <- c(recovered, list(bisect(cid, ends[j] - cap * step, ends[j])))
      }
    }
  }
  data2 <- c(data$out, Filter(Negate(is.null), recovered))
  # 2. Here comes the second part: Clean and create dataset
  map_scrape <- function(lout){
    pb2$tick()
    if (length(lout$quotes)==0) return(NULL)
    suppressWarnings(
      # only one currency possible at this time
      outall <- lout$quotes |>  tibble::as_tibble() |>  tidyr::unnest(quote) |>
        dplyr::mutate(across(contains("time"),~as.POSIXlt(.,format="%Y-%m-%dT%H:%M:%S"))) |>
        janitor::clean_names() |>
        dplyr::mutate(id=lout$id,name=lout$name,symbol=lout$symbol,ref_cur_id=lout$quotes$quote$name,ref_cur_name=convert) |>
        dplyr::select(id,name,symbol,timestamp,ref_cur_id,ref_cur_name,everything())
    )
    return(outall)
  }
  # Modify function to run insistently.
  insistent_map <- purrr::possibly(map_scrape,otherwise=NULL)
  # Progress Bar 2
  pb2 <- progress_bar$new(format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
                          total = length(data2), clear = FALSE)
  message(cli::cat_bullet("Processing historical crypto data", bullet = "pointer",bullet_col = "green"))
  out_info <- purrr::map(data2,.f = ~ insistent_map(.x))
  #filter

  # results — guard against the case where every coin in the limited set
  # has no historical data (e.g., a slice that hits only index DTFs); the
  # final left_join would otherwise error with "Join columns in x must
  # be present in the data" because bind_rows returned an empty tibble.
  raw_results <- dplyr::bind_rows(out_info)
  if (!nrow(raw_results)) {
    warning("crypto_history(): no coins in this batch returned historical data. ",
            "Returning an empty tibble. Consider widening `limit` or passing a ",
            "`coin_list` that excludes index / non-tradeable products.",
            call. = FALSE)
    return(tibble::tibble(
      id = integer(0), slug = character(0), name = character(0),
      symbol = character(0), timestamp = as.POSIXct(character(0)),
      ref_cur_id = integer(0), ref_cur_name = character(0)
    ))
  }
  results <- raw_results %>% tibble::as_tibble() %>%
    dplyr::left_join(coin_list %>% dplyr::select(id, slug), by ="id") %>%
    dplyr::relocate(slug, .after = id) %>%
    dplyr::filter(as.Date(timestamp)>=start_date, as.Date(timestamp)<=end_date) %>%
    dplyr::distinct(id, timestamp, .keep_all = TRUE) %>%
    dplyr::arrange(match(id, ids), timestamp)
  no_data <- setdiff(ids, results$id)
  if (length(no_data)) {
    message("No historical data at CMC for id(s) ", paste(no_data, collapse = ", "), ".")
  }
  # Report what CMC itself does not have: gaps between a coin's data points
  # within the requested window.
  opens <- purrr::map(data2, function(page) {
    if (NROW(page$quotes)) tibble::tibble(id = page$id, open = open_times(page))
  })
  gaps <- dplyr::bind_rows(opens)
  if (nrow(gaps)) {
    gaps <- gaps %>%
      dplyr::filter(open >= t_start, open <= t_end) %>%
      dplyr::distinct() %>%
      dplyr::arrange(id, open) %>%
      dplyr::group_by(id) %>%
      dplyr::mutate(nxt = dplyr::lead(open)) %>%
      dplyr::ungroup() %>%
      dplyr::filter(!is.na(nxt), nxt - open > 1.5 * step) %>%
      dplyr::transmute(id,
                       from = as.POSIXct(open + step, origin = "1970-01-01", tz = "UTC"),
                       to = as.POSIXct(nxt - step, origin = "1970-01-01", tz = "UTC")) %>%
      dplyr::left_join(dplyr::distinct(coin_list, id, slug), by = "id") %>%
      dplyr::relocate(slug, .after = id)
  }
  if (nrow(gaps)) {
    fmt <- if (step < 86400) "%Y-%m-%d %H:%M UTC" else "%Y-%m-%d"
    shown <- gaps[seq_len(min(5, nrow(gaps))), ]
    warning(sprintf("crypto_history(): CMC has no data for %d period(s) in the requested window, see attr(result, \"gaps\"): %s%s",
                    nrow(gaps),
                    paste(shown$slug, ifelse(shown$from == shown$to, format(shown$from, fmt),
                                             paste(format(shown$from, fmt), "to", format(shown$to, fmt))),
                          collapse = "; "),
                    if (nrow(gaps) > 5) "; ..." else ""),
            call. = FALSE)
    attr(results, "gaps") <- gaps
  }
  # wait 60s before finishing (or you might end up with the web-api 60s bug)
  if (finalWait){
    pb <- progress_bar$new(
    format = "Final wait [:bar] :percent eta: :eta",
    total = 60, clear = FALSE, width= 60)
    for (i in 1:60) {
      pb$tick()
      Sys.sleep(1)
    }
  }

  return(results)
}
