# Test with valid inputs and expected outputs
test_that("Valid parameters return correctly structured data for crypto_info()", {
  skip_on_cran()
  result <- crypto_info(limit = 2)

  # Check data structure
  expect_s3_class(result, "tbl_df")
  expect_true(all(c("id", "name", "symbol", "slug", "description", "logo") %in% names(result)))

  # Check specific content for a known coin
  bitcoin_info <- result %>% filter(name == "Bitcoin")
  expect_equal(nrow(bitcoin_info), 1)
  expect_true(!is.na(bitcoin_info$logo))
  expect_true(!is.na(bitcoin_info$description))
})

# Test downloaded data against earlier downloaded data
test_that("Downloaded data matches previously downloaded reference data for crypto_info()", {
  skip_on_cran()
  # coin_info <- crypto_info(limit = 2) |>  select(id,name,symbol,slug,category,date_added)
  # saveRDS(coin_info, "tests/testthat/test_data/crypto_info_reference.rds")
  # Assume you've saved reference data from a previous known good state
  expected_data <- readRDS("test_data/crypto_info_reference.rds")
  # expected_data <- readRDS("tests/testthat/test_data/crypto_info_reference.rds")

  # Get new data using the same parameters as when the reference was created
  new_data <- crypto_info(limit = 2)  |>  select(id,name,symbol,slug,category,date_added)

  # Compare the new data to the expected data
  expect_equal(new_data, expected_data, tolerance = 1e-8,
               info = "The newly downloaded data should match the reference dataset.")
})
# Test with valid inputs and expected outputs
test_that("Valid parameters return correctly structured data for exchange_info()", {
  skip_on_cran()
  result <- exchange_info(limit = 2)

  # Check data structure
  expect_s3_class(result, "tbl_df")
  expect_true(all(c("id", "name", "slug", "description", "logo") %in% names(result)))

  # Check specific content for a known coin
  poloniex_info <- result %>% filter(slug == "poloniex")
  expect_equal(nrow(poloniex_info), 1)
  expect_true(!is.na(poloniex_info$logo))
  expect_true(!is.na(poloniex_info$description))
})

# Test downloaded data against earlier downloaded data
test_that("Downloaded data matches previously downloaded reference data for exchange_info()", {
  skip_on_cran()
  # ex_info <- exchange_info(limit = 2)
  # saveRDS(ex_info, file = "tests/testthat/test_data/ex_info_reference.rds")
  # Assume you've saved reference data from a previous known good state
  expected_data <- readRDS("test_data/ex_info_reference.rds")
  # expected_data <- readRDS("tests/testthat/test_data/ex_info_reference.rds")

  # Get new data using the same parameters as when the reference was created
  new_data <- exchange_info(limit = 2)

  # Compare the new data to the expected data
  expect_equal(new_data, expected_data, tolerance = 1e-8,
               info = "The newly downloaded data should match the reference dataset.")
})

