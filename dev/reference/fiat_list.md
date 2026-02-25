# Retrieves list of all CMC supported fiat currencies available to convert cryptocurrencies

This code retrieves data for all available fiat currencies that are
available on the website.

## Usage

``` r
fiat_list(include_metals = FALSE)
```

## Arguments

- include_metals:

  Shall the results include precious metals (TRUE) or not
  (FALSE=default). Update: As of May 2024 no more metals are included in
  this file

## Value

List of (active and historically existing) cryptocurrencies in a tibble:

- id:

  CMC id (unique identifier)

- symbol:

  Coin symbol (not-unique)

- name:

  Coin name

- sign:

  Fiat currency sign

## Examples

``` r
if (FALSE) { # \dontrun{
# return fiat currencies available through the CMC api
fiat_list <- fiat_list()
} # }
```
