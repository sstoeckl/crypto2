# Retrieves name, CG id, symbol, slug, rank, and quote data for current listings (CoinGecko)

Companion to
[`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md)
but for CoinGecko. Returns one row per coin with current
price/volume/market-cap fields plus percent-change windows. Column names
mirror those of
[`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md)
so downstream code that already consumes a CMC listings tibble works on
this tibble too.

## Usage

``` r
cg_listings(
  which = "latest",
  convert = "USD",
  limit = 5000,
  start_date = NULL,
  end_date = NULL,
  interval = "day",
  quote = FALSE,
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

  integer Return the top n records (default `5000` – matches
  [`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md)).

- start_date, end_date, interval:

  Kept for API parity with
  [`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md)
  – ignored for CoinGecko (no historical-listings endpoint on the free
  tier).

- quote:

  logical Kept for API parity. The CoinGecko `/coins/markets` endpoint
  always returns prices, so quote fields are always present; setting
  this to `FALSE` drops them from the returned tibble for parity with
  [`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md).

- sort, sort_dir:

  Kept for parity. CoinGecko sorts by `market_cap_desc` on the
  underlying endpoint; the arguments are ignored.

- sleep:

  integer (default `0`) Seconds to sleep between API requests. Will be
  raised to at least `2.5` internally to stay under the Demo-tier 30
  req/min cap.

- wait:

  Seconds to wait before retrying after a 429 (default `60`).

- finalWait:

  Sleep 60s after the last call (mirrors
  [`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md)).

## Value

Tibble with columns matching
[`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md)
where the corresponding CoinGecko field exists. See
[`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md)
for the column glossary; CoinGecko-specific extras (e.g. `ath`, `atl`)
are appended at the end.

## Details

CoinGecko free-tier limitations: only `which = "latest"` is supported.
`which = "historical"` and `which = "new"` produce a warning and are
coerced to `"latest"`, because CoinGecko's free tier does not expose the
historical cross-section. Snapshot this function periodically (daily /
weekly via a cron job) to accumulate a survivorship-bias-corrected
archive over time.

## Examples

``` r
if (FALSE) { # \dontrun{
# Full current snapshot (all coins with a market cap)
latest <- cg_listings(which = "latest", quote = TRUE)

# Top 1000 in BTC
latest_btc <- cg_listings(which = "latest", convert = "BTC", limit = 1000)
} # }
```
