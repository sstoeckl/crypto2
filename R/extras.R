#' URL Creator
#'
#' @param path A path to append to the base URL
#'
#' @return A full URL string
#' @keywords internal
#'
#' @importFrom base64enc base64decode
#'
construct_url <- function(path,v=1) {
  if (v==1){
    base <- rawToChar(base64enc::base64decode("aHR0cHM6Ly9hcGkuY29pbm1hcmtldGNhcC5jb20vZGF0YS1hcGkvdjEv"))
  } else if (v==3) {
    base <- rawToChar(base64enc::base64decode("aHR0cHM6Ly9hcGkuY29pbm1hcmtldGNhcC5jb20vZGF0YS1hcGkvdjMv"))
  } else if (v=="3.1") {
    base <- rawToChar(base64enc::base64decode("aHR0cHM6Ly9hcGkuY29pbm1hcmtldGNhcC5jb20vZGF0YS1hcGkvdjMuMS8="))
  }
  return(paste0(base, path))
}
#' Parses json data from a string without revealing information about the source in case of an error
#'
#' @param ...
#'
#' @return A parsed JSON object
#' @keywords internal
#'
#' @importFrom jsonlite fromJSON
#'
safeFromJSON <- function(...) {
  result <- withCallingHandlers(
    tryCatch({
      # Attempt to parse JSON with suppressed warnings and messages
      suppressWarnings(suppressMessages({
        jsonlite::fromJSON(...)
      }))
    }, error = function(e) {
      # Return a custom, simpler error object
      simpleError("Unfortunately, the scraper could not find data with the sent api-call. If you believe this is a bug please report at https://github.com/sstoeckl/crypto2/issues")
    }),
    warning = function(w) {
      # Intercept warnings and handle them silently
      invokeRestart("muffleWarning")
    }
  )
  # Check if result is an error and stop if it is
  if (inherits(result, "error")) {
    stop(result$message, call. = FALSE)
  }
  result
}
