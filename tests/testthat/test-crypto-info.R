# Test with valid inputs and expected outputs
test_that("Valid parameters return correctly structured data for crypto_info()", {
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
  coin_info <- crypto_info(limit = 2)
  saveRDS(coin_info, "test_data/crypto_info_reference.rds")
  # Assume you've saved reference data from a previous known good state
  expected_data <- readRDS("test_data/crypto_info_reference.rds")

  # Get new data using the same parameters as when the reference was created
  new_data <- crypto_info(limit = 2)

  # Compare the new data to the expected data
  expect_equal(new_data, expected_data, tolerance = 1e-8,
               info = "The newly downloaded data should match the reference dataset.")
})
# Test with valid inputs and expected outputs
test_that("Valid parameters return correctly structured data for exchange_info()", {
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
test_that("Downloaded data matches previously downloaded reference data for exchange_info()", {
  coin_info <- crypto_info(limit = 2)
  saveRDS(coin_info, "test_data/crypto_info_reference.rds")
  # Assume you've saved reference data from a previous known good state
  expected_data <- readRDS("test_data/crypto_info_reference.rds")

  # Get new data using the same parameters as when the reference was created
  new_data <- crypto_info(limit = 2)

  # Compare the new data to the expected data
  expect_equal(new_data, expected_data, tolerance = 1e-8,
               info = "The newly downloaded data should match the reference dataset.")
})
# Test with valid inputs and expected outputs
test_that("Valid parameters return correctly structured data", {
  result <- exchange_info(limit = 2)

  # Check data structure
  expect_s3_class(result, "tbl_df")
  expect_true(all(c("id", "name", "slug", "description", "logo") %in% names(result)))

  # Check specific content for a known coin
  exchange_info <- result %>% filter(name == "Poloniex")
  expect_equal(nrow(exchange_info), 1)
  expect_true(!is.na(exchange_info$logo))
  expect_true(!is.na(exchange_info$description))
})

# Test downloaded data against earlier downloaded data
test_that("Downloaded data matches previously downloaded reference data", {
  # ex_info <- exchange_info(limit = 2)
  # saveRDS(ex_info, "test_data/exchange_info_reference.rds")
  # Assume you've saved reference data from a previous known good state
  expected_data <- readRDS("test_data/exchange_info_reference.rds")

  # Get new data using the same parameters as when the reference was created
  new_data <- exchange_info(limit = 2)

  # Compare the new data to the expected data
  expect_equal(new_data, expected_data, tolerance = 1e-8,
               info = "The newly downloaded data should match the reference dataset.")
})

