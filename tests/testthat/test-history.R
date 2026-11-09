# Test with valid inputs and expected outputs
test_that("Valid parameters return correctly structured data", {
  skip_on_cran()
  result <- crypto_history(convert = "USD", limit = 1,
                           start_date = "2020-01-01", end_date = "2020-01-07", interval = "1d")

  # Check data structure
  expect_s3_class(result, "tbl_df")
  expect_true(all(c("id", "name", "symbol", "open", "high", "low", "close", "volume", "market_cap") %in% names(result)))

  # Check data content related to input parameters
  expect_equal(nrow(result), 7)  # Expecting 7 days of data
  expect_equal(min(as.Date(result$timestamp)), as.Date("2020-01-01"))
  expect_equal(max(as.Date(result$timestamp)), as.Date("2020-01-07"))
})

# Test handling of unsupported currencies
test_that("Unsupported currencies are rejected", {
  skip_on_cran()
  expect_error(crypto_history(convert = "EUR"),
               "convert must be one of the available currencies")
})

test_that("Downloaded data matches previously downloaded reference data", {
  skip_on_cran()
  # Load the expected output
  # saved_output <- crypto_history(
  # convert="USD",
  # limit=1,
  # start_date="2020-01-01",
  # end_date="2020-01-07",
  # interval="daily")
  expected_dir <- "test_data"
  # expected_dir <- paste0(getwd(),"/tests/testthat/test_data")
  # saveRDS(saved_output, paste0(expected_dir, "/crypto_history_reference.rds"))
  # # Load the reference data
  # saveRDS(saved_output, paste0(expected_dir,"/historical_output.rds"))
  # expected_output <- readRDS("test_data/historical_output.rds")
  expected_data <- readRDS(paste0(expected_dir,"/crypto_history_reference.rds"))

  # Get new data using the same parameters
  new_data <- crypto_history(convert = "USD", limit = 1,
                             start_date = "2020-01-01", end_date = "2020-01-07", interval = "daily")

  # Compare the new data to the expected data
  expect_equal(new_data |>  select(!contains("time")), expected_data |>  select(!contains("time")), tolerance = 1e-8,
               info = "The newly downloaded data should match the reference dataset.")
})

# ---- request windows and holes (offline) -----------------------------------

# Mimics CMC's historical endpoint: the 400 hourly points up to `timeEnd`
# (`timeStart` is ignored). If one of them is missing it returns nothing, or
# with `partial = TRUE` only the points before the missing one.
# The point at `mislabel` carries the time of the point before it and is
# listed first.
fake_cmc <- function(first, missing = numeric(), mislabel = numeric(), partial = FALSE) {
  seen <- new.env()
  seen$n <- 0
  fn <- function(url, ...) {
    seen$n <- seen$n + 1
    end <- as.numeric(sub(".*[?&]timeEnd=([0-9]+).*", "\\1", url))
    opens <- floor(end / 3600) * 3600 - (399:0) * 3600
    opens <- opens[opens >= first]
    if (any(opens %in% missing)) opens <- if (partial) opens[opens < min(opens[opens %in% missing])] else numeric()
    if (!length(opens)) return(list(data = list(quotes = list())))
    iso <- function(x) format(as.POSIXct(x, origin = "1970-01-01", tz = "UTC"), "%Y-%m-%dT%H:%M:%S.000Z")
    quotes <- data.frame(timeOpen = iso(opens), timeClose = iso(opens + 3599),
                         timeHigh = iso(opens + 60), timeLow = iso(opens + 120))
    quotes$quote <- data.frame(name = "2781", open = opens, high = opens, low = opens,
                               close = opens, volume = 1, marketCap = 1,
                               timestamp = iso(opens + 3599))
    m <- which(opens %in% mislabel)
    if (length(m)) {
      quotes[m, c("timeOpen", "timeHigh", "timeLow")] <- quotes[m - 1, c("timeOpen", "timeHigh", "timeLow")]
      quotes$timeClose[m] <- quotes$timeClose[m - 1]
      quotes$quote$timestamp[m] <- quotes$quote$timestamp[m - 1]
      quotes <- quotes[c(m, setdiff(seq_along(opens), m)), ]
    }
    list(data = list(id = 1831L, name = "Bitcoin Cash", symbol = "BCH", quotes = quotes))
  }
  list(fn = fn, seen = seen)
}
bch <- tibble::tibble(id = 1831L, slug = "bitcoin-cash", name = "Bitcoin Cash", symbol = "BCH")
utc <- function(x) as.numeric(as.POSIXct(x, tz = "UTC"))

test_that("hourly requests neither overlap nor leave gaps", {
  withr::local_timezone("UTC")
  cmc <- fake_cmc(first = utc("2019-01-01"))
  local_mocked_bindings(safeFromJSON = cmc$fn)
  for (rl in c(400, 150)) {
    h <- crypto_history(bch, start_date = "2020-01-01", end_date = "2020-03-31",
                        interval = "1h", requestLimit = rl)
    expect_equal(nrow(h), 91 * 24)
    expect_equal(anyDuplicated(as.POSIXct(h$timestamp)), 0L)
    expect_null(attr(h, "gaps"))
  }
})

test_that("the data around a hole in CMC's data are recovered and the hole reported", {
  withr::local_timezone("UTC")
  for (partial in c(FALSE, TRUE)) {
    cmc <- fake_cmc(first = utc("2019-01-01"), missing = utc("2020-02-12 00:00"), partial = partial)
    local_mocked_bindings(safeFromJSON = cmc$fn)
    expect_warning(
      h <- crypto_history(bch, start_date = "2020-01-01", end_date = "2020-03-31", interval = "1h"),
      "bitcoin-cash 2020-02-12 00:00 UTC")
    expect_equal(nrow(h), 91 * 24 - 1)
    expect_equal(anyDuplicated(as.POSIXct(h$timestamp)), 0L)
    expect_equal(attr(h, "gaps")$from, as.POSIXct("2020-02-12", tz = "UTC"))
    expect_equal(attr(h, "gaps")$to, as.POSIXct("2020-02-12", tz = "UTC"))
  }
})

test_that("a point labelled with the time before it is moved to its own time", {
  withr::local_timezone("UTC")
  cmc <- fake_cmc(first = utc("2019-01-01"), mislabel = utc("2020-02-12 01:00"))
  local_mocked_bindings(safeFromJSON = cmc$fn)
  h <- crypto_history(bch, start_date = "2020-01-01", end_date = "2020-03-31", interval = "1h")
  expect_equal(nrow(h), 91 * 24)
  expect_equal(anyDuplicated(as.POSIXct(h$timestamp)), 0L)
  expect_null(attr(h, "gaps"))
  open <- as.POSIXct(h$time_open, tz = "UTC")
  for (x in c("2020-02-12 00:00", "2020-02-12 01:00")) {
    expect_equal(h$close[open == as.POSIXct(x, tz = "UTC")], utc(x))
  }
})

test_that("a coin listed after start_date costs no extra requests", {
  withr::local_timezone("UTC")
  cmc <- fake_cmc(first = utc("2020-02-10 05:00"))
  local_mocked_bindings(safeFromJSON = cmc$fn)
  h <- crypto_history(bch, start_date = "2020-01-01", end_date = "2020-03-31", interval = "1h")
  expect_equal(min(as.POSIXct(h$time_open, tz = "UTC")), as.POSIXct("2020-02-10 05:00", tz = "UTC"))
  expect_equal(cmc$seen$n, 6)
  expect_null(attr(h, "gaps"))
})

test_that("hourly history bridges CMC's missing hour of 2020-02-12 (live)", {
  skip_on_cran()
  skip_if_offline()
  withr::local_timezone("UTC")
  expect_warning(
    h <- crypto_history(bch, start_date = "2020-02-01", end_date = "2020-02-29", interval = "1h"),
    "2020-02-12 00:00 UTC")
  expect_equal(nrow(h), 29 * 24 - 1)
  expect_equal(anyDuplicated(as.POSIXct(h$timestamp)), 0L)
})

test_that("CMC's mislabelled hour of 2022-10-01 01:00 is moved to its own time (live)", {
  skip_on_cran()
  skip_if_offline()
  withr::local_timezone("UTC")
  h <- crypto_history(bch, start_date = "2022-09-30", end_date = "2022-10-01", interval = "1h")
  expect_equal(nrow(h), 48)
  expect_equal(anyDuplicated(as.POSIXct(h$timestamp)), 0L)
  expect_null(attr(h, "gaps"))
})
