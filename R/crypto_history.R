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
#' @param interval string Interval with which to sample data according to what `seq()` needs
#' @param requestLimit limiting the length of request URLs when bundling the api calls
#' @param sleep integer (default 60) Seconds to sleep between API requests
#' @param wait waiting time before retry in case of fail (needs to be larger than 60s in case the server blocks too many attempts, default=60)
#' @param finalWait to avoid calling the web-api again with another command before 60s are over (TRUE=default)
#' @param single_id Download data coin by coin (as of May 2024 this is necessary)
#
#' @return Crypto currency historic OHLC market data in a dataframe and additional information via attribute "info":
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
#' @importFrom tidyr replace_na expand_grid
#' @importFrom tibble tibble as_tibble rowid_to_column
#' @importFrom cli cat_bullet
#' @importFrom lubridate mdy today
#' @importFrom stats na.omit
#' @importFrom plyr laply
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
  # only if no coins are provided use crypto_list() to provide all actively traded coins
  if (is.null(coin_list)) coin_list <- crypto_list()
  # limit amount of coins downloaded
  if (!is.null(limit)) coin_list <- coin_list[1:limit, ]
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
  # time_period
  if (interval %in% c("hourly","1h", "2h", "3h", "4h", "6h", "12h")){time_period="hours"} else {time_period="days"}
  # extract slugs & ids
  slugs <- coin_list %>% dplyr::distinct(slug)
  ids <- coin_list %>% dplyr::distinct(id) |>  dplyr::pull(id)
  # Create slug_vec with number of elements determined by max length of retrieved datapoints (10000)
  if (time_period=="hours"){
    dl <- seq(as.POSIXct(paste0(start_date," 00:00:00")),as.POSIXct(paste0(end_date," 23:00:00")),"hour")
    # split time vector in chunks of requestLimit
    if (length(dl)>=requestLimit) {
      start_dates <- seq(from = as.POSIXct(paste0(start_date," 00:00:00")), by = paste(requestLimit,time_period),
                         length.out = length(dl) %/% requestLimit +1)
      end_dates_start <- seq(from = start_dates[2], by = paste(-1,time_period), length.out = 2)
      end_dates <- seq(from = end_dates_start[2], by = paste(requestLimit,time_period),
                       length.out = length(dl) %/% requestLimit +1)
      if (end_dates[length(end_dates)] > end_date) {
        end_dates[length(end_dates)] <- as.POSIXct(paste0(end_date," 23:00:00"))
        start_dates <- start_dates[1:length(end_dates)]
      }
      # UNIX format
      # Create UNIX timestamps for download
      UNIXstart <- format(as.numeric(start_dates),scientific = FALSE)
      UNIXend <- format(as.numeric(end_dates),scientific = FALSE)
      dates <- tibble::tibble(start_dates,end_dates,startDate=UNIXstart, endDate=UNIXend)
    } else {
      UNIXstart <- format(as.numeric(as.POSIXct(as.Date(start_date))-1),scientific = FALSE)
      UNIXend <- format(as.numeric(as.POSIXct(as.Date(end_date), tz = "UTC")),scientific = FALSE)
      dates <- tibble::tibble(start_dates=start_date,end_dates=end_date,startDate=UNIXstart, endDate=UNIXend)
    }
  } else {
    dl <- seq(as.Date(start_date),as.Date(end_date),"day")
    # split time vector in chunks of requestLimit
    if (length(dl)>=requestLimit) {
      start_dates <- seq(from = as.Date(start_date), by = paste(requestLimit,time_period), length.out = length(dl) %/% requestLimit +1)
      end_dates_start <- seq(from = start_dates[2], by = paste(-1,time_period), length.out = 2)
      end_dates <- seq(from = end_dates_start[2], by = paste(requestLimit,time_period), length.out = length(dl) %/% requestLimit +1)
      if (end_dates[length(end_dates)] > end_date) {
        end_dates[length(end_dates)] <- end_date
        start_dates <- start_dates[1:length(end_dates)]
      }
      # UNIX format
      # Create UNIX timestamps for download
      UNIXstart <- format(as.numeric(as.POSIXct(as.Date(start_dates)-1, format="%Y%m%d")),scientific = FALSE)
      UNIXend <- format(as.numeric(as.POSIXct(as.Date(end_dates), format="%Y%m%d", tz = "UTC")),scientific = FALSE)
      dates <- tibble::tibble(start_dates,end_dates,startDate=UNIXstart, endDate=UNIXend)
    } else {
      UNIXstart <- format(as.numeric(as.POSIXct(as.Date(start_date)-1, format="%Y%m%d")),scientific = FALSE)
      UNIXend <- format(as.numeric(as.POSIXct(as.Date(end_date), format="%Y%m%d", tz = "UTC")),scientific = FALSE)
      dates <- tibble::tibble(start_dates=start_date,end_dates=end_date,startDate=UNIXstart, endDate=UNIXend)
    }
  }
  # determine number of splits based on either max 10000 datapoints or max-length of url
  if (!single_id) {n <- max(ceiling(nrow(ids)/floor(10000/dl)),ceiling(nrow(ids)/(2000-142)*6))} else {n<-length(ids)}
  id_vec <- plyr::laply(split(ids, sort(seq_len(length(ids))%%n)),function(x) paste0(x,collapse=","))
  # create tibble to use
  id_vec <- tidyr::expand_grid(id=ids,dates)

  # define scraper_function
  scrape_web <- function(historyurl){
    page <- safeFromJSON(construct_url(historyurl,v="3.1"))
    pb$tick()
    return(page$data)
  }
  # add history URLs
  id_vec <- id_vec %>% dplyr::mutate(historyurl=paste0(
    "cryptocurrency/historical?id=",
    id,
    "&convertId=",
    convertId,
    "&timeStart=",
    startDate,
    "&timeEnd=",
    endDate,
    "&interval=",
    interval
    ))
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
  if (!single_id) {if (nrow(coin_list)==1) {data2 <- data$out} else {data2 <- data$out %>% unlist(.,recursive=FALSE)}
  } else {
    data2 <- data$out
  }
  # 2. Here comes the second part: Clean and create dataset
  map_scrape <- function(lout){
    pb2$tick()
    if (length(lout$quotes)==0){
      cat("\nCoin",lout$name,"does not have data available! Cont to next coin.\n")
    } else {
      suppressWarnings(
        # only one currency possible at this time
        outall <- lout$quotes |>  tibble::as_tibble() |>  tidyr::unnest(quote) |>
          dplyr::mutate(across(contains("time"),~as.POSIXlt(.,format="%Y-%m-%dT%H:%M:%S"))) |>
          janitor::clean_names() |>
          dplyr::mutate(id=lout$id,name=lout$name,symbol=lout$symbol,ref_cur_id=lout$quotes$quote$name,ref_cur_name=convert) |>
          dplyr::select(id,name,symbol,timestamp,ref_cur_id,ref_cur_name,everything())
      )
    }
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

  # results
  results <-dplyr:: bind_rows(out_info) %>% tibble::as_tibble() %>%
    dplyr::left_join(coin_list %>% dplyr::select(id, slug), by ="id") %>%
    dplyr::relocate(slug, .after = id) %>%
    dplyr::filter(timestamp>=start_date)
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
