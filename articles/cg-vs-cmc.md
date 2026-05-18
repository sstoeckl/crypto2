# Cross-source reconciliation: CMC vs CoinGecko

## Why compare?

The `crypto_*` functions (CoinMarketCap) and the `cg_*` functions
(CoinGecko) are deliberately interchangeable – column names, sort order
and types match – so the same downstream code consumes either tibble.
For empirical work the right thing to do is to **always cross-check** a
metric across both sources. Doing so:

- catches silent schema regressions on either platform;
- catches unit-of-quote bugs (USD vs sats vs cents);
- catches calendar / date-labelling errors;
- and gives factor pipelines a robustness buffer when one provider
  changes its policies.

## The date-convention pitfall

A subtle but important detail: the two providers label the **same
physical instant** with different dates.

| Provider | Daily price labelled date X means |
|----|----|
| CoinMarketCap (post-2018) | the close *at the end of* UTC day X (~23:59:59 UTC of date X) |
| CoinGecko (native) | the snapshot *at the start of* UTC day X (00:00:00 UTC of date X) |

These two instants are essentially the same moment in time (they differ
by 1 second), but the date labels disagree by one day. The first
convention is the **standard asset-pricing convention** (CRSP,
Compustat, Liu/Tsyvinski/Wu 2022 and most academic work): under it,
`close[X] / close[X-1] - 1` is the return earned during date X.

[`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md)
and
[`cg_history_by_id()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history_by_id.md)
ship with `date_convention = "end_of_day"` as the default, which shifts
CG’s midnight-UTC ticks by -1 day so the output lines up with CMC’s
labels. Pass `date_convention = "raw"` to keep CG’s native start-of-day
labels (useful when you are doing diagnostic work directly against the
CoinGecko UI or its public API).

``` r

# default: CMC / CRSP / Compustat convention
btc_cg <- cg_history(coin_list = tibble::tibble(slug = "bitcoin", id = 1L),
                     start_date = "2026-05-01")

# raw: CG's start-of-day labels
btc_cg_raw <- cg_history(coin_list = tibble::tibble(slug = "bitcoin", id = 1L),
                         start_date  = "2026-05-01",
                         date_convention = "raw")
```

## A worked example: Bitcoin reconciliation

``` r

library(crypto2)
library(dplyr)
library(tibble)

start_date <- Sys.Date() - 10
end_date   <- Sys.Date()
btc_anchor <- tibble::tibble(id = 1L, slug = "bitcoin",
                             name = "Bitcoin", symbol = "BTC")

cmc <- crypto_history(coin_list = btc_anchor, convert = "USD",
                      start_date = start_date, end_date = end_date) |>
  transmute(date = as.Date(timestamp), close_cmc = close)

cg <- cg_history(coin_list = btc_anchor, convert = "USD",
                 start_date = start_date, end_date = end_date) |>
  transmute(date = as.Date(timestamp), close_cg = close)

joined <- inner_join(cmc, cg, by = "date") |>
  mutate(pct_diff = (close_cg - close_cmc) / close_cmc * 100) |>
  arrange(date)

joined
#> # A tibble: 10 x 4
#>    date       close_cmc close_cg  pct_diff
#>    <date>         <dbl>    <dbl>     <dbl>
#>  1 2026-05-08    80187.   80189.  0.003
#>  2 2026-05-09    80664.   80678.  0.017
#>  3 2026-05-10    82139.   82146.  0.008
#>  ...
```

Typical agreement on BTC is well under **0.05%** per day, with
occasional spikes up to ~0.5% in periods of high intra-day volatility
(the two providers compute their daily close from slightly different
exchange-weighting baskets). If you ever see \>1% on BTC, something is
wrong – start by double-checking your `date_convention` argument.

## What’s expected to differ – and what isn’t

| Field | Typical agreement | Caveats |
|----|----|----|
| `close` (BTC, ETH) | \< 0.05% per day | Different exchange weightings; spikes during volatility |
| `close` (small caps) | \< 1% per day | Larger spreads, more reliance on a single venue |
| `volume` | poor (often \>20%) | The two providers aggregate over different exchange sets |
| `market_cap` | \< 1% if supply agrees | Discrepancies usually indicate disagreement on circulating supply, not price |
| `circulating_supply` | exact (large caps) | Self-reported supplies on small caps can diverge |

Use price for cross-validation; treat volume and market-cap-via-supply
disagreements as informative on their own.

## The built-in test

`tests/testthat/test-cg-vs-cmc.R` runs a tight reconciliation on BTC
(7-day window, tolerance 1%) on every CI run that has network access. It
will fail loudly if the date conventions ever drift out of alignment
again, or if either provider switches its underlying basket
significantly enough to break the tolerance.

## When to override the default

The `"end_of_day"` default is what you almost always want. Switch to
`"raw"` when:

- you are reproducing a CoinGecko chart published with start-of-day
  labels;
- you are debugging the raw data parsing inside
  [`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md);
- you are comparing daily CG output side-by-side with a Demo
  `/coins/{id}/market_chart` call (which also returns start-of-day
  timestamps).

Otherwise, leave it alone and join cleanly with
[`crypto_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_history.md)
output on `as.Date(timestamp)`.
