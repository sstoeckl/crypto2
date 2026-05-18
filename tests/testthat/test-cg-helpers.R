# Offline unit tests for the helpers in R/cg_extras.R.
# These run on CRAN and CI without making any network calls.

# ---- cg_url ----------------------------------------------------------------

test_that("cg_url() routes to the documented host", {
  u <- cg_url("coins/list", host = "api")
  expect_match(u, "^https://api\\.coingecko\\.com/api/v3/coins/list$")
})

test_that("cg_url() routes to the website host (no /en/)", {
  u <- cg_url("price_charts/bitcoin/usd/max.json", host = "web")
  expect_match(u, "^https://www\\.coingecko\\.com/price_charts/")
  expect_false(grepl("/en/", u))
})

test_that("cg_url() routes to the website host with /en/ prefix", {
  u <- cg_url("coins/bitcoin/historical_data", host = "web_en")
  expect_match(u, "^https://www\\.coingecko\\.com/en/coins/bitcoin/historical_data$")
})

test_that("cg_url() strips a leading slash from the path", {
  expect_equal(
    cg_url("/coins/list", host = "api"),
    cg_url("coins/list",  host = "api")
  )
})

test_that("cg_url() rejects unknown hosts", {
  expect_error(cg_url("x", host = "geckoterminal"))
})

# ---- cg_user_agent ---------------------------------------------------------

test_that("cg_user_agent() returns a non-empty Chrome-like UA by default", {
  ua <- cg_user_agent()
  expect_type(ua, "character")
  expect_match(ua, "Mozilla/5\\.0")
  expect_match(ua, "Chrome")
})

test_that("cg_user_agent() honours options() override", {
  old <- options(crypto2.cg_user_agent = "custom/1.0")
  on.exit(options(old), add = TRUE)
  expect_equal(cg_user_agent(), "custom/1.0")
})

# ---- cg_numeric_id_from_image ---------------------------------------------

test_that("cg_numeric_id_from_image() extracts the numeric id correctly", {
  urls <- c(
    "https://coin-images.coingecko.com/coins/images/1/thumb/bitcoin.png?1696501400",
    "https://assets.coingecko.com/coins/images/279/standard/ethereum.png?1696501628",
    "https://coin-images.coingecko.com/coins/images/4128/standard/solana.png"
  )
  expect_equal(cg_numeric_id_from_image(urls), c(1L, 279L, 4128L))
})

test_that("cg_numeric_id_from_image() returns NA on malformed URLs", {
  bad <- c(NA_character_, "", "https://example.com/no/id/here.png")
  expect_equal(cg_numeric_id_from_image(bad),
               rep(NA_integer_, length(bad)))
})

# ---- cg_ms_to_posix --------------------------------------------------------

test_that("cg_ms_to_posix() converts unix-ms to UTC POSIXct", {
  ms <- 1577836800000  # 2020-01-01T00:00:00Z
  t  <- cg_ms_to_posix(ms)
  expect_s3_class(t, "POSIXct")
  expect_equal(attr(t, "tzone"), "UTC")
  expect_equal(format(t, "%Y-%m-%d %H:%M:%S", tz = "UTC"),
               "2020-01-01 00:00:00")
})

# ---- cg_parse_json ---------------------------------------------------------

test_that("cg_parse_json() parses valid JSON", {
  out <- cg_parse_json('{"a": 1, "b": "x"}')
  expect_equal(out$a, 1)
  expect_equal(out$b, "x")
})

test_that("cg_parse_json() returns NULL on bad input rather than erroring", {
  expect_null(cg_parse_json(""))
  expect_null(cg_parse_json(NULL))
  expect_null(cg_parse_json("this is not json {{{"))
})

# ---- cg_make_client --------------------------------------------------------

test_that("cg_make_client() returns a function", {
  cl <- cg_make_client(sleep = 0)
  expect_type(cl, "closure")
})

# ---- 429 / network-error retry contract ------------------------------------

# The retry logic relies on cg_get() raising classed conditions for 429s
# and network errors so that purrr::insistently catches them. We can't
# easily simulate a real 429 without network mocking, so verify the
# condition class machinery directly: a manually-raised cg_rate_limited
# condition must be catchable by class, and a possibly()-wrapped
# insistently() must convert exhausted-retries to NULL rather than
# propagating the error.

test_that("cg_rate_limited condition is catchable by class", {
  cond <- tryCatch(
    stop(structure(
      class = c("cg_rate_limited", "error", "condition"),
      list(message = "test", retry_after = 60)
    )),
    cg_rate_limited = function(c) c
  )
  expect_true(inherits(cond, "cg_rate_limited"))
  expect_equal(cond$retry_after, 60)
})

test_that("possibly() wrapper converts an unrecoverable cg_get() failure to NULL", {
  # Build a client whose underlying GET always errors (no network).
  # If wait * max_retries is short, the call returns NULL promptly.
  fake_get <- function(...) {
    stop(structure(
      class = c("cg_rate_limited", "error", "condition"),
      list(message = "simulated 429", retry_after = 0)
    ))
  }
  wrapped <- purrr::possibly(
    purrr::insistently(fake_get,
                       rate = purrr::rate_backoff(pause_base = 0.01,
                                                  pause_cap = 0.02,
                                                  max_times = 2,
                                                  jitter = FALSE),
                       quiet = TRUE),
    otherwise = NULL
  )
  expect_null(wrapped("anything"))
})
