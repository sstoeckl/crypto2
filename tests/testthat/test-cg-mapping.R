# Offline-safe tests for cg_id_mapping() and the bundled fallback.
# These tests do NOT hit the network: cg_id_mapping() falls back to the
# bundled inst/extdata/cg_id_mapping_sample.parquet when the cache is
# absent and the network is unreachable.

test_that("bundled cg_id_mapping_sample.parquet has the expected schema", {
  skip_if_not_installed("arrow")
  bundled <- system.file("extdata", "cg_id_mapping_sample.parquet",
                         package = "crypto2")
  skip_if(!nzchar(bundled), "bundled sample not installed")

  out <- tibble::as_tibble(arrow::read_parquet(bundled))
  expect_setequal(
    names(out),
    c("id", "slug", "symbol", "name", "harvested_at")
  )
  expect_true(nrow(out) > 0L)
  # canonical anchors
  expect_true("bitcoin"  %in% out$slug)
  expect_true("ethereum" %in% out$slug)
})

test_that("cg_id_mapping() returns the bundled sample when the cache is primed from it", {
  skip_if_not_installed("arrow")
  cache <- file.path(tempdir(), "crypto2_cg_mapping.parquet")
  if (file.exists(cache)) file.remove(cache)
  bundled <- system.file("extdata", "cg_id_mapping_sample.parquet",
                         package = "crypto2")
  skip_if(!nzchar(bundled), "bundled sample not installed")
  file.copy(bundled, cache, overwrite = TRUE)

  # refresh = FALSE -> reads cache directly without touching the network
  out <- suppressMessages(cg_id_mapping(refresh = FALSE, quiet = TRUE))
  expect_s3_class(out, "tbl_df")
  expect_setequal(
    names(out),
    c("id", "slug", "symbol", "name", "harvested_at")
  )
  expect_type(out$id, "integer")
  expect_s3_class(out$harvested_at, "Date")
  expect_true(nrow(out) > 0L)
  expect_true("bitcoin"  %in% out$slug)
  expect_true("ethereum" %in% out$slug)
})

