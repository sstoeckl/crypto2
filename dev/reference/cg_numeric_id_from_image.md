# Extract a coin's numeric CoinGecko ID from its image URL

The documented Demo-tier API does not expose CoinGecko's internal
numeric coin ID, but the `image` URL in every coin response embeds it as
`https://coin-images.coingecko.com/coins/images/{numeric_id}/...`. The
numeric ID is required for some undocumented website-host endpoints
(notably `/ohlc/{numeric_id}/series/...` and the batched
`/coins/price_percentage_change?ids=...`).

## Usage

``` r
cg_numeric_id_from_image(image_url)
```

## Arguments

- image_url:

  Character vector of CoinGecko image URLs.

## Value

Integer vector of the same length, `NA_integer_` where extraction
failed.
