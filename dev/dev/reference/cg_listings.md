# Retrieve the latest CoinGecko market snapshot (CMC-compatible columns)

Companion to `crypto_listings(which = "latest", quote = TRUE)` but for
CoinGecko. Returns one row per coin with current price/volume/market-cap
fields plus percent-change windows. Column names mirror those of
[`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md)
so that downstream code that already consumes a CMC listings tibble
works on this tibble too.

## Usage

``` r
cg_listings(
  which = "latest",
  convert = "USD",
  limit = NULL,
  quote = TRUE,
  sleep = 2.5,
  wait = 60,
  max_retries = 3,
  ...
)
```

## Arguments

- which:

  Always `"latest"` for CoinGecko. Other values produce a warning and
  are coerced to `"latest"`.

- convert:

  Quote currency. Use `"USD"` (default) or `"BTC"`; the value is
  lower-cased and passed to CoinGecko as `vs_currency`.

- limit:

  Max number of coins to return (default `NULL` = all coins with a
  market cap; CoinGecko currently lists ~17 000).

- quote:

  Kept for API parity. Always treated as `TRUE` because the
  `/coins/markets` endpoint always returns prices.

- sleep:

  Seconds between page calls (default `2.5` -\> 24 req/min, ~80% of the
  Demo-tier 30 req/min cap, with headroom for CoinGecko's sliding-window
  enforcement).

- wait:

  Seconds to wait before retrying after a 429 (default `60`, matching
  CoinGecko's rate-limit window). See
  [`cg_make_client()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_make_client.md).

- max_retries:

  Maximum retry attempts on 429 / network failures (default `3`). See
  [`cg_make_client()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_make_client.md).

- ...:

  Other args (e.g. `sort`, `sort_dir`) ignored – kept for parity with
  [`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md).

## Value

Tibble with columns matching `crypto_listings(quote = TRUE)` where the
corresponding CoinGecko field exists. Mapping:

- id:

  CoinGecko internal numeric id (from image URL).

- name, symbol, slug:

  Coin identifiers (slug = CG's API id).

- date_added:

  `NA_Date_` – not available from `/coins/markets`. Pull via
  [`cg_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_info.md)
  for these.

- last_updated:

  Date of the last update reported by CoinGecko.

- rank:

  Market-cap rank (= CG `market_cap_rank`).

- market_cap, fully_diluted_market_cap:

- circulating_supply, total_supply, max_supply:

- price:

  Current price (= CG `current_price`).

- volume_24h:

  = CG `total_volume`.

- percent_change_1h, \_24h, \_7d, \_14d, \_30d, \_200d, \_1y:

  From the `price_change_percentage` parameter.

- high_24h, low_24h:

  Intra-day extremes.

- ath, ath_change_percentage, ath_date:

  All-time high info.

- atl, atl_change_percentage, atl_date:

  All-time low info.

- ref_currency:

  Quote currency, upper-cased to match CMC output.

## Details

Data sources (no API key required):

- `api.coingecko.com/api/v3/coins/markets?vs_currency=...&per_page=250&page=N`
  – paginated. The `price_change_percentage` query param is set to
  `"1h,24h,7d,14d,30d,200d,1y"` so all CMC-equivalent return windows are
  present.

CoinGecko free-tier limitations

- Snapshot only – `which = "historical"` is **not supported** because
  CoinGecko's free tier does not expose the historical cross-section of
  the universe. Use this function periodically (daily/weekly) and
  persist each snapshot yourself to accumulate a
  survivorship-bias-corrected archive over time.

- `which = "new"` is not supported (no CG equivalent endpoint).

## Examples

``` r
if (FALSE) { # \dontrun{
# Full current snapshot of all coins with a market cap
snap <- cg_listings()

# Top 1000 only, in BTC
snap_btc <- cg_listings(convert = "BTC", limit = 1000)
} # }
```
