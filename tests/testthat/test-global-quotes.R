# Test with valid inputs
test_that("Valid inputs return correct data structure", {
  skip_on_cran()
  result <- crypto_global_quotes(which="latest", convert="USD", quote=TRUE)
  expect_s3_class(result, "tbl_df")
  expect_true("btc_dominance" %in% names(result))
  expect_true("eth_dominance" %in% names(result))
})

# Test response to invalid 'convert' parameters
test_that("Invalid 'convert' parameters are handled", {
  skip_on_cran()
  expect_error(crypto_global_quotes(which="latest", convert="INVALID_CURRENCY"), "convert must be one of the available currencies")
})

test_that("Historical data matches expected output", {
  skip_on_cran()
  # Load the expected output
  # saved_output <- crypto_global_quotes(
  # which="historical",
  # convert="USD",
  # start_date="20200101",
  # end_date="20200107",
  # interval="daily",
  # quote=TRUE)
  # saveRDS(saved_output, "tests/testthat/test_data/historical_output.rds")
  expected_output <- readRDS("test_data/historical_output.rds")

  # Run the function again with the same parameters
  current_output <- crypto_global_quotes(
    which="historical",
    convert="USD",
    start_date="20200101",
    end_date="20200107",
    interval="daily",
    quote=TRUE
  )

  # Use expect_equal to compare data frames/tibbles
  expect_equal(current_output, expected_output,
               info = "The output of crypto_global_quotes should match the historical data.")
})
