# Fetch CoinGecko history by numeric ID (incl. partial survivorship-bias correction)

Companion to
[`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md)
that addresses coins by their internal **numeric ID** instead of their
slug. Useful in two scenarios:

## Usage

``` r
cg_history_by_id(
  ids = NULL,
  what = c("price", "market_cap", "ohlc"),
  vs_currency = "usd",
  start_date = NULL,
  end_date = NULL,
  coin_list = NULL,
  sleep = 0.6,
  wait = 60,
  max_retries = 3,
  quiet = FALSE,
  finalWait = FALSE
)
```

## Arguments

- ids:

  Integer vector of numeric IDs to fetch. Default `NULL` -\> uses
  `cg_list()$id` (active universe). To extend coverage to delisted
  coins, supply the union of historically-observed IDs from your
  accumulated snapshots.

- what:

  Subset of streams to fetch. Any combination of `"price"`,
  `"market_cap"`, and `"ohlc"`. Default all three.

- vs_currency:

  Quote currency, default `"usd"`.

- start_date, end_date:

  Client-side date filter applied after fetch. `NULL` returns full
  history.

- coin_list:

  Optional
  [`cg_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_list.md)
  output used to join `slug` / `name` / `symbol` onto recovered rows for
  coins still in the active universe. If `NULL`, calls
  [`cg_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_list.md)
  automatically. Set to `FALSE` to skip the join (rows then have only
  `id`).

- sleep, wait, max_retries:

  Passed to
  [`cg_make_client()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_make_client.md).
  Defaults `0.6 / 60 / 3` match
  [`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md).

- quiet:

  If `FALSE`, prints a progress bar.

- finalWait:

  Sleep 60 s after the last call (mirrors
  [`crypto_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_history.md)).

## Value

Tibble with one row per (id, date) using crypto2-compatible column
names. Columns:

- id:

  CoinGecko numeric id (always populated).

- slug, name, symbol:

  Coin identifiers – `NA` for ids no longer in the active universe (i.e.
  delisted on the slug side).

- timestamp:

  POSIXct UTC midnight of the trading day.

- ref_cur_id, ref_cur_name:

  Quote currency.

- open, high, low, close, volume, market_cap:

  Daily values.

## Details

1.  Coins that have been **delisted** from CoinGecko's slug routing
    (i.e., `api.coingecko.com/api/v3/coins/{slug}` now returns 404) but
    whose numeric ID still serves data on the website-host endpoints.
    This holds at least for low/early IDs.

2.  Cronjob-style accumulation: when you persist
    [`cg_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_list.md)
    snapshots over time, the **union of all numeric IDs ever observed**
    is the survivorship-bias-corrected universe. `cg_history_by_id()`
    lets you refetch each historical ID directly without needing its
    current slug to still resolve.

Important caveats – please read:

- **The numeric-ID space is sparse, not dense.** CoinGecko's
  auto-increment counter has been allocated up to ~102 million, but only
  ~15 000 IDs are actually populated as of mid 2026. **Blind iteration
  over `1:N` does NOT recover the full universe** – most numeric IDs in
  that range return 404. The default `ids = NULL` therefore uses the
  active universe from
  [`cg_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_list.md),
  NOT a numeric range. To recover delisted coins you must supply the IDs
  explicitly (e.g., the union of accumulated
  [`cg_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_list.md)
  snapshots).

- **Slug recovery for delisted coins is not available** through any
  free-tier endpoint. Active coins get their slug/name joined back in
  from
  [`cg_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_list.md);
  rows whose numeric ID is no longer in the active universe come back
  with `slug = NA` and `name = NA`. Use the `id` column as the join key
  in downstream code.

- **It is empirically true** that some low/early numeric IDs continue to
  serve historical data even when their slug has been removed from the
  public API. The exact coverage policy is undocumented and may change
  without notice.

## Examples

``` r
if (FALSE) { # \dontrun{
# Scan first 200 numeric IDs (will include both active and delisted coins)
h <- cg_history_by_id(ids = 1:200, what = c("price", "market_cap"))

# Full sweep -- survivorship-bias-free price history of the entire
# CoinGecko universe. Slow (10+ hours). Run via cronjob package.
h_all <- cg_history_by_id()
} # }
```
