#' Retrieves historical quotes for the global aggregate market
#'
#' This code uses the web api. It retrieves global quote data (latest/historic) and does not require an 'API' key.
#'
#' @param which string Shall the code retrieve the latest listing or a historic listing?
#' @param convert string (default: USD) to one or more of available fiat or precious metals prices (`fiat_list()`). If more
#' than one are selected please separate by comma (e.g. "USD,BTC"), only necessary if 'quote=TRUE'
#' @param start_date string Start date to retrieve data from, format 'yyyymmdd'
#' @param end_date string End date to retrieve data from, format 'yyyymmdd', if not provided, today will be assumed
#' @param interval string Interval with which to sample data, default 'daily'. Must be one of `"hourly" "daily" "weekly"
#' "monthly" "yearly" "1d" "2d" "3d" "7d" "14d" "15d" "30d" "60d" "90d" "365d"`
#' @param quote logical set to TRUE if you want to include price data (FALSE=default)
#' @param finalWait to avoid calling the web-api again with another command before 60s are over (TRUE=default)
#'
#' @return List of latest/new/historic listings of crypto currencies in a tibble (depending on the "which"-switch and
#' whether "quote" is requested, the result may only contain some of the following variables):
#' \item{btc_dominance}{number Bitcoin's market dominance percentage by market cap.}
#' \item{eth_dominance}{number Ethereum's market dominance percentage by market cap.}
#' \item{active_cryptocurrencies}{number Count of active crypto currencies tracked by CMC
#' This includes all crypto currencies with a listing_status of "active" or "listed".}
#' \item{total_cryptocurrencies}{number Count of all crypto currencies tracked by CMC
#' This includes "inactive" listing_status crypto currencies.}
#' \item{active_market_pairs}{number Count of active market pairs tracked by CoinMarketCap across all exchanges.}#'
#' \item{active_exchanges}{number Count of active exchanges tracked by CMC This includes all
#' exchanges with a listing_status of "active" or "listed".}
#' \item{total_exchanges}{number Count of all exchanges tracked by CMC
#' This includes "inactive" listing_status exchanges.}
#' \item{last_updated}{Timestamp of when this record was last updated.}
#' \item{total_market_cap}{number The sum of all individual cryptocurrency market capitalizations in the requested currency.}
#' \item{total_volume_24h}{number The sum of rolling 24 hour adjusted volume (as outlined in our methodology) for all
#' crypto currencies in the requested currency.}
#' \item{total_volume_24h_reported}{number The sum of rolling 24 hour reported volume for all crypto currencies in the requested currency.}#'
#' \item{altcoin_volume_24h}{number The sum of rolling 24 hour adjusted volume (as outlined in our methodology) for
#' all crypto currencies excluding Bitcoin in the requested currency.}
#' \item{altcoin_volume_24h_reported}{number The sum of rolling 24 hour reported volume for
#' all crypto currencies excluding Bitcoin in the requested currency.}
#' \item{altcoin_market_cap	}{number The sum of all individual cryptocurrency market capitalizations excluding Bitcoin in the requested currency.}
#'
#' @importFrom tibble as_tibble
#' @importFrom jsonlite fromJSON
#' @importFrom dplyr bind_rows mutate rename arrange distinct
#' @importFrom tidyr unnest unnest_wider pivot_wider pivot_longer
#'
#' @examples
#' \dontrun{
#' # return new listings from the last 30 days
#' new_quotes <- crypto_global_quotes(which="latest", quote=FALSE)
#' new_quotes2 <- crypto_global_quotes(which="latest", quote=TRUE, convert="BTC,USD")
#' # return all global quotes in the first week of January 2014
#' quotes_2014w1 <- crypto_global_quotes(which="historical", quote=TRUE,
#' start_date = "20140101", end_date="20140107", interval="daily")
#'
#' # report in two different currencies
#' listings_2014w1_USDBTC <- crypto_global_quotes(which="historical", quote=TRUE,
#' start_date = "20140101", end_date="20140107", interval="daily", convert="USD,BTC")
#' }
#'
#' @name crypto_global_quotes
#'
#' @export
#'
crypto_global_quotes <- function(which="latest", convert="USD", start_date = NULL, end_date = NULL, interval = "daily", quote=FALSE, finalWait = FALSE) {
  # get current coins
  quotes_raw <- NULL
 if (which=="latest"){

      latest_url <- paste0("https://web-api.coinmarketcap.com/v1/global-metrics/quotes/latest?convert=",convert)
      latest_raw <- jsonlite::fromJSON(latest_url)
      global_quotes_raw <- latest_raw$data  %>% tibble::as_tibble() %>%
        dplyr::mutate(dplyr::across(c(last_updated),as.Date))


    global_quotes <- global_quotes_raw %>% select(-quote) %>% unique()
    if (quote){
      lquote <- global_quotes_raw %>% select(quote) %>% tidyr::unnest_wider(quote) %>%
        tibble::add_column("quote"=names(latest_raw$data$quote)) %>% select(-last_updated) %>%
        tidyr::pivot_longer(cols = total_market_cap:total_volume_24h_yesterday_percentage_change, names_to="VAR", values_to = "VAL") %>%
        tidyr::pivot_wider(names_from = c(quote,VAR), names_sep = "_", values_from = "VAL")
      global_quotes <- global_quotes %>% bind_cols(lquote) %>% unique()
    }
  } else if (which=="historical"){
    if (is.null(start_date)) { start_date <- "20130428" }
    UNIXstart <- format(as.numeric(as.POSIXct(start_date, format="%Y%m%d")),scientific = FALSE)
    if (is.null(end_date)) { end_date <- gsub("-", "", lubridate::today()) }
    UNIXend <- format(as.numeric(as.POSIXct(end_date, format="%Y%m%d", tz = "UTC")),scientific = FALSE)
    if (is.null(interval)) {
      interval <- 'daily'
    } else if (
      !(interval %in% c(#"hourly",
        "daily", "weekly", "monthly", "yearly",
        #"1h", "2h", "3h", "4h", "6h", "12h",
        "1d", "2d",
        "3d", "7d", "14d", "15d", "30d", "60d", "90d", "365d"))){
      warning('interval was not valid, using "daily". see documentation for allowed values.')
      interval <- 'daily'
    }
    hist_url <- paste0(
      "https://web-api.coinmarketcap.com/v1/global-metrics/quotes/historical?convert=",
      convert,
      "&time_end=",
      UNIXend,
      "&time_start=",
      UNIXstart,
      "&interval=",
      interval
    )
    hist_raw <- jsonlite::fromJSON(hist_url)
    global_quotes_raw <- hist_raw$data$quotes  %>% tibble::as_tibble() %>%
      dplyr::mutate(dplyr::across(c(timestamp),as.Date))


    global_quotes <- global_quotes_raw %>% select(-quote) %>% unique()
    if (quote){
      lquote <- global_quotes_raw %>% select(quote) %>% tidyr::unnest_wider(quote) %>%
        tidyr::unnest(everything(), names_sep="_")
      global_quotes <- global_quotes %>% bind_cols(lquote) %>% unique()
    }
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
  return(global_quotes)
}
