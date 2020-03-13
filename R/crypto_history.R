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
#'   \item{slug}{Coin url slug}
#'   \item{symbol}{Coin symbol}
#'   \item{name}{Coin name}
#'   \item{date}{Market date}
#'   \item{open}{Market open}
#'   \item{high}{Market high}
#'   \item{low}{Market low}
#'   \item{close}{Market close}
#'   \item{volume}{Volume 24 hours}
#'   \item{market}{USD Market cap}
#'   \item{close_ratio}{Close rate, min-maxed with the high and low values that day}
#'   \item{spread}{Volatility premium, high minus low for that day}
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
#' coins_2015 <- crypto_history(coins = coin_list_2015,
#' start_date = "20150101", end_date="20151231", limit=20)
#'
#' @name crypto_history
#'
#' @export
#'
crypto_history <- function(coin_list = NULL, limit = NULL, start_date = NULL, end_date = NULL, sleep = NULL) {
  pink <- crayon::make_style(grDevices::rgb(0.93, 0.19, 0.65))
  options(scipen = 999)
  i <- "i"
  low <- NULL
  high <- NULL
  close <- NULL
  ranknow <- NULL

  # only if no coins are provided
  if (is.null(coin_list)) coin_list <- crypto_list(coin=NULL)
  # limit amount of coins downloaded
  if (!is.null(limit)) coin_list <- coin_list[1:limit, ]
  # Create history urls for download
  historyurl <-
    paste0(
      "https://coinmarketcap.com/currencies/",
      coin_list$slug,
      "/historical-data/?start=",
      start_date,
      "&end=",
      end_date
    )
  coin_list <- coin_list %>% dplyr::bind_cols(.,history_url=historyurl)
  # define scraper_funtion
  scrape_web <- function(url,slug){
    page <- xml2::read_html(url,handle = curl::new_handle("useragent" = "Mozilla/5.0"))
    pb$tick()
    return(page)
  }
  # define backoff rate
  rate <- rate_delay(pause=65,max_times = 2)
    #rate_backoff(pause_base = 3, pause_cap = 70, pause_min = 40, max_times = 10, jitter = TRUE)
  # Modify function to run insistently.
  insistent_scrape <- purrr::possibly(purrr::insistently(scrape_web, rate, quiet = FALSE),otherwise=NULL)
  # Progress Bar 1
  pb <- progress_bar$new(format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
                         total = min(limit,nrow(coins)), clear = FALSE)
  message(cli::cat_bullet("Scraping historical crypto data", bullet = "pointer",bullet_col = "green"))
  data <- coin_list %>% dplyr::select(history_url,slug) %>% dplyr::mutate(out = purrr::map2(history_url,slug,.f=~insistent_scrape(.x,.y)))
  # Progress Bar 2
  pb2 <- progress_bar$new(format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta",
                         total = min(limit,nrow(data)), clear = FALSE)
  map_scrape <- function(out,slug){
    pb2$tick()
    if (is.na(out)) {cat("\nCoin",slug,"could not be downloaded. Please check URL!\n")} else{
    temp <- rvest::html_nodes(out, css = "table") %>% .[3] %>%
      rvest::html_table(fill = TRUE) %>%
      replace(!nzchar(.), NA)
    if (!length(temp)==0) {ans <- temp %>% .[[1]] %>% tibble::as_tibble() %>%
        dplyr::mutate(slug = slug) %>% mutate(Date=lubridate::mdy(Date, locale = platform_locale()))} else {
          cat("\nCoin",slug,"has missing data. Please check URL!\n"); ans <- NULL
        }
    }
  }
  message(cli::cat_bullet("Processing historical crypto data", bullet = "pointer",bullet_col = "green"))
  out <- purrr::map2(data$out,data$slug, .f = ~ map_scrape(.x,.y))

  # Old code
  results <- do.call(rbind, out) %>% tibble::as_tibble()

  if (length(results) == 0L) stop("No data downloaded.", call. = FALSE)

  market_data <- results %>% dplyr::left_join(coins %>% dplyr::select(symbol,name,slug) %>% unique(), by = "slug")
  colnames(market_data) <- c("date", "open", "high", "low", "close", "volume",
    "market", "slug", "symbol", "name")

  history_results <- market_data %>%
    # create fake ranknow
    dplyr::left_join(market_data %>% dplyr::select(slug,date,volume) %>% dplyr::group_by(slug) %>%
                       dplyr::arrange(desc(date)) %>% dplyr::slice(1) %>%
                       dplyr::mutate_at(dplyr::vars(volume),~gsub(",","",.)) %>%
                       dplyr::mutate_at(dplyr::vars(volume),~gsub("-","0",.)) %>%
                       dplyr::mutate_at(dplyr::vars(volume),~as.numeric(.)) %>%
                       dplyr::ungroup() %>%  dplyr::arrange(desc(volume)) %>%
                       tibble::rowid_to_column("ranknow") %>% dplyr::select(slug,ranknow), by="slug") %>%
    dplyr::select(slug,symbol,name,date,ranknow,open,high,low,close,volume,market) %>%
    dplyr::mutate_at(dplyr::vars(open,high,low,close,volume,market),~gsub(",","",.)) %>%
    dplyr::mutate_at(dplyr::vars(high,low,close,volume,market),~gsub("-","0",.)) %>%
    dplyr::mutate_at(dplyr::vars(open,high,low,close,volume,market),~as.numeric(tidyr::replace_na(.,0))) %>%
    dplyr::mutate(close_ratio = (close - low)/(high - low) %>% round(4) %>% as.numeric(),
                  spread = (high - low) %>% round(2) %>% as.numeric()) %>%
    dplyr::mutate_at(dplyr::vars(close_ratio),~as.numeric(tidyr::replace_na(.,0))) %>%
    dplyr::group_by(symbol) %>%
    dplyr::arrange(ranknow,desc(date))

  return(history_results)
}
