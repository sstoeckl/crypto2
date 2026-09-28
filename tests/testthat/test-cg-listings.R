# cg_listings(): field completeness, retry and failure semantics.
# The first block runs offline against a mocked cg_get(); the last test
# hits the live API.

cg_fake_page <- function(n, offset = 0L) {
  coins <- lapply(seq_len(n) + offset, function(i) list(
    id = paste0("coin-", i), symbol = paste0("c", i), name = paste("Coin", i),
    image = sprintf("https://coin-images.coingecko.com/coins/images/%d/large/x.png", i),
    current_price = 100 + i, market_cap = 1e9 / i, market_cap_rank = i,
    fully_diluted_valuation = 2e9 / i, total_volume = 1e7 / i,
    high_24h = 110 + i, low_24h = 90 + i, price_change_24h = 1.5,
    price_change_percentage_24h = 1.2, market_cap_change_24h = 1e6,
    market_cap_change_percentage_24h = 0.8, circulating_supply = 1e6,
    total_supply = 2e6, max_supply = NULL, ath = 500, ath_change_percentage = -60,
    ath_date = "2021-11-10T14:24:11.849Z", atl = 1, atl_change_percentage = 9000,
    atl_date = "2015-10-20T00:00:00.000Z",
    roi = if (i == 1L) list(times = 42.5, currency = "usd", percentage = 4250) else NULL,
    last_updated = "2026-09-28T10:15:30.123Z",
    price_change_percentage_1h_in_currency = 0.1,
    price_change_percentage_24h_in_currency = 1.2,
    price_change_percentage_7d_in_currency = -3.4
  ))
  as.character(jsonlite::toJSON(coins, auto_unbox = TRUE, null = "null", digits = NA))
}

cg_rate_limited_error <- function() {
  stop(structure(
    class = c("cg_rate_limited", "error", "condition"),
    list(message = "simulated 429", call = NULL, retry_after = 0)
  ))
}

local_fast_cg <- function(env = parent.frame()) {
  withr::local_options(crypto2.cg_sleep = 0, crypto2.cg_max_retries = 2,
                       .local_envir = env)
}

test_that("cg_listings() returns price, volume and all /coins/markets fields", {
  local_fast_cg()
  local_mocked_bindings(cg_get = function(url, query = NULL, ...) {
    if (query$page == 1L) cg_fake_page(3) else "[]"
  })
  out <- cg_listings(wait = 0.01)

  expect_equal(nrow(out), 3L)
  expect_equal(out$price, c(101, 102, 103))
  expect_equal(out$volume_24h, 1e7 / 1:3)
  expect_equal(out$id, 1:3)
  for (col in c("high_24h", "low_24h", "price_change_24h",
                "market_cap_change_24h", "market_cap_change_percentage_24h",
                "ath", "ath_date", "atl", "atl_date",
                "roi_times", "roi_currency", "roi_percentage")) {
    expect_true(col %in% names(out), info = col)
  }
  expect_false("image" %in% names(out))
  expect_equal(out$roi_times, c(42.5, NA, NA))
  expect_equal(out$roi_currency, c("usd", NA, NA))
  for (col in c("last_updated", "ath_date", "atl_date")) {
    expect_s3_class(out[[col]], "POSIXct")
    expect_equal(attr(out[[col]], "tzone"), "UTC")
  }
  expect_equal(format(out$ath_date[1], "%Y-%m-%d %H:%M:%S"), "2021-11-10 14:24:11")
})

test_that("cg_listings(quote = FALSE) drops the quote columns", {
  local_fast_cg()
  local_mocked_bindings(cg_get = function(url, query = NULL, ...) cg_fake_page(2))
  out <- cg_listings(quote = FALSE, wait = 0.01)
  expect_false("price" %in% names(out))
  expect_true("market_cap" %in% names(out))
})

test_that("a simulated 429 is retried instead of returning an empty result", {
  local_fast_cg()
  calls <- 0L
  local_mocked_bindings(cg_get = function(url, query = NULL, ...) {
    calls <<- calls + 1L
    if (calls == 1L) cg_rate_limited_error()
    if (query$page == 1L) cg_fake_page(250) else cg_fake_page(10, offset = 250L)
  })
  expect_no_warning(out <- cg_listings(wait = 0.01))
  expect_equal(nrow(out), 260L)
  expect_equal(calls, 3L)
})

test_that("a page that keeps failing produces a warning naming the page", {
  local_fast_cg()
  local_mocked_bindings(cg_get = function(url, query = NULL, ...) {
    if (query$page == 1L) cg_fake_page(250) else cg_rate_limited_error()
  })
  expect_warning(out <- cg_listings(wait = 0.01),
                 "page 2 of /coins/markets failed.*INCOMPLETE")
  expect_equal(nrow(out), 250L)
})

test_that("transient 5xx responses are retryable, 500 is not", {
  resp_503 <- structure(list(status_code = 503L, headers = list()), class = "response")
  resp_500 <- structure(list(status_code = 500L, headers = list()), class = "response")
  local_mocked_bindings(GET = function(...) resp_503, .package = "httr")
  expect_error(cg_get(cg_url("ping", host = "api")), class = "cg_server_error")
  local_mocked_bindings(GET = function(...) resp_500, .package = "httr")
  expect_null(cg_get(cg_url("ping", host = "api")))
})

test_that("CG_DEMO_KEY is sent as a header to the API host only", {
  withr::local_envvar(CG_DEMO_KEY = "")
  expect_length(cg_demo_key_header(cg_url("coins/markets", host = "api")), 0L)

  withr::local_envvar(CG_DEMO_KEY = "CG-test")
  expect_equal(cg_demo_key_header(cg_url("coins/markets", host = "api")),
               c(`x-cg-demo-api-key` = "CG-test"))
  expect_length(cg_demo_key_header(cg_url("price_charts/bitcoin/usd/max.json",
                                          host = "web")), 0L)
})

test_that("live: cg_listings() top 100 all carry a price and a volume", {
  skip_if_no_cg()
  skip_if_cg_rate_limited()
  cg_pace(3)
  out <- cg_listings(limit = 100)
  skip_if(!nrow(out), "cg_listings returned no data (likely rate-limited).")
  expect_equal(nrow(out), 100L)
  expect_false(anyNA(out$price))
  expect_false(anyNA(out$volume_24h))
  expect_true(all(out$price > 0))
})
