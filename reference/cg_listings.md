# Retrieves name, CG id, symbol, slug, rank, and quote data for current listings (CoinGecko)

Companion to
[`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md)
but for CoinGecko. Returns one row per coin with every field of the
`/coins/markets` endpoint: price, volume, 24h range, price and
market-cap changes, all-time high/low and ROI. Column names mirror those
of
[`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md)
where a CMC counterpart exists, so downstream code that already consumes
a CMC listings tibble works on this tibble too.

## Usage

``` r
cg_listings(
  which = "latest",
  convert = "USD",
  limit = NULL,
  start_date = NULL,
  end_date = NULL,
  interval = "day",
  quote = TRUE,
  sort = "cmc_rank",
  sort_dir = "asc",
  sleep = 0,
  wait = 60,
  finalWait = FALSE
)
```

## Arguments

- which:

  Always `"latest"` for CoinGecko free-tier. Other values produce a
  warning and are coerced to `"latest"`.

- convert:

  string (default: `"USD"`). The value is lower-cased and passed to
  CoinGecko as `vs_currency`. Common values: `"USD"`, `"BTC"`, `"ETH"`,
  `"EUR"`, `"GBP"`.

- limit:

  integer Return the top n records. `NULL` (default) returns all coins.

- start_date, end_date, interval:

  Kept for API parity with
  [`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md)
  – ignored for CoinGecko (no historical-listings endpoint on the free
  tier).

- quote:

  logical (default `TRUE`). The `/coins/markets` endpoint always returns
  prices at no extra cost, so they are included by default. Set to
  `FALSE` to keep only the identifier, rank, market-cap and supply
  columns. Note that this default differs from
  [`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md).

- sort, sort_dir:

  Kept for parity. CoinGecko sorts by `market_cap_desc` on the
  underlying endpoint; the arguments are ignored.

- sleep:

  integer (default `0`) Seconds to sleep between API requests. Will be
  raised to at least `getOption("crypto2.cg_sleep", 2.5)` internally to
  stay under the Demo-tier 30 req/min cap.

- wait:

  Seconds to wait before retrying after a 429 (default `60`).

- finalWait:

  Sleep 60s after the last call (mirrors
  [`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md)).

## Value

Tibble with one row per coin. Always present: `id`, `name`, `symbol`,
`slug`, `date_added` (always `NA`), `last_updated` (POSIXct, UTC),
`rank`, `market_cap`, `fully_diluted_market_cap`, `circulating_supply`,
`total_supply`, `max_supply`. With `quote = TRUE` additionally
(CoinGecko field name in brackets):

- price:

  \[`current_price`\]

- volume_24h:

  \[`total_volume`\]

- high_24h, low_24h:

  24h price range

- price_change_24h:

  absolute 24h price change

- percent_change_1h, \_24h, \_7d, \_14d, \_30d, \_200d, \_1y:

  \[`price_change_percentage_<window>_in_currency`\]

- market_cap_change_24h, market_cap_change_percentage_24h:

  24h market-cap change, absolute and in percent

- ath, ath_change_percentage, ath_date:

  all-time high; date as POSIXct (UTC)

- atl, atl_change_percentage, atl_date:

  all-time low; date as POSIXct (UTC)

- roi_times, roi_currency, roi_percentage:

  flattened `roi` object (`NA` for most coins)

- ref_currency:

  upper-cased `convert`

## Details

CoinGecko free-tier limitations: only `which = "latest"` is supported.
`which = "historical"` and `which = "new"` produce a warning and are
coerced to `"latest"`, because CoinGecko's free tier does not expose the
historical cross-section. Snapshot this function periodically (daily /
weekly via a cron job) to accumulate a survivorship-bias-corrected
archive over time.

**Coverage.** `/coins/markets` no longer lists wrapped, staked or
bridged tokens (e.g. stETH, wstETH, WBTC, JitoSOL, bridged USDT). Their
history is still available through
[`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md)
(the `market_chart` endpoint), but they will not appear in a
`cg_listings()` snapshot.

**Rate limits and API key.** Without a key the public endpoint allows
only a handful of calls per minute. Set the environment variable
`CG_DEMO_KEY` to a (free) CoinGecko Demo-API key to raise this to 30
calls per minute (10,000 per month); it is sent as the
`x-cg-demo-api-key` header to the documented API host only. HTTP 429 and
transient 408/502/503/504 responses are retried with exponential backoff
(see `wait` and the `crypto2.cg_max_retries` option). If a page still
fails after the last retry, paging stops and a warning names the failed
page, so an incomplete result is never returned silently.

## Examples

``` r
if (FALSE) { # \dontrun{
# Full current snapshot (all coins with a market cap), including prices
latest <- cg_listings()

# Top 1000 in BTC, with a Demo-API key for the higher rate limit
Sys.setenv(CG_DEMO_KEY = "CG-...")
latest_btc <- cg_listings(convert = "BTC", limit = 1000)
} # }
```
