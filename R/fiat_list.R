#' Retrieves list of all CMC supported fiat currencies available to convert cryptocurrencies
#'
#' This code uses the web api. It retrieves data for all available fiat currencies and does not require an API key.
#'
#' @param include_metals (default FALSE) Shall the code also retrieve available precious metals?
#'
#' @return List of (active and historically existing) cryptocurrencies in a tibble:
#'   \item{id}{CMC id (unique identifier)}
#'   \item{symbol}{Coin symbol (not-unique)}
#'   \item{name}{Coin name}
#'   \item{sign}{Fiat currency sign}
#'   \item{code}{Precious metals code}
#'
#' @importFrom tibble as_tibble
#' @importFrom jsonlite fromJSON
#' @importFrom dplyr bind_rows mutate rename arrange
#'
#' @examples
#' \dontrun{
#' # return all fiat currencies available on CMC as well as precious metals
#' fiat_list <- fiat_list(include_metals=TRUE)
#' }
#'
#' @name crypto_list
#'
#' @export
#'
fiat_list <- function(include_metals=FALSE) {
  # get current coins
  if (!include_metals){
    fiat_url <- paste0("https://web-api.coinmarketcap.com/v1/fiat/map")
    active_fiat <- jsonlite::fromJSON(fiat_url)
    fiats <- active_fiat$data %>% tibble::as_tibble()
  } else {
    fiat_url <- paste0("https://web-api.coinmarketcap.com/v1/fiat/map?include_metals=",include_metals)
    active_fiat <- jsonlite::fromJSON(fiat_url)
    fiats <- active_fiat$data %>% tibble::as_tibble()
  }
  return(fiats)
}
