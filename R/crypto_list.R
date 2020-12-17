#' Retrieves name, cmc id, symbol, slug, rank, an activity flas as well as activity dates on cmc for all coins
#'
#' This code uses the web api. It retrieves data for all historic and all active coins and does not require an API key.
#' This function replaces the old function \code{crypto_list()} (still available as \code{crypto_list_old()}
#' which does not work anymore due to the "load more" button that I could not figure out)
#'
#' @param only_active Shall the code only retrieve active coins (TRUE=default) or include inactive coins (FALSE)
#'
#' @return List of (active and historically existing) cryptocurrencies in a tibble:
#'   \item{id}{CMC id (unique identifier)}
#'   \item{symbol}{Coin symbol (not-unique)}
#'   \item{name}{Coin name}
#'   \item{slug}{Coin URL slug (unique)}
#'   \item{rank}{Current rank on CMC (if still active)}
#'   \item{first_historical_data}{First time listed on CMC}
#'   \item{last_historical_data}{Last time listed on CMC, NA if still listed}
#'
#' Required dependency that is used in function call \code{getCoins()}.
#' @importFrom tibble as_tibble
#' @importFrom jsonlite fromJSON
#' @importFrom dplyr bind_rows mutate rename arrange
#'
#' @examples
#' \dontrun{
#' # return all coins
#' coin_list <- crypto_list(only_active=FALSE)
#'
#' # return all coins listed in 2015
#' coin_list_2015 <- coin_list %>%
#' dplyr::filter(first_historical_data<="2015-12-31",
#' last_historical_data>="2015-01-01")
#'
#' }
#'
#' @name crypto_list
#'
#' @export
#'
crypto_list <- function(only_active=TRUE) {
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
  return(coins %>% dplyr::select(id:last_historical_data))
}
