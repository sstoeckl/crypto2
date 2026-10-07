# CMC vs CoinGecko: matching and reconciling

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

Cross-checking needs two things: knowing which CoinGecko coin is which
CoinMarketCap coin, and knowing which dates line up. This vignette
covers both, after a short comparison of what each source delivers.

## Which source for what

|  | CoinMarketCap (`crypto_*`) | CoinGecko (`cg_*`) |
|----|----|----|
| Coin universe incl. dead coins | `crypto_list(only_active = FALSE)` | `cg_list(only_active = FALSE)` (via [`cg_id_mapping()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_id_mapping.md)) |
| Historical cross-section | `crypto_listings(which = "historical")`, daily since 2013-04-28 | not on the free tier; snapshot [`cg_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_listings.md) yourself |
| Daily close, volume, market cap | full history | full history in USD; other quote currencies: last 365 days |
| Daily open / high / low | full history | last 30 days |
| Wrapped, staked, bridged tokens | in the listings, ranked at the bottom | missing from [`cg_listings()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_listings.md); history via [`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md) |
| API key | none | none; optional free Demo key via `CG_DEMO_KEY` raises the rate limit |
| Coin identifier | numeric `id` | `slug` (e.g. `"bitcoin"`) and numeric `id` |

In short: CoinMarketCap is the stronger source for historical
cross-sections and full OHLC; CoinGecko is an independent second source
for prices, volume and market cap. The two id systems are unrelated,
which is what the crosswalk below solves.

## Matching coins across sources: `crypto_crosswalk()`

CoinMarketCap and CoinGecko number their coins independently. Bitcoin
happens to be id 1 on both, but that is a coincidence: Ethereum is 1027
on CoinMarketCap and 279 on CoinGecko, and symbols are not unique on
either platform. Joining the two sources on `symbol` or `name` silently
mismatches coins.

[`crypto_crosswalk()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_crosswalk.md)
downloads the Open Crypto Pricing crosswalk, which links each
CoinMarketCap id to its CoinGecko slug and numeric id, including dead
coins. Each pair is matched on contract addresses, project links,
name/symbol and slug, cross-checked against DefiLlama, and confirmed on
the price series of both providers. The file is updated weekly and
cached per R session.

``` r

library(crypto2)
library(dplyr)

cw <- crypto_crosswalk()          # high-confidence pairs only (default)
cw |> filter(cmc_id %in% c(1L, 1027L, 52L)) |>
  select(uid, cmc_id, cg_id, cg_numeric_id, symbol, match_confidence)
#> # A tibble: 3 x 6
#>   uid       cmc_id cg_id    cg_numeric_id symbol match_confidence
#>   <chr>      <int> <chr>            <int> <chr>  <chr>
#> 1 OCP004106      1 bitcoin              1 BTC    high
#> 2 OCP004108   1027 ethereum           279 ETH    high
#> 3 OCP013055     52 ripple              44 XRP    high
```

| Argument / column | Meaning |
|----|----|
| `min_confidence = "high"` | default; about 20,700 pairs (October 2026) |
| `min_confidence = "medium"` / `"low"` | adds weaker matches (about 3,600 and 2,500 more) |
| `include_unmatched = TRUE` | adds coins listed by one provider only (`match_confidence` `"cmc_only"` / `"cg_only"`, other ids `NA`) |
| `uid` | stable Open Crypto Pricing id, never reused |
| `match_basis` | the evidence behind a pair, e.g. `"contract+name_sym+slug+price"` |
| `defillama_check` | `"agrees"`, `"disagrees"`, `"suggests_pair_we_lack"`, or `NA` |
| `is_stablecoin`, `is_derived_token`, `is_tokenized_tradfi` | flags to exclude coins from a factor universe |

The crosswalk is published under CC BY 4.0. When you use or redistribute
it, cite: Stoeckl & Pukrop (2026), Open Crypto Pricing,
<https://opencryptopricing.com>.

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

This example only works without a crosswalk because Bitcoin is id 1 on
both platforms. For any other coin, take the ids from
[`crypto_crosswalk()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_crosswalk.md),
as in the next example.

Typical agreement on BTC is well under **0.05%** per day, with
occasional spikes up to ~0.5% in periods of high intra-day volatility
(the two providers compute their daily close from slightly different
exchange-weighting baskets). If you ever see \>1% on BTC, something is
wrong – start by double-checking your `date_convention` argument.

## A worked example at scale: the CMC top 20

The same reconciliation for many coins: take the current CMC top 20, map
them to CoinGecko through the crosswalk, download both histories and
compare the daily closes.

``` r

library(crypto2)
library(dplyr)

cw <- crypto_crosswalk()

top <- crypto_listings(which = "latest", limit = 20, quote = FALSE) |>
  filter(!is.na(cmc_rank)) |>            # drop index products without a rank
  select(id, name, symbol, slug)

pairs <- top |>
  inner_join(cw |> filter(!is_stablecoin) |>
               select(cmc_id, cg_id, cg_numeric_id),
             by = c("id" = "cmc_id"))

start_date <- Sys.Date() - 10

cmc <- crypto_history(coin_list = pairs,
                      start_date = format(start_date, "%Y%m%d"),
                      end_date   = format(Sys.Date() - 1, "%Y%m%d")) |>
  transmute(cmc_id = id, date = as.Date(timestamp), close_cmc = close)

options(crypto2.cg_what = c("price", "market_cap"))   # skip OHLC
cg <- cg_history(pairs |> transmute(slug = cg_id, id = cg_numeric_id),
                 start_date = start_date) |>
  transmute(cg_id = slug, date = as.Date(timestamp), close_cg = close)

pairs |>
  select(cmc_id = id, cg_id, symbol) |>
  inner_join(cmc, by = "cmc_id") |>
  inner_join(cg, by = c("cg_id", "date")) |>
  mutate(pct_diff = 100 * (close_cg / close_cmc - 1)) |>
  group_by(symbol) |>
  summarise(days           = n(),
            median_abs_pct = median(abs(pct_diff)),
            max_abs_pct    = max(abs(pct_diff))) |>
  arrange(desc(max_abs_pct))
#> # A tibble: 17 x 4
#>    symbol  days median_abs_pct max_abs_pct
#>    <chr>  <int>          <dbl>       <dbl>
#>  1 NEAR      10         0.0363      0.764
#>  2 ZEC       10         0.0939      0.195
#>  3 ADA       10         0.0411      0.192
#>  ...
#> 15 ETH       10         0.0223      0.0384
#> 16 BTC       10         0.0194      0.0280
#> 17 TRX       10         0.0127      0.0246
```

The output above is from early October 2026: all 17 coins agree to
within 0.1% on the median day; the largest single-day gap was 0.76%
(NEAR). A coin whose median gap is several percent is almost always a
mismatched pair or a wrong `date_convention`, not a pricing difference.

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
