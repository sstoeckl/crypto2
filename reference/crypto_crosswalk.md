# Crosswalk between CoinMarketCap and CoinGecko coin ids

Downloads the Open Crypto Pricing crosswalk, which links every
CoinMarketCap id (as used by the `crypto_*` functions) to its CoinGecko
coin (as used by the `cg_*` functions), including dead coins. Each pair
is matched on contract addresses, project links, name/symbol and slug,
cross-checked against DefiLlama, and confirmed on the price series of
both providers. The file is updated weekly.

## Usage

``` r
crypto_crosswalk(
  min_confidence = c("high", "medium", "low"),
  include_unmatched = FALSE,
  refresh = FALSE,
  quiet = FALSE
)
```

## Source

Stoeckl & Pukrop (2026), Open Crypto Pricing,
<https://opencryptopricing.com>. Licensed under CC BY 4.0: cite the
source when you use or redistribute the crosswalk.

## Arguments

- min_confidence:

  Lowest match confidence to keep, one of `"high"` (default), `"medium"`
  or `"low"`. Each level includes the ones above it, so `"low"` returns
  all published matches.

- include_unmatched:

  If `TRUE`, also return coins listed by only one provider
  (`match_confidence` `"cmc_only"` or `"cg_only"`), which have `NA` for
  the other provider's ids. Default `FALSE`.

- refresh:

  Download again even if the file is cached this session.

- quiet:

  Suppress the one-line source message.

## Value

Tibble with one row per coin:

- uid:

  Open Crypto Pricing id, never reused (e.g. `"OCP004106"` for Bitcoin).

- cmc_id:

  CoinMarketCap id (the `id` column of
  [`crypto_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/crypto_list.md)).

- cg_id:

  CoinGecko slug (the `slug` column of
  [`cg_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_list.md)).

- cg_numeric_id:

  CoinGecko numeric id (the `id` column of
  [`cg_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_list.md)).

- name, symbol:

  Coin name and symbol.

- match_confidence:

  `"high"`, `"medium"` or `"low"`, or `"cmc_only"` / `"cg_only"` for
  unmatched coins.

- match_basis:

  The evidence that matched, joined by `+` (e.g.
  `"contract+name_sym+slug+price"`).

- defillama_check:

  `"agrees"`, `"disagrees"`, `"suggests_pair_we_lack"` or `NA` when
  DefiLlama has no entry.

- is_stablecoin, is_derived_token, is_tokenized_tradfi:

  Logical flags.

## Details

The file is downloaded once per session and cached in
[`tempdir()`](https://rdrr.io/r/base/tempfile.html). Parquet is used
when the `arrow` package is installed, CSV otherwise.

## Examples

``` r
if (FALSE) { # \dontrun{
cw <- crypto_crosswalk()

# CoinGecko history for the CMC top 100, via the crosswalk
top <- crypto_listings(limit = 100)
ids <- dplyr::inner_join(top, cw, by = c("id" = "cmc_id"))
hist <- cg_history(dplyr::select(ids, slug = cg_id, id = cg_numeric_id))
} # }
```
