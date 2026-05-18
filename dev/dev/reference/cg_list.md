# Retrieve the CoinGecko coin universe (active coins only)

Companion to
[`crypto_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_list.md)
but for CoinGecko. Returns the active universe as a tibble using the
same column conventions as
[`crypto_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_list.md),
so downstream code that consumes a CMC coin list also consumes this one.

## Usage

``` r
cg_list(
  only_active = TRUE,
  add_untracked = FALSE,
  top_n = NULL,
  sleep = 2.5,
  wait = 60,
  max_retries = 3,
  vs_currency = "usd"
)
```

## Arguments

- only_active:

  Always `TRUE` for CoinGecko free-tier (kept for API parity with
  [`crypto_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_list.md)).
  The argument is ignored with a warning if set to `FALSE`.

- add_untracked:

  Same – ignored on CoinGecko free-tier. Kept for parity.

- top_n:

  If non-NULL, only enrich the top `top_n` coins by market cap with
  `rank` and `numeric_id` (faster). Default `NULL` = enrich all coins
  that appear in `/coins/markets`.

- sleep:

  Seconds between consecutive `/coins/markets` page calls (default `2.5`
  -\> 24 req/min, ~80% of the Demo-tier 30 req/min cap, leaving headroom
  for CoinGecko's sliding-window enforcement).

- wait:

  Seconds to wait before retrying after an HTTP 429 / network error
  (default `60`, matching CoinGecko's rate-limit window).

- max_retries:

  Maximum number of retry attempts on rate-limit / network failures
  (default `3`).

- vs_currency:

  Quote currency for the market snapshot, default `"usd"`.

## Value

Tibble with one row per coin currently tracked by CoinGecko. Columns
mirror
[`crypto_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_list.md):

- id:

  CoinGecko internal numeric id (extracted from the image URL). May be
  `NA` for coins outside the top `top_n`.

- name:

  Coin name.

- symbol:

  Coin symbol (lower-case, non-unique).

- slug:

  CoinGecko URL slug (unique, also the `id` in CoinGecko's documented
  API).

- rank:

  Current market-cap rank, `NA` for coins outside the top `top_n` or
  without a market cap.

- is_active:

  Always `1L` on CoinGecko free-tier.

- first_historical_data:

  `NA_Date_` – not exposed by the free tier. Backfill via
  [`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md)
  if needed.

- last_historical_data:

  Today's date, in line with
  [`crypto_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_list.md)'s
  convention for active coins.

## Details

Important caveat – survivorship bias: CoinGecko actively prunes delisted
and inactive coins from its public database. The free-tier API only
returns coins currently active on the platform. To build a
survivorship-bias-free dataset from CoinGecko, snapshot this list
**periodically** (daily/weekly, via an external cronjob or scheduling
package) so coins that get delisted later remain in your accumulated
archive.

Data sources (no API key required):

- `api.coingecko.com/api/v3/coins/list` – the full slug/symbol/name
  universe in a single HTTP call (free, key-less, but limited to active
  coins).

- `api.coingecko.com/api/v3/coins/markets?per_page=250&page=N` –
  paginated market snapshot, which provides `market_cap_rank` and the
  `image` URL from which the internal numeric ID is extracted.

## Examples

``` r
if (FALSE) { # \dontrun{
# Bootstrap: one HTTP call gets the entire universe
universe <- cg_list(top_n = 0)

# Enriched: pull universe + ranks + numeric IDs for the top 500
top500 <- cg_list(top_n = 500)
} # }
```
