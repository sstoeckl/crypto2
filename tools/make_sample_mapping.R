## Generate inst/extdata/cg_id_mapping_sample.parquet (top 20 reference coins).
## Not part of the package -- this lives under tools/ so the bundled sample can
## be regenerated when the schema or representative coins change. Run with
##   Rscript tools/make_sample_mapping.R
suppressPackageStartupMessages({
  library(arrow)
  library(tibble)
})

sample <- tibble::tibble(
  id     = c(1L, 279L, 825L, 1027L, 5176L, 5805L, 4128L, 1839L, 7083L, 7129L,
             4943L, 11939L, 1958L, 7186L, 6636L, 3408L, 2010L, 5994L, 13502L, 4687L),
  slug   = c("bitcoin","ethereum","tether","binancecoin","solana","ripple",
             "dogecoin","cardano","tron","avalanche-2","chainlink","stellar",
             "litecoin","polkadot","wrapped-bitcoin","usd-coin","monero",
             "ethereum-classic","matic-network","near"),
  symbol = c("btc","eth","usdt","bnb","sol","xrp","doge","ada","trx","avax",
             "link","xlm","ltc","dot","wbtc","usdc","xmr","etc","pol","near"),
  name   = c("Bitcoin","Ethereum","Tether","BNB","Solana","XRP","Dogecoin",
             "Cardano","TRON","Avalanche","Chainlink","Stellar","Litecoin",
             "Polkadot","Wrapped Bitcoin","USDC","Monero","Ethereum Classic",
             "Polygon","NEAR"),
  harvested_at = as.Date("2026-05-13")
)

dest <- "inst/extdata/cg_id_mapping_sample.parquet"
dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
arrow::write_parquet(sample, dest)
cat("Wrote", nrow(sample), "rows to", dest, "\n")
