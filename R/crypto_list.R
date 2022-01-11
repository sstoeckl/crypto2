#' Retrieves name, CMC id, symbol, slug, rank, an activity flag as well as activity dates on CMC for all coins
#'
#' This code uses the web api. It retrieves data for all historic and all active coins and does not require an 'API' key.
#'
#' @param only_active Shall the code only retrieve active coins (TRUE=default) or include inactive coins (FALSE)
#' @param add_untracked Shall the code additionally retrieve untracked coins (FALSE=default)
#'
#' @return List of (active and historically existing) cryptocurrencies in a tibble:
#'   \item{id}{CMC id (unique identifier)}
#'   \item{name}{Coin name}
#'   \item{symbol}{Coin symbol (not-unique)}
#'   \item{slug}{Coin URL slug (unique)}
#'   \item{rank}{Current rank on CMC (if still active)}
#'   \item{is_active}{Flag showing whether coin is active (1), inactive(0) or untracked (-1)}
#'   \item{first_historical_data}{First time listed on CMC}
#'   \item{last_historical_data}{Last time listed on CMC, *today's date* if still listed}
#'
#' @importFrom tibble as_tibble
#' @importFrom jsonlite fromJSON
#' @importFrom dplyr bind_rows mutate rename arrange distinct
#'
#' @examples
#' \dontrun{
#' # return all coins
#' active_list <- crypto_list(only_active=TRUE)
#' all_but_untracked_list <- crypto_list(only_active=FALSE)
#' full_list <- crypto_list(only_active=FALSE,add_untracked=TRUE)
#'
#' # return all coins active in 2015
#' coin_list_2015 <- active_list %>%
#' dplyr::filter(first_historical_data<="2015-12-31",
#'               last_historical_data>="2015-01-01")
#'
#' }
#'
#' @name crypto_list
#'
#' @export
#'
crypto_list <- function(only_active=TRUE, add_untracked=FALSE) {
  # get current coins
  active_url <- paste0("https://web-api.coinmarketcap.com/v1/cryptocurrency/map")
  active_coins <- jsonlite::fromJSON(active_url)
  coins <- active_coins$data %>% tibble::as_tibble() %>% dplyr::mutate(dplyr::across(7:8,as.Date))

  if (!only_active){
    inactive_url <- paste0("https://web-api.coinmarketcap.com/v1/cryptocurrency/map?listing_status=inactive")
    inactive_coins <- jsonlite::fromJSON(inactive_url)
    coins <- dplyr::bind_rows(coins,
                       inactive_coins$data %>% tibble::as_tibble() %>% dplyr::mutate(dplyr::across(7:8,as.Date))) %>% dplyr::arrange(id)
  }
  if (add_untracked){
    untracked_url <- paste0("https://web-api.coinmarketcap.com/v1/cryptocurrency/map?listing_status=untracked")
    untracked_coins <- jsonlite::fromJSON(untracked_url)
    coins <- dplyr::bind_rows(coins,
                        untracked_coins$data %>% tibble::as_tibble() %>% dplyr::mutate(dplyr::across(7:8,as.Date),is_active=-1)) %>% dplyr::arrange(id)
  }
  return(coins %>% dplyr::select(id:last_historical_data) %>% dplyr::distinct() %>% dplyr::arrange(id))
}
#' Retrieves name, CMC id, symbol, slug, rank, an activity flag as well as activity dates on CMC for all coins
#'
#' This code uses the web api. It retrieves data for all historic and all active coins and does not require an 'API' key.
#'
#' @param only_active Shall the code only retrieve active coins (TRUE=default) or include inactive coins (FALSE)
#' @param add_untracked Shall the code additionally retrieve untracked coins (FALSE=default)
#'
#' @return List of (active and historically existing) cryptocurrencies in a tibble:
#'   \item{id}{CMC exchange id (unique identifier)}
#'   \item{name}{Exchange name}
#'   \item{slug}{Exchange URL slug (unique)}
#'   \item{is_active}{Flag showing whether exchange is active (1), inactive(0) or untracked (-1)}
#'   \item{first_historical_data}{First time listed on CMC}
#'   \item{last_historical_data}{Last time listed on CMC, *today's date* if still listed}
#'
#' @importFrom tibble as_tibble
#' @importFrom jsonlite fromJSON
#' @importFrom dplyr bind_rows mutate rename arrange distinct
#'
#' @examples
#' \dontrun{
#' # return all coins
#' ex_active_list <- exchange_list(only_active=TRUE)
#' ex_all_but_untracked_list <- exchange_list(only_active=FALSE)
#' ex_full_list <- exchange_list(only_active=FALSE,add_untracked=TRUE)
#'
#' }
#'
#' @name exchange_list
#'
#' @export
#'
exchange_list <- function(only_active=TRUE, add_untracked=FALSE) {
  # get current coins
  active_url <- paste0("https://web-api.coinmarketcap.com/v1/exchange/map")
  active_exchanges <- jsonlite::fromJSON(active_url)
  exchanges <- active_exchanges$data %>% tibble::as_tibble() %>% dplyr::mutate(dplyr::across(5:6,as.Date))

  if (!only_active){
    inactive_url <- paste0("https://web-api.coinmarketcap.com/v1/exchange/map?listing_status=inactive")
    inactive_exchanges <- jsonlite::fromJSON(inactive_url)
    exchanges <- dplyr::bind_rows(exchanges,
                              inactive_exchanges$data %>% tibble::as_tibble() %>% dplyr::mutate(dplyr::across(5:6,as.Date))) %>% dplyr::arrange(id)
  }
  if (add_untracked){
    untracked_url <- paste0("https://web-api.coinmarketcap.com/v1/exchange/map?listing_status=untracked")
    untracked_exchanges <- jsonlite::fromJSON(untracked_url)
    exchanges <- dplyr::bind_rows(exchanges,
                              untracked_exchanges$data %>% tibble::as_tibble() %>% dplyr::mutate(dplyr::across(5:6,as.Date),is_active=-1)) %>% dplyr::arrange(id)
  }
  return(exchanges %>% dplyr::select(id:last_historical_data) %>% dplyr::distinct() %>% dplyr::arrange(id))
}
