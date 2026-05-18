# CoinGecko integration: a second source for crypto2

## Why a second source?

`crypto2` was built around CoinMarketCap (CMC). The `cg_*` functions are
a second, independent source: a CoinGecko-side counterpart with the
**same column conventions** as the CMC functions, so research code that
already consumes a `crypto_*` tibble works on a `cg_*` tibble too.
Triangulating across both is the cleanest insulation against either
platform changing its terms.

## Function pairs (CMC \<-\> CoinGecko)

| Purpose | CMC | CoinGecko | Same signature? |
|----|----|----|----|
| Coin universe | [`crypto_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_list.md) | [`cg_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_list.md) | yes |
| Current snapshot | [`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md) | [`cg_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_listings.md) | yes |
| Historical OHLC | [`crypto_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_history.md) | [`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md) | yes |
| Per-coin metadata | [`crypto_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_info.md) | [`cg_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_info.md) | yes |

The `cg_*` functions accept the **same arguments** as their `crypto_*`
counterparts. Arguments that have no CoinGecko equivalent (e.g.
`add_untracked`, `requestLimit`, `single_id`) are kept for parity and
silently ignored. Arguments where CoinGecko is more restrictive (e.g.
`which = "historical"` in
[`cg_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_listings.md))
emit a one-line warning and coerce to the supported mode.

## What the package handles for you

CoinGecko’s free tier has a couple of edges. The package routes around
them where possible and warns when it cannot:

1.  **Survivorship bias.** The free coin list only returns currently
    tracked coins. `cg_list(only_active = FALSE)` transparently extends
    the universe with a periodically-updated historic mapping and prints
    one line: *“Historic data retrieval is current until YYYY-MM-DD”*.
2.  **Daily price / volume / market-cap history is available in full** –
    back to each coin’s listing date in a single call, no key required.
    This is the workhorse path and the basis for almost all factor work.
3.  **OHLC (open / high / low) is capped at the most recent 365 days on
    the free tier.** Close prices over a longer window come from the
    price stream above; if you genuinely need long-horizon OHLC candles
    (for intra-day microstructure or candlestick-based signals), use the
    one-shot Pro recipes in
    [`vignette("coingecko-pro-backfill")`](https://www.sebastianstoeckl.com/crypto2/dev/articles/coingecko-pro-backfill.md).

## The four core functions

All four return tibbles with column names mirroring the `crypto_*`
counterparts.

### `cg_list()` – the active coin universe

``` r

universe       <- cg_list()                       # active coins only
universe_full  <- cg_list(only_active = FALSE)    # + historic mapping
head(universe)
#> # A tibble: 6 x 8
#>      id name      symbol slug      rank is_active first_historical_data last_historical_data
#>   <int> <chr>     <chr>  <chr>    <int>     <int> <date>                <date>
#> 1     1 Bitcoin   btc    bitcoin      1         1 NA                    2026-05-13
#> 2   279 Ethereum  eth    ethereum     2         1 NA                    2026-05-13
#> 3   825 Tether    usdt   tether       3         1 NA                    2026-05-13
```

### `cg_listings()` – current cross-sectional snapshot

``` r

snap <- cg_listings(which = "latest", quote = TRUE, limit = 1000)
```

`which = "historical"` and `which = "new"` are CMC-only – they warn and
coerce to `"latest"`. Snapshot this function periodically (cron job) to
accumulate a survivorship-bias-corrected archive in your own storage.

### `cg_history()` – full daily history (close, volume, market cap, +OHLC)

``` r

top50 <- cg_list()[1:50, ]
hist  <- cg_history(top50, start_date = "2014-01-01")   # back to 2014, free
```

[`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md)
returns daily history in one tibble, mirroring
[`crypto_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_history.md)’s
output. **Close, volume and market cap are available for the full
lifetime of each coin** on the free tier – typically from the coin’s
listing date forward. Missing numeric IDs are silently backfilled from
the historic mapping.

The only field with a free-tier ceiling is the **OHLC quartet (open /
high / low)**, which CoinGecko caps at the most recent 365 days. For any
longer window, `open`, `high` and `low` are returned as `NA` (close is
still populated from the price stream). If you need long-horizon OHLC
candles for microstructure or technical-signal work, the one-shot Pro
recipes in
[`vignette("coingecko-pro-backfill")`](https://www.sebastianstoeckl.com/crypto2/dev/articles/coingecko-pro-backfill.md)
produce a complete backfill of the OHLC stream too.

### `cg_info()` – per-coin metadata

``` r

info <- cg_info(cg_list()[1:10, ])
```

## Decision tree: which function should I call?

    Do I want a snapshot of *current* coins only?
    |
    +-- yes -> cg_list() + cg_listings()
    |
    +-- no, I need delisted coins too
        |
        +-- I need close / volume / market cap (any horizon)
        |   -> cg_list(only_active = FALSE) + cg_history()
        |
        +-- I need OHLC candles older than ~365 days
            -> see vignette("coingecko-pro-backfill") for the Pro recipes

## Persisting your own survivorship-bias archive

A small companion package (or a plain cron job) can run weekly:

``` r

snap <- cg_listings(which = "latest", quote = TRUE)
arrow::write_dataset(
  snap,
  path        = "data/cg_listings",
  partitioning = "harvested_at"
)
```

The accumulated parquet dataset is your survivorship-bias-corrected
universe; reading it back with
[`arrow::open_dataset()`](https://arrow.apache.org/docs/r/reference/open_dataset.html)
plus a join on `(slug, harvested_at)` gives you the historical
cross-section that the free tier alone cannot reproduce.
