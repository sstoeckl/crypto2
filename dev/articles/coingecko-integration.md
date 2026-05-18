# CoinGecko integration: a second source for crypto2

## Why a second source?

`crypto2` was built around CoinMarketCap (CMC) because CMC’s internal
endpoints serve **survivorship-bias-free historical listings** without
an API key — exactly what academic finance research needs. CMC’s schema
is, however, unstable in places
([`crypto_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_info.md)
has been patched several times).

The `cg_*` functions are a second, independent source: a CoinGecko-side
counterpart with the **same column conventions** as the CMC functions,
so research code that already consumes a `crypto_*` tibble works on a
`cg_*` tibble too. Triangulating across both is the cleanest insulation
against either platform changing its terms.

## Function pairs (CMC ↔︎ CoinGecko)

| Purpose | CMC | CoinGecko | Same signature? |
|----|----|----|----|
| Coin universe | [`crypto_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_list.md) | [`cg_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_list.md) | yes |
| Current snapshot | [`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md) | [`cg_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_listings.md) | yes |
| Historical OHLC | [`crypto_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_history.md) | [`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md) | yes |
| Per-coin metadata | [`crypto_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_info.md) | [`cg_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_info.md) | yes |

The `cg_*` functions accept the **same arguments** as their `crypto_*`
counterparts. Arguments that have no CoinGecko equivalent (e.g.
`add_untracked`, `requestLimit`, `single_id`) are kept for parity and
silently ignored. Arguments where the CG free tier is more restrictive
(e.g. `which = "historical"` in
[`cg_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_listings.md))
emit a one-line warning and coerce to the supported mode.

## Free-tier limitations and how the package handles them

CoinGecko’s free tier has three relevant ceilings — the package routes
around them where possible and warns when it cannot:

1.  **Survivorship bias.** The free `/coins/list` endpoint only returns
    coins currently tracked by CoinGecko; coins that get delisted
    disappear from the universe. `cg_list(only_active = FALSE)`
    transparently merges in a periodically-updated historic mapping via
    [`cg_id_mapping()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_id_mapping.md)
    and prints one line: *“Historic data retrieval is current until
    YYYY-MM-DD”*.
2.  **365-day cap on Demo history.** Public Demo endpoints cap per-coin
    history at 365 days.
    [`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md)
    falls back to the website-host endpoints (which return full history
    in one call) when reachable; if those are blocked too, you get a
    one-time warning and the most recent 365 days only.
3.  **Cloudflare bot filtering.** The website-host endpoints are gated
    by Cloudflare. Requests from datacenter / cloud IPs typically
    receive a `403 cf-mitigated: challenge` response that no amount of
    retry will resolve.
    [`cg_get()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_get.md)
    detects this and emits one message per session advising the user to
    run from a residential IP. If you must run in the cloud, accept that
    historic OHLC will be limited to the Demo 365-day window, or upgrade
    to the Pro tier (see the “*CoinGecko Pro backfill*” vignette).

## The four core functions

All four return tibbles with column names mirroring the `crypto_*`
counterparts.

### `cg_list()` — the active coin universe

``` r

universe <- cg_list()              # active coins only
universe_full <- cg_list(only_active = FALSE)   # + historic mapping
head(universe)
#> # A tibble: 6 x 8
#>      id name      symbol slug      rank is_active first_historical_data last_historical_data
#>   <int> <chr>     <chr>  <chr>    <int>     <int> <date>                <date>
#> 1     1 Bitcoin   btc    bitcoin      1         1 NA                    2026-05-13
#> 2   279 Ethereum  eth    ethereum     2         1 NA                    2026-05-13
#> 3   825 Tether    usdt   tether       3         1 NA                    2026-05-13
```

### `cg_listings()` — current cross-sectional snapshot

``` r

snap <- cg_listings(which = "latest", quote = TRUE, limit = 1000)
```

`which = "historical"` and `which = "new"` are CMC-only — they warn and
coerce to `"latest"`. Snapshot this function periodically (cron job) to
accumulate a survivorship-bias-corrected archive in your own storage.

### `cg_history()` — historical OHLC + volume + market cap

``` r

top50 <- cg_list()[1:50, ]
hist  <- cg_history(top50, start_date = "2024-01-01")
```

[`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md)
joins the price-charts, market-cap and OHLC streams on a UTC calendar
day, mirroring
[`crypto_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_history.md)’s
daily output. Missing numeric IDs are silently backfilled from
[`cg_id_mapping()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_id_mapping.md).
When the website-host endpoints are blocked, only the Demo 365-day
window is returned (with a one-time warning).

### `cg_info()` — per-coin metadata

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
        +-- I'm running from a residential IP
        |   -> cg_list(only_active = FALSE) + cg_history()
        |       (uses the historic id mapping silently)
        |
        +-- I'm running from a cloud / VPS
            -> Cloudflare will block the website-host endpoints.
               Options:
               (a) Run the bootstrap on a laptop, ship the parquet
                   output to the server.
               (b) Subscribe to the CoinGecko Pro tier and use the
                   recipes in the 'CoinGecko Pro backfill' vignette.

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
cross-section CoinGecko’s free tier alone cannot reproduce.

## Source code conventions

- URL hosts are base64-encoded inside the package source. This mirrors
  the same defensive pattern used for the CMC endpoints — see
  [`construct_url()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/construct_url.md)
  and
  [`cg_url()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_url.md).
  The package does not embed plaintext endpoint URLs in its source tree.
- All HTTP calls go through
  [`cg_get()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_get.md),
  which raises classed conditions for retryable failures (429, network
  errors) so
  [`purrr::insistently()`](https://purrr.tidyverse.org/reference/insistently.html)
  retries cleanly without burning retry budget on permanent failures
  (404, 5xx, Cloudflare 403).
