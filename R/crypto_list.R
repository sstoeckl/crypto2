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
#' }
#'
#' @name crypto_list
#'
#' @export
#'
crypto_list <- function(only_active=TRUE, add_untracked=FALSE) {
  # get current coins
  path <- paste0("cryptocurrency/map")
  active_coins <- safeFromJSON(construct_url(path))
  coins <- active_coins$data %>% tibble::as_tibble() %>%
    dplyr::mutate(dplyr::across(c(first_historical_data,last_historical_data),as.Date))

  if (!only_active){
    path <- paste0("cryptocurrency/map?listing_status=inactive")
    inactive_coins <- safeFromJSON(construct_url(path))
    date_cols <- inactive_coins$data %>%
      select_if(is.character) %>%
      select(where(~ !any(is.na(as.Date(., format = "%Y-%m-%d", tryFormats = c("%Y-%m-%d", "%Y/%m/%d"))))))

    data_formatted <- inactive_coins$data %>%
      mutate(across(all_of(names(date_cols)), ~ as.Date(., format = "%Y-%m-%d", tryFormats = c("%Y-%m-%d", "%Y/%m/%d"))))
    coins <- dplyr::bind_rows(coins,
                              data_formatted %>% tibble::as_tibble() %>%
                                dplyr::arrange(id))
  }
  if (add_untracked){
    path <- paste0("cryptocurrency/map?listing_status=untracked")
    untracked_coins <- safeFromJSON(construct_url(path))
    date_cols <- untracked_coins$data %>%
      select_if(is.character) %>%
      select(where(~ !any(is.na(as.Date(., format = "%Y-%m-%d", tryFormats = c("%Y-%m-%d", "%Y/%m/%d"))))))

    data_formatted <- untracked_coins$data %>%
      mutate(across(all_of(names(date_cols)), ~ as.Date(., format = "%Y-%m-%d", tryFormats = c("%Y-%m-%d", "%Y/%m/%d"))))
    coins <- dplyr::bind_rows(coins,
                              data_formatted %>% tibble::as_tibble() %>%
                                dplyr::arrange(id))
  }
  return(coins %>% dplyr::select(id:last_historical_data) %>% dplyr::distinct() %>% dplyr::arrange(id))
}
#' Retrieves name, CMC id, symbol, slug, rank, an activity flag as well as activity dates on CMC for all coins
#'
#' This code uses the web api. It retrieves data for all historic and all active exchanges and does not require an 'API' key.
#'
#' @param only_active Shall the code only retrieve active exchanges (TRUE=default) or include inactive coins (FALSE)
#' @param add_untracked Shall the code additionally retrieve untracked exchanges (FALSE=default)
#'
#' @return List of (active and historically existing) exchanges in a tibble:
#'   \item{id}{CMC exchange id (unique identifier)}
#'   \item{name}{Exchange name}
#'   \item{slug}{Exchange URL slug (unique)}
#'   \item{is_active}{Flag showing whether exchange is active (1), inactive(0) or untracked (-1)}
#'   \item{first_historical_data}{First time listed on CMC}
#'   \item{last_historical_data}{Last time listed on CMC, *today's date* if still listed}
#'
#' @importFrom tibble as_tibble
#' @importFrom dplyr bind_rows mutate rename arrange distinct
#'
#' @examples
#' \dontrun{
#' # return all exchanges
#' ex_active_list <- exchange_list(only_active=TRUE)
#' ex_all_but_untracked_list <- exchange_list(only_active=FALSE)
#' ex_full_list <- exchange_list(only_active=FALSE,add_untracked=TRUE)
#' }
#'
#' @name exchange_list
#'
#' @export
#'
exchange_list <- function(only_active=TRUE, add_untracked=FALSE) {
  # get current coins
  path <- paste0("exchange/map")
  active_exchanges <- safeFromJSON(construct_url(path))
  exchanges <- active_exchanges$data %>% tibble::as_tibble() %>%
    dplyr::mutate(dplyr::across(c(first_historical_data,last_historical_data),as.Date))

  if (!only_active){
    path <- paste0("exchange/map?listing_status=inactive")
    inactive_exchanges <- safeFromJSON(construct_url(path))
    exchanges <- dplyr::bind_rows(exchanges,
                              inactive_exchanges$data %>% tibble::as_tibble() %>%
                                dplyr::mutate(dplyr::across(c(first_historical_data,last_historical_data),as.Date))) %>%
      dplyr::arrange(id)
  }
  if (add_untracked){
    path <- paste0("exchange/map?listing_status=untracked")
    untracked_exchanges <- safeFromJSON(construct_url(path))
    exchanges <- dplyr::bind_rows(exchanges,
                              untracked_exchanges$data %>% tibble::as_tibble() %>%
                                dplyr::mutate(dplyr::across(c(first_historical_data,last_historical_data),as.Date),is_active=-1)) %>%
      dplyr::arrange(id)
  }
  return(exchanges %>% dplyr::select(id:last_historical_data) %>% dplyr::distinct() %>% dplyr::arrange(id))
}
#' Retrieves list of all CMC supported fiat currencies available to convert cryptocurrencies
#'
#' This code retrieves data for all available fiat currencies that are available on the website.
#'
#' @param include_metals Shall the results include precious metals (TRUE) or not (FALSE=default).
#' Update: As of May 2024 no more metals are included in this file
#'
#' @return List of (active and historically existing) cryptocurrencies in a tibble:
#'   \item{id}{CMC id (unique identifier)}
#'   \item{symbol}{Coin symbol (not-unique)}
#'   \item{name}{Coin name}
#'   \item{sign}{Fiat currency sign}
#'
#' @importFrom tibble as_tibble
#'
#' @examples
#' \dontrun{
#' # return fiat currencies available through the CMC api
#' fiat_list <- fiat_list()
#' }
#'
#' @name fiat_list
#'
#' @export
#'
fiat_list <- function(include_metals=FALSE) {
  # get current coins
  if (!include_metals){
    fiat_url <- paste0("fiat/map")
    active_fiat <- safeFromJSON(construct_url(fiat_url))
    fiats <- active_fiat$data %>% tibble::as_tibble()
  } else {
    fiat_url <- paste0("fiat/map?include_metals=",include_metals)
    active_fiat <- safeFromJSON(construct_url(fiat_url))
    fiats <- active_fiat$data %>% tibble::as_tibble()
  }
  return(fiats)
}
