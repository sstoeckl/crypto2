# CoinGecko integration: a second source for crypto2

## Why a second source?

`crypto2` was built around CoinMarketCap (CMC). The `cg_*` functions are
a second, independent source that returns tibbles with the **same column
conventions** as the CMC functions, so research code that already
consumes a `crypto_*` tibble works on a `cg_*` tibble too.

Three concrete reasons to bother with a second source:

- **Triangulation.** If a factor signal disagrees between CMC and CG,
  treat the disagreement as informative on its own. Most schema /
  data-quality regressions show up first as a cross-source delta. The
  vignette `cg-vs-cmc` shows the dedicated reconciliation workflow.
- **Independence.** CMC and CG are owned and operated separately, so
  policy changes on one side do not affect the other.
- **Universe completeness.** CG exposes a separate (and partially
  non-overlapping) set of delisted coins to CMC, so combining the two
  universes captures more of the historic cross-section than either one
  alone.

This vignette focuses on **how** to actually pull a complete history out
of CG for asset-pricing research.

## Build a survivorship-bias-free price history (free, no key)

The end-to-end recipe is three lines of code. It produces a daily panel
of `(slug, date, close, volume, market_cap)` for every coin CoinGecko
has ever tracked – active *and* delisted – back to each coin’s listing
date.

``` r

library(crypto2)
library(arrow)

# 1. Full historic universe: active + delisted, via cg_id_mapping()
universe <- cg_list(only_active = FALSE)

# 2. Daily close / volume / market cap in USD, full lifetime per coin
#    (one CSV download per coin). Skip OHLC here -- it adds a 2nd HTTP
#    call per coin and only covers the last 30 days (see "What is NOT in
#    the free tier" below).
options(crypto2.cg_what = c("price", "market_cap"))
hist <- cg_history(universe)

# 3. Persist
arrow::write_parquet(hist, "data/cg_history.parquet")
```

**Output shape (`hist`)**: columns match
[`crypto_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_history.md)
exactly –
`id, slug, name, symbol, timestamp, ref_cur_id, ref_cur_name, open, high, low, close, volume, market_cap, time_open, ...`.
Under the default `date_convention = "end_of_day"`, dates are labelled
with CMC’s convention so `close[X] / close[X-1] - 1` is the return
earned during date X (see
[`vignette("cg-vs-cmc")`](https://www.sebastianstoeckl.com/crypto2/dev/articles/cg-vs-cmc.md)
for the date-convention story).

### Preconditions

- **Run from a workstation / local machine.** CoinGecko serves the full
  historic backfill freely, but its bot filtering refuses requests from
  some cloud / VPS environments. If
  [`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md)
  prints the one-time message *“CoinGecko refused the request from this
  environment”*, the recipe above will not complete on your host.
  Workarounds:
  1.  run the bootstrap on a laptop, ship the parquet to the server;
  2.  use the one-shot Pro recipes in
      [`vignette("coingecko-pro-backfill")`](https://www.sebastianstoeckl.com/crypto2/dev/articles/coingecko-pro-backfill.md).
- **The historic mapping must be reachable.**
  `cg_list(only_active = FALSE)` calls
  [`cg_id_mapping()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_id_mapping.md)
  to download the slug / numeric-id / symbol / name archive of delisted
  coins. The mapping is cached after the first call; if the download
  itself is blocked, only the bundled fallback (~20 reference coins) is
  used and you will see a yellow *“using bundled sample”* message.

### What you get back

| Column | Coverage on free tier |
|----|----|
| `close` | full lifetime of each coin (daily, USD) |
| `volume` | full lifetime of each coin (daily, USD) |
| `market_cap` | full lifetime of each coin (daily, USD) |
| `open`, `high`, `low` | **only the most recent 30 days**; older rows have `NA` here |

Full history is served in USD only. With `convert = "BTC"` (or any other
quote currency) close, volume and market cap come from the API and cover
the most recent 365 days.

For complete OHLC over the full history (microstructure work,
candlestick-based signals, intraday volatility models), see the Pro
recipes in
[`vignette("coingecko-pro-backfill")`](https://www.sebastianstoeckl.com/crypto2/dev/articles/coingecko-pro-backfill.md).

## Function reference

All four exported `cg_*` functions accept the same arguments as their
`crypto_*` counterparts. Arguments without a CG equivalent (e.g.
`add_untracked`, `requestLimit`, `single_id`) are kept for parity and
silently ignored. Arguments where CG is more restrictive (e.g.
`which = "historical"` in
[`cg_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_listings.md))
emit a one-line warning and coerce to the supported mode.

| Purpose | CMC | CoinGecko |
|----|----|----|
| Coin universe | [`crypto_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_list.md) | [`cg_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_list.md) |
| Current snapshot | [`crypto_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_listings.md) | [`cg_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_listings.md) |
| Daily history | [`crypto_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_history.md) | [`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md) |
| Per-coin metadata | [`crypto_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_info.md) | [`cg_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_info.md) |

### `cg_list()` – the universe

``` r

universe       <- cg_list()                       # active coins only
universe_full  <- cg_list(only_active = FALSE)    # + historic mapping
```

`only_active = FALSE` is the survivorship-bias-corrected universe: the
output is
[`cg_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_list.md)’s
active rows plus the historic-only rows from
[`cg_id_mapping()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_id_mapping.md).
A single one-line message reports the mapping’s harvest date: *“Historic
data retrieval is current until YYYY-MM-DD”*.

### `cg_listings()` – current cross-section

``` r

snap <- cg_listings(limit = 1000)   # prices included by default
```

The snapshot carries every `/coins/markets` field: price, 24h volume and
range, price and market-cap changes, all-time high/low and ROI (see
[`?cg_listings`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_listings.md)
for the column mapping). Two caveats:

- `/coins/markets` no longer lists wrapped, staked or bridged tokens
  (stETH, wstETH, WBTC, JitoSOL, bridged USDT, …). Their history is only
  available through
  [`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md).
- Without a key the public endpoint allows only a few calls per minute,
  and a full snapshot needs about 70 pages. Setting
  `Sys.setenv(CG_DEMO_KEY = "...")` to a free Demo-API key raises the
  limit to 30 calls per minute. Failed pages are retried with backoff;
  if a page still fails,
  [`cg_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_listings.md)
  warns with the page number instead of returning a silently truncated
  snapshot.

`which = "historical"` and `which = "new"` warn and coerce to `"latest"`
– CG’s free tier does not expose the historical cross-section in a
single call. To build your own cross-section history on the free tier,
snapshot
[`cg_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_listings.md)
periodically (cron) and accumulate the parquet output:

``` r

arrow::write_dataset(
  cg_listings(),
  path        = "data/cg_listings",
  partitioning = "harvested_at"
)
```

### `cg_history()` – the workhorse

Covered in the recipe at the top of this vignette. Key knobs:

- `start_date` / `end_date` – date window (client-side filter).
- `options(crypto2.cg_what = ...)` – restrict to
  `c("price", "market_cap")` to skip OHLC and save one HTTP call per
  coin.
- `date_convention = c("end_of_day", "raw")` – default `"end_of_day"`
  aligns dates with CMC; see
  [`vignette("cg-vs-cmc")`](https://www.sebastianstoeckl.com/crypto2/dev/articles/cg-vs-cmc.md).

### `cg_info()` – per-coin metadata

``` r

info <- cg_info(cg_list()[1:10, ])
```

Description, categories, contract addresses across chains, and various
link fields. Same column conventions as
[`crypto_info()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_info.md).

## What is NOT in the free tier

The free tier covers every cell needed for daily asset-pricing work in
USD *except* the older end of the OHLC quartet:

- **OHLC (open / high / low) older than 30 days.** Close is fine
  (returned from the price stream), volume and market cap are fine, but
  the three intra-day extreme columns come back `NA` for any date more
  than a month old; CoinGecko offers longer windows only as 4-day
  candles. For a complete backfill, run the Pro recipes in
  [`vignette("coingecko-pro-backfill")`](https://www.sebastianstoeckl.com/crypto2/dev/articles/coingecko-pro-backfill.md)
  once – the recipes are kept inline in that vignette rather than
  exported from the package, so the package itself stays key-less.

## Cross-checking against CMC

Triangulation is one click away once you have the parquet from the
recipe above. The dedicated vignette `cg-vs-cmc` walks through:

- the date-convention difference between CMC and CG and how `crypto2`
  harmonizes it;
- a worked BTC reconciliation showing typical agreement \< 0.05% per
  day;
- which fields are expected to agree exactly vs. which ones genuinely
  differ between providers (volume disagrees more than price – they
  aggregate over different exchange sets).

A live cross-source test (`tests/testthat/test-cg-vs-cmc.R`) runs in CI
and will fail loudly if either provider drifts.
