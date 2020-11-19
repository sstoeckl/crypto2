#' Get historic crypto currency market data
#'
#' Scrape the crypto currency historic market tables from
#' CoinMarketCap <https://coinmarketcap.com> and display
#' the results in a date frame. This can be used to conduct
#' analysis on the crypto financial markets or to attempt
#' to predict future market movements or trends.
#'
#' @param coin_list string if NULL retrieve all currently existing coins (crypto_list()),
#' or provide list of crypto currencies in the crypto_list() format (e.g. current and dead coins since 2015)
#' @param limit integer Return the top n records, default is all tokens
#' @param start_date string Start date to retrieve data from, format 'yyyymmdd'
#' @param end_date string End date to retrieve data from, format 'yyyymmdd', if not provided, today will be assumed
#' @param sleep integer Seconds to sleep for between API requests
#
#' @return Crypto currency historic OHLC market data in a dataframe and additional information via attribute "info":
#'   \item{timestamp}{Timestamp of entry in database}
#'   \item{slug}{Coin url slug}
#'   \item{id}{Coin market cap unique id}
#'   \item{name}{Coin name}
#'   \item{symbol}{Coin symbol}
#'   \item{open}{Market open}
#'   \item{high}{Market high}
#'   \item{low}{Market low}
#'   \item{close}{Market close}
#'   \item{volume}{Volume 24 hours}
#'   \item{time_open}{Timestamp of open}
#'   \item{time_close}{Timestamp of close}
#'   \item{time_high}{Timestamp of high}
#'   \item{time_low}{Timestamp of low}
#'
#' This is the main function of the crypto package. If you want to retrieve
#' ALL active coins then do not pass an argument to crypto_history(), or pass the coin name.
#'
#' @importFrom tidyr 'replace_na'
#' @importFrom crayon 'make_style'
#' @importFrom grDevices 'rgb'
#' @importFrom tibble 'tibble' 'as_tibble' 'rowid_to_column'
#' @importFrom cli 'cat_bullet'
#' @importFrom lubridate 'mdy'
#' @importFrom stats 'na.omit'
#'
#' @import progress
#' @import purrr
#' @import dplyr
#'
#' @examples
#' \dontrun{
#'
#' # Retrieving market history for ALL crypto currencies
#' all_coins <- crypto_history(limit = 1)
#'
#' # Retrieving this years market history for ALL crypto currencies
#' all_coins <- crypto_history(start_date = '20200101',limit=10)
#'
#' # Retrieve 2015 history for all 2015 crypto currencies
#' coin_list_2015 <- crypto_list(start_date_hist="20150101",
#' end_date_hist="20150201",date_gap="months")
#' coins_2015 <- crypto_history(coin_list = coin_list_2015,
#' start_date = "20150101", end_date="20151231", limit=20)
#'
#' }
#'
#' @name crypto_history
#'
#' @export
#'
crypto_history <- function(coin_list = NULL, limit = NULL, start_date = NULL, end_date = NULL, sleep = NULL) {
  # only if no coins are provided use the old cryptolist feature that provides all the actively traded coins plus...
  if (is.null(coin_list)) coin_list <- crypto_list()
  # limit amount of coins downloaded
  if (!is.null(limit)) coin_list <- coin_list[1:limit, ]
  # Create UNIX timestamps for download
  if (is.null(start_date)) { start_date <- "20130428" }
  UNIXstart <- as.numeric(as.POSIXct(start_date, format="%Y%m%d"))
  if (is.null(end_date)) { end_date <- gsub("-", "", lubridate::today()) }
  UNIXend <- as.numeric(as.POSIXct(end_date, format="%Y%m%d", tz = "UTC"))
  # create web-api urls
  historyurl <-
    paste0(
      "https://web-api.coinmarketcap.com/v1/cryptocurrency/ohlcv/historical?convert=USD&slug=",
      coin_list$slug,
      "&time_end=",
      UNIXend,
      "&time_start=",
     UNIXstart
    )
  coin_list_plus <- coin_list %>% dplyr::bind_cols(.,history_url=historyurl)
  # define scraper_funtion
  scrape_web <- function(url,slug){
    page <- jsonlite::fromJSON(url)
    pb$tick()
    return(page)
  }
  # define backoff rate
  rate <- purrr::rate_delay(pause=65,max_times = 2)
    #rate_backoff(pause_base = 3, pause_cap = 70, pause_min = 40, max_times = 10, jitter = TRUE)
  # Modify function to run insistently.
  insistent_scrape <- purrr::possibly(purrr::insistently(scrape_web, rate, quiet = FALSE),otherwise=NULL)
  # Progress Bar 1
  pb <- progress_bar$new(format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
                         total = min(limit,nrow(coin_list_plus)), clear = FALSE)
  message(cli::cat_bullet("Scraping historical crypto data", bullet = "pointer",bullet_col = "green"))
  data <- coin_list_plus %>% dplyr::select(history_url,slug) %>% dplyr::mutate(out = purrr::map2(history_url,slug,.f=~insistent_scrape(.x,.y)))
  # Progress Bar 2
  pb2 <- progress_bar$new(format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
                         total = min(limit,nrow(data)), clear = FALSE)
  map_scrape <- function(out,slug){
    pb2$tick()
    if (!(out$status$error_code==0)) {
      cat("\nCoin",slug,"could not be downloaded. Error message: ",out$status$error_message,"!\n")
      } else if (length(out$data$quotes)==0){
      cat("\nCoin",slug,"does not have data available! Cont to next coin.\n")
    } else {
      status <- out$status %>% purrr::flatten() %>% as_tibble() %>% mutate(timestamp=as.POSIXlt(timestamp,format="%Y-%m-%dT%H:%M:%S"))
      outdata <- out$data$quotes$quote$USD %>% tibble::as_tibble() %>% mutate(timestamp=as.POSIXlt(timestamp,format="%Y-%m-%dT%H:%M:%S")) %>%
        dplyr::bind_cols(.,out$data$quotes %>% select(-quote) %>% tibble::as_tibble() %>% mutate(across(1:4,~as.POSIXlt(.,format="%Y-%m-%dT%H:%M:%S")))) %>%
        mutate(id=out$data$id,name=out$data$name,symbol=out$data$symbol,slug=slug) %>% select(timestamp,slug,id,name,symbol,everything())
    }
  }
  message(cli::cat_bullet("Processing historical crypto data", bullet = "pointer",bullet_col = "green"))
  out <- purrr::map2(data$out,data$slug, .f = ~ map_scrape(.x,.y))

  # Old code
  results <- do.call(rbind, out) %>% tibble::as_tibble()

  if (length(results) == 0L) stop("No data downloaded.", call. = FALSE)

  market_data <- results %>% dplyr::left_join(coin_list %>% dplyr::select(symbol,name,slug) %>% unique(), by = "slug")
  colnames(market_data) <- c("date", "open", "high", "low", "close", "volume",
    "market", "slug", "symbol", "name")

  return(results)
}
