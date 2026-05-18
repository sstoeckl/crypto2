# Historic CoinGecko id/slug mapping (incl. delisted coins)

The free CoinGecko API only exposes coins currently tracked, so coins
that get delisted after their listing day disappear from `/coins/list`.
A separate, periodically updated archive of
`(numeric_id, slug, symbol, name, harvested_at)` rows is hosted at a
stable companion location. This function downloads and caches it so
callers (e.g.
[`cg_list()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_list.md),
[`cg_history()`](https://www.sebastianstoeckl.com/crypto2/dev/reference/cg_history.md))
can transparently fall back to historic identifiers without ceremony.

## Usage

``` r
cg_id_mapping(refresh = FALSE, quiet = FALSE)
```

## Arguments

- refresh:

  Force re-download even if a cached file exists in
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html). Default `FALSE`.

- quiet:

  Suppress the one-line "historic data current until ..." message.
  Default `FALSE`.

## Value

Tibble with columns `id` (integer numeric CoinGecko id), `slug`
(character), `symbol` (character), `name` (character), `harvested_at`
(Date) – one row per historic coin. Returns an empty tibble with the
correct schema if neither the network mapping nor the bundled sample can
be loaded.

## Details

The mapping is fetched once per session and cached in
`tempdir()/crypto2_cg_mapping.parquet`. If the network is unavailable, a
small bundled sample (top 100 coins, shipped in `inst/extdata/`) is used
as a fallback. When `quiet = FALSE` (default), a single one-line message
is emitted on first successful download stating the harvest date.

## Examples

``` r
if (FALSE) { # \dontrun{
mapping <- cg_id_mapping()
delisted <- dplyr::anti_join(mapping,
  cg_list() %>% dplyr::select(slug), by = "slug")
} # }
```
