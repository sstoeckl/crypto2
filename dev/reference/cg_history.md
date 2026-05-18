# Retrieve historic CoinGecko market data (OHLC + volume + market cap)

Companion to
[`crypto_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_history.md)
but for CoinGecko, returning daily time-series data in a tibble whose
column names match crypto2's CMC output. Uses CoinGecko's **undocumented
website-host endpoints** (no API key required, no documented rate limit)
so it can be used for mass research backfills.

## Usage

``` r
cg_history(
  coin_list = NULL,
  convert = "USD",
  limit = NULL,
  start_date = NULL,
  end_date = NULL,
  interval = "daily",
  what = c("price", "market_cap", "ohlc"),
  sleep = 0.6,
  wait = 60,
  max_retries = 3,
  finalWait = FALSE
)
```

## Arguments

- coin_list:

  Tibble in the
  [`cg_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_list.md)
  /
  [`cg_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_listings.md)
  format (must contain at least `slug`; `id` recommended for OHLC). If
  `NULL`,
  [`cg_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_list.md)
  is called to fetch the active universe.

- convert:

  Quote currency, default `"USD"` (lower-cased before sending).

- limit:

  Optional cap on the number of coins to process (top of the tibble
  after sorting by `rank`).

- start_date, end_date:

  Filter the returned timeseries to this date window after fetching (the
  upstream endpoints always return full history in one call, so this is
  a client-side filter).

- interval:

  Always `"daily"` – CoinGecko's website endpoints return daily
  granularity for `max` periods. Hourly is not available without an API
  key.

- what:

  Subset of timeseries to fetch – character vector with any of
  `"price"`, `"market_cap"`, `"ohlc"`. Default
  `c("price","market_cap","ohlc")`. Drop `"ohlc"` if you don't need
  candles (saves one call per coin).

- sleep:

  Seconds between consecutive endpoint calls on the website host
  (default `0.6` -\> ~100 req/min, polite). Cloudflare may issue a 403
  challenge at higher rates from less reputable IPs.

- wait:

  Seconds to wait before retrying after a 429 / network error (default
  `60`). See
  [`cg_make_client()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_make_client.md).

- max_retries:

  Maximum retry attempts (default `3`). See
  [`cg_make_client()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_make_client.md).

- finalWait:

  Sleep 60s after the last call (mirrors
  [`crypto_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_history.md)).

## Value

Tibble with one row per (coin, date) using crypto2-compatible column
names:

- id:

  CoinGecko numeric id (NA if unknown).

- slug, name, symbol:

  Coin identifiers.

- timestamp:

  POSIXct (UTC), midnight of the trading day.

- ref_cur_id:

  CoinGecko quote currency code (e.g. `"usd"`).

- ref_cur_name:

  Upper-cased quote currency.

- open, high, low, close:

  Daily OHLC, `NA` if `"ohlc"` not requested or numeric id missing.
  `close` is back-filled from the price endpoint when OHLC is missing –
  the price-charts series records the last spot price of the day, which
  is a reasonable close proxy.

- volume:

  Daily total volume.

- market_cap:

  Daily market cap.

- time_open, time_high, time_low, time_close:

  `NA` – CoinGecko does not expose intra-day OHLC timestamps in these
  endpoints.

## Details

Per coin, up to three HTTP calls are made (each returning the coin's
**full** history in one response):

- `/price_charts/{slug}/{vs}/max.json`:

  price + total volume (daily)

- `/market_cap/{slug}/{vs}/max.json`:

  market cap (daily)

- `/ohlc/{numeric_id}/series/{vs}/max.json`:

  OHLC – daily where the period covers \>=91 days, 4-day candles for
  older history per CoinGecko's OHLC granularity policy. Sparse on short
  date windows.

The three series are joined on date. If a coin's numeric id is missing
(e.g. because the coin is outside the top market-cap pages enriched by
[`cg_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_list.md)),
OHLC will be `NA` for that coin but price/volume/mcap will still be
returned. Pass an explicit `coin_list` that already has a non-NA `id`
column to guarantee OHLC.

## Examples

``` r
if (FALSE) { # \dontrun{
# Pull full price+volume+market-cap+OHLC history for the top 50 coins.
top50 <- cg_list(top_n = 50)
hist  <- cg_history(coin_list = top50, what = c("price", "market_cap", "ohlc"))

# Faster: skip OHLC if you only need close+volume+mcap
hist_fast <- cg_history(coin_list = top50, what = c("price", "market_cap"))
} # }
```
