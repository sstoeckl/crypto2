
<!-- README.md is generated from README.Rmd. Please edit that file -->

<!-- badges: start -->

[![Project
Status](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)
[![Build
Status](https://travis-ci.org/sstoeckl/crypto2.svg?branch=master)](https://travis-ci.org/sstoeckl/crypto2)
[![CRAN
status](https://www.r-pkg.org/badges/version/crypto2)](https://CRAN.R-project.org/package=crypto2)
<!-- badges: end -->

# Historical Cryptocurrency Prices for Active and Delisted Tokens!

This is a modification of the original `crypto` package by [jesse
vent](https://github.com/JesseVent/crypto). It is entirely set up to use
means from the `tidyverse` and provides `tibble`s with all data
available via the web-api of
[coinmarketcap.com](https://coinmarketcap.com/). **It does not require
an API key but in turn only provides information that is also available
through the website of
[coinmarketcap.com](https://coinmarketcap.com/).**

It allows the user to retrieve

-   `crypto_list()` a list of all coins that are listed as either being
    *active*, *delisted* or *untracked* according to the [CMC API
    documentation](https://coinmarketcap.com/api/documentation/v1/#operation/getV1CryptocurrencyMap)
-   `crypto_info()` a list of all information available for all
    available coins according to the [CMC API
    documentation](https://coinmarketcap.com/api/documentation/v1/#operation/getV1CryptocurrencyInfo)
-   `crypto_history()` the **most powerful** function of this package
    that allows to download the entire available history for all coins
    covered by CMC according to the [CMC API
    documentation](https://coinmarketcap.com/api/documentation/v1/#operation/getV1CryptocurrencyOhlcvHistorical)
-   `fiat_list()` a mapping of all fiat currencies (plus precious
    metals) available via the [CMC WEB
    API](https://coinmarketcap.com/api/documentation/v1/#operation/getV1FiatMap)
-   `exchange_list()` a list of all exchanges available as either being
    *active*, *delisted* or *untracked* according to the [CMC API
    documentation](https://coinmarketcap.com/api/documentation/v1/#operation/getV1ExchangeMap)
-   `exchange_info()` a list of all information available for all given
    exchanges according to the [CMC API
    documentation](https://coinmarketcap.com/api/documentation/v1/#operation/getV1ExchangeInfo)

## Installation

You can install `crypto2` from CRAN with

``` r
install.packages("crypto2")
```

or directly from github with:

``` r
# install.packages("devtools")
devtools::install_github("sstoeckl/crypto2")
```

## Package Contribution

The package provides API free and efficient access to all information
from <https://coinmarketcap.com> that is also available through their
website. It uses a variety of modification and web\_Scraping tools from
the `tidyverse` (especially `purrr`).

As this provides access not only to **active** coins but also to those
that have now been **delisted**, including historical pricing
information, this package provides a valid basis for any **Asset Pricing
Studies** based on crypto currencies that require
**survivorship-bias-free** information. In addition to that, the package
maintainer is currently working on also providing **delisting returns**
(similarly to CRSP for stocks) to also eliminate the **delisting bias**.

## Package Usage

``` r
library(crypto2)
#> Loading required package: rvest
#> Loading required package: xml2
library(dplyr)
#> 
#> Attaching package: 'dplyr'
#> The following objects are masked from 'package:stats':
#> 
#>     filter, lag
#> The following objects are masked from 'package:base':
#> 
#>     intersect, setdiff, setequal, union

# List all active coins
coins <- crypto_list(only_active=TRUE)

# retrieve historical data for all (the first 3) of them
coin_hist <- crypto_history(coins, limit=3, start_date="20200101")
#> > Scraping historical crypto data
#> 
#> > Processing historical crypto data
#> 

# and give the first two lines of information per coin
coin_hist %>% group_by(slug) %>% slice(1:2)
#> # A tibble: 6 x 16
#> # Groups:   slug [3]
#>   timestamp           slug      id name   symbol ref_cur    open    high     low
#>   <dttm>              <chr>  <int> <chr>  <chr>  <chr>     <dbl>   <dbl>   <dbl>
#> 1 2020-01-01 23:59:59 bitco~     1 Bitco~ BTC    USD     7.19e+3 7.25e+3 7.17e+3
#> 2 2020-01-02 23:59:59 bitco~     1 Bitco~ BTC    USD     7.20e+3 7.21e+3 6.94e+3
#> 3 2020-01-01 23:59:59 litec~     2 Litec~ LTC    USD     4.13e+1 4.23e+1 4.13e+1
#> 4 2020-01-02 23:59:59 litec~     2 Litec~ LTC    USD     4.20e+1 4.21e+1 3.97e+1
#> 5 2020-01-01 23:59:59 namec~     3 Namec~ NMC    USD     4.69e-1 4.79e-1 4.50e-1
#> 6 2020-01-02 23:59:59 namec~     3 Namec~ NMC    USD     4.60e-1 4.68e-1 4.22e-1
#> # ... with 7 more variables: close <dbl>, volume <dbl>, market_cap <dbl>,
#> #   time_open <dttm>, time_close <dttm>, time_high <dttm>, time_low <dttm>
```

### Author/License

-   **Sebastian Stöckl** - Package Creator, Modifier & Maintainer -
    [sstoeckl](https://github.com/sstoeckl)

This project is licensed under the MIT License - see the
&lt;license.md&gt; file for details&lt;/license.md&gt;

### Acknowledgments

-   Thanks to the team at <https://coinmarketcap.com> for the great work
    they do
-   Thanks to Jesse Vent for providing the original (nut fully research
    compatible) `crypto`-package
