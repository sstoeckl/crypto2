---
output: github_document
---

<!-- README.md is generated from README.Rmd. Please edit that file -->



# crypto2 <a href='https://github.com/sstoeckl/crypto2'><img src='man/figures/crypto2_hex.png' align="right" height="139" /></a>

 <!-- badges: start -->

  [![Project Status](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)
  [![Build Status](https://travis-ci.org/sstoeckl/crypto2.svg?branch=master)](https://travis-ci.org/sstoeckl/crypto2)
  [![CRAN status](https://www.r-pkg.org/badges/version/crypto2)](https://CRAN.R-project.org/package=crypto2)
  [![](http://cranlogs.r-pkg.org/badges/grand-total/crypto2)](https://cran.r-project.org/package=crypto2)
  [![](http://cranlogs.r-pkg.org/badges/crypto2)](https://cran.r-project.org/package=crypto2)
  [![](http://cranlogs.r-pkg.org/badges/last-week/crypto2)](https://cran.r-project.org/package=crypto2)
 <!-- badges: end -->

# Historical Cryptocurrency Prices for Active and Delisted Tokens!

This is a modification of the original `crypto` package by [jesse vent](https://github.com/JesseVent/crypto). It is entirely set up to use means from the `tidyverse` and provides `tibble`s with all data available via the web-api of [coinmarketcap.com](https://coinmarketcap.com/). **It does not require an API key but in turn only provides information that is also available through the website of [coinmarketcap.com](https://coinmarketcap.com/).**

It allows the user to retrieve

- `crypto_listings()` a list of all coins that were historically listed on CMC (main dataset to avoid delisting bias) according to the [CMC API documentation](https://coinmarketcap.com/api/documentation/v1/#operation/getV1CryptocurrencyListingsHistorical)
- `crypto_list()` a list of all coins that are listed as either being *active*, *delisted* or *untracked* according to the [CMC API documentation](https://coinmarketcap.com/api/documentation/v1/#operation/getV1CryptocurrencyMap)
- `crypto_info()` a list of all information available for all available coins according to the [CMC API documentation](https://coinmarketcap.com/api/documentation/v1/#operation/getV1CryptocurrencyInfo)
- `crypto_history()` the **most powerful** function of this package that allows to download the entire available history for all coins covered by CMC according to the [CMC API documentation](https://coinmarketcap.com/api/documentation/v1/#operation/getV1CryptocurrencyOhlcvHistorical)
- `fiat_list()` a mapping of all fiat currencies (plus precious metals) available via the [CMC WEB API](https://coinmarketcap.com/api/documentation/v1/#operation/getV1FiatMap)
- `exchange_list()` a list of all exchanges available as either being *active*, *delisted* or *untracked* according to the [CMC API documentation](https://coinmarketcap.com/api/documentation/v1/#operation/getV1ExchangeMap)
- `exchange_info()` a list of all information available for all given exchanges according to the [CMC API documentation](https://coinmarketcap.com/api/documentation/v1/#operation/getV1ExchangeInfo)

# Update

Since version 1.4.4 a new function `crypto_listings()` was introduced that retrieves new/latest/historical listings and listing information at CMC. Additionally some aspects of the other functions have been reworked. We noticed that `finalWait = TRUE` does not seem to be necessary at the moment, as well as `sleep` can be set to '0' seconds. If you experience strange behavior this might be due to the the api sending back strange (old) results. In this case let `sleep = 60` (the default) and `finalWait = TRUE` (the default).

Since version 1.4.0 the package has been reworked to retrieve as many assets as possible with one api call, as there is a new "feature" introduced by CMC to send back the initially requested data for each api call within 60 seconds. So one needs to wait 60s before calling the api again. Additionally, since version v1.4.3 the package allows for a data `interval` larger than daily (e.g. '2d' or '7d'/'weekly')

## Installation

You can install `crypto2` from CRAN with 

```r
install.packages("crypto2")
```
or directly from github with:

```r
# install.packages("devtools")
devtools::install_github("sstoeckl/crypto2")
```

## Package Contribution

The package provides API free and efficient access to all information from <https://coinmarketcap.com> that is also available through their website. It uses a variety of modification and web-scraping tools from the `tidyverse` (especially `purrr`).

As this provides access not only to **active** coins but also to those that have now been **delisted** and also those that are categorized as **untracked**, including historical pricing information, this package provides a valid basis for any **Asset Pricing Studies** based on crypto currencies that require **survivorship-bias-free** information. In addition to that, the package maintainer is currently working on also providing **delisting returns** (similarly to CRSP for stocks) to also eliminate the **delisting bias**.

## Package Usage

First we load the `crypto2`-package and download the set of active coins from <https://coinmarketcap.com> (additionally one could load delisted coins with `only_Active=FALSE` as well as untracked coins with `add_untracked=TRUE`).


```r
library(crypto2)
library(dplyr)
#> 
#> Attache Paket: 'dplyr'
#> Die folgenden Objekte sind maskiert von 'package:stats':
#> 
#>     filter, lag
#> Die folgenden Objekte sind maskiert von 'package:base':
#> 
#>     intersect, setdiff, setequal, union

# List all active coins
coins <- crypto_list(only_active=TRUE)
```

Next we download information on the first three coins from that list.


```r
# retrieve information for all (the first 3) of those coins
coin_info <- crypto_info(coins, limit=3, finalWait=FALSE)
#> > Scraping crypto info
#> 
#> Scraping  https://web-api.coinmarketcap.com/v1/cryptocurrency/info?id=1,2,3  with  65  characters!
#> > Processing crypto info
#> 
#> > Sleep for 60s before finishing to not have next function call end up with this data!
#> 

# and give the first two lines of information per coin
coin_info
#> # A tibble: 3 x 19
#>      id name     symbol category description                     slug  logo  subre~1 notice date_~2 twitt~3 is_hi~4 date_~5 self_~6 self_~7 tags     self_~8 urls     platform
#> * <int> <chr>    <chr>  <chr>    <chr>                           <chr> <chr> <chr>   <chr>  <chr>   <chr>     <int> <lgl>   <lgl>   <lgl>   <list>   <lgl>   <list>   <list>  
#> 1     1 Bitcoin  BTC    coin     "## What Is Bitcoin (BTC)?\n\n~ bitc~ http~ bitcoin ""     2013-0~ ""            0 NA      NA      NA      <tibble> NA      <tibble> <lgl>   
#> 2     2 Litecoin LTC    coin     "## What Is Litecoin (LTC)?\n\~ lite~ http~ liteco~ ""     2013-0~ "Litec~       0 NA      NA      NA      <tibble> NA      <tibble> <tibble>
#> 3     3 Namecoin NMC    coin     "Namecoin (NMC) is a cryptocur~ name~ http~ nameco~ ""     2013-0~ "Namec~       0 NA      NA      NA      <tibble> NA      <tibble> <lgl>   
#> # ... with abbreviated variable names 1: subreddit, 2: date_added, 3: twitter_username, 4: is_hidden, 5: date_launched, 6: self_reported_circulating_supply,
#> #   7: self_reported_market_cap, 8: self_reported_tags
```

In a next step we show the logos of the three coins as provided by <https://coinmarketcap.com>.

<img src="https://s2.coinmarketcap.com/static/img/coins/64x64/1.png" alt="plot of chunk logos" width="5%" height="5%" style="display: block; margin: auto;" /><img src="https://s2.coinmarketcap.com/static/img/coins/64x64/2.png" alt="plot of chunk logos" width="5%" height="5%" style="display: block; margin: auto;" /><img src="https://s2.coinmarketcap.com/static/img/coins/64x64/3.png" alt="plot of chunk logos" width="5%" height="5%" style="display: block; margin: auto;" />

In addition we show tags provided by <https://coinmarketcap.com>.


```r
coin_info %>% select(slug,tags) %>% tidyr::unnest(tags) %>% group_by(slug) %>% slice(1,n())
#> # A tibble: 6 x 2
#> # Groups:   slug [3]
#>   slug     tags              
#>   <chr>    <chr>             
#> 1 bitcoin  mineable          
#> 2 bitcoin  paradigm-portfolio
#> 3 litecoin mineable          
#> 4 litecoin medium-of-exchange
#> 5 namecoin mineable          
#> 6 namecoin platform
```

Additionally: Here are some urls pertaining to these coins as provided by <https://coinmarketcap.com>.


```r
coin_info %>% select(slug,urls) %>% tidyr::unnest(urls) %>% filter(name %in% c("reddit","twitter"))
#> # A tibble: 5 x 3
#>   slug     name    url                                
#>   <chr>    <chr>   <chr>                              
#> 1 bitcoin  reddit  https://reddit.com/r/bitcoin       
#> 2 litecoin twitter https://twitter.com/LitecoinProject
#> 3 litecoin reddit  https://reddit.com/r/litecoin      
#> 4 namecoin twitter https://twitter.com/Namecoin       
#> 5 namecoin reddit  https://reddit.com/r/namecoin
```

In a next step we download time series data for these coins.


```r
# retrieve historical data for all (the first 3) of them
coin_hist <- crypto_history(coins, limit=3, start_date="20210101", end_date="20210105", finalWait=FALSE)
#> > Scraping historical crypto data
#> 
#> > Processing historical crypto data
#> 

# and give the first two times of information per coin
coin_hist %>% group_by(slug) %>% slice(1:2)
#> # A tibble: 6 x 16
#> # Groups:   slug [3]
#>   timestamp              id slug     name     symbol ref_cur      open      high       low   close  volume marke~1 time_open           time_close          time_high          
#>   <dttm>              <int> <chr>    <chr>    <chr>  <chr>       <dbl>     <dbl>     <dbl>   <dbl>   <dbl>   <dbl> <dttm>              <dttm>              <dttm>             
#> 1 2021-01-01 23:59:59     1 bitcoin  Bitcoin  BTC    USD     28994.    29601.    28804.    2.94e+4 4.07e10 5.46e11 2021-01-01 00:00:00 2021-01-01 23:59:59 2021-01-01 12:38:43
#> 2 2021-01-02 23:59:59     1 bitcoin  Bitcoin  BTC    USD     29376.    33155.    29091.    3.21e+4 6.79e10 5.97e11 2021-01-02 00:00:00 2021-01-02 23:59:59 2021-01-02 19:49:42
#> 3 2021-01-01 23:59:59     2 litecoin Litecoin LTC    USD       125.      133.      123.    1.26e+2 7.33e 9 8.36e 9 2021-01-01 00:00:00 2021-01-01 23:59:59 2021-01-01 03:02:03
#> 4 2021-01-02 23:59:59     2 litecoin Litecoin LTC    USD       126.      140.      124.    1.37e+2 1.05e10 9.07e 9 2021-01-02 00:00:00 2021-01-02 23:59:59 2021-01-02 19:34:03
#> 5 2021-01-01 23:59:59     3 namecoin Namecoin NMC    USD         0.439     0.463     0.432 4.51e-1 3.74e 4 6.65e 6 2021-01-01 00:00:00 2021-01-01 23:59:59 2021-01-01 16:52:02
#> 6 2021-01-02 23:59:59     3 namecoin Namecoin NMC    USD         0.451     0.510     0.415 4.25e-1 3.75e 4 6.26e 6 2021-01-02 00:00:00 2021-01-02 23:59:59 2021-01-02 17:33:02
#> # ... with 1 more variable: time_low <dttm>, and abbreviated variable name 1: market_cap
```

Similarly, we could download the same data on a monthly basis.


```r
# retrieve historical data for all (the first 3) of them
coin_hist_m <- crypto_history(coins, limit=3, start_date="20210101", end_date="20210501", interval ="monthly", finalWait=FALSE)
#> > Scraping historical crypto data
#> 
#> > Processing historical crypto data
#> 

# and give the first two times of information per coin
coin_hist_m %>% group_by(slug) %>% slice(1:2)
#> # A tibble: 6 x 16
#> # Groups:   slug [3]
#>   timestamp              id slug     name     symbol ref_cur      open      high       low   close  volume marke~1 time_open           time_close          time_high          
#>   <dttm>              <int> <chr>    <chr>    <chr>  <chr>       <dbl>     <dbl>     <dbl>   <dbl>   <dbl>   <dbl> <dttm>              <dttm>              <dttm>             
#> 1 2021-01-01 23:59:59     1 bitcoin  Bitcoin  BTC    USD     28994.    29601.    28804.    2.94e+4 4.07e10 5.46e11 2021-01-01 00:00:00 2021-01-01 23:59:59 2021-01-01 12:38:43
#> 2 2021-02-01 23:59:59     1 bitcoin  Bitcoin  BTC    USD     33115.    34638.    32384.    3.35e+4 6.14e10 6.24e11 2021-02-01 00:00:00 2021-02-01 23:59:59 2021-02-01 09:07:36
#> 3 2021-01-01 23:59:59     2 litecoin Litecoin LTC    USD       125.      133.      123.    1.26e+2 7.33e 9 8.36e 9 2021-01-01 00:00:00 2021-01-01 23:59:59 2021-01-01 03:02:03
#> 4 2021-02-01 23:59:59     2 litecoin Litecoin LTC    USD       130.      136.      126.    1.32e+2 5.61e 9 8.76e 9 2021-02-01 00:00:00 2021-02-01 23:59:59 2021-02-01 11:58:03
#> 5 2021-01-01 23:59:59     3 namecoin Namecoin NMC    USD         0.439     0.463     0.432 4.51e-1 3.74e 4 6.65e 6 2021-01-01 00:00:00 2021-01-01 23:59:59 2021-01-01 16:52:02
#> 6 2021-02-01 23:59:59     3 namecoin Namecoin NMC    USD         0.782     0.805     0.748 7.50e-1 7.13e 4 1.10e 7 2021-02-01 00:00:00 2021-02-01 23:59:59 2021-02-01 09:24:02
#> # ... with 1 more variable: time_low <dttm>, and abbreviated variable name 1: market_cap
```

Alternatively, we could determine the price of these coins in other currencies. A list of such currencies is available as `fiat_list()`


```r
fiats <- fiat_list()
fiats
#> # A tibble: 93 x 4
#>       id name                 sign  symbol
#>    <int> <chr>                <chr> <chr> 
#>  1  2781 United States Dollar $     USD   
#>  2  2782 Australian Dollar    $     AUD   
#>  3  2783 Brazilian Real       R$    BRL   
#>  4  2784 Canadian Dollar      $     CAD   
#>  5  2785 Swiss Franc          Fr    CHF   
#>  6  2786 Chilean Peso         $     CLP   
#>  7  2787 Chinese Yuan         <U+00A5>     CNY   
#>  8  2788 Czech Koruna         K<U+010D>    CZK   
#>  9  2789 Danish Krone         kr    DKK   
#> 10  2790 Euro                 <U+20AC>     EUR   
#> # ... with 83 more rows
```

So we download the time series again depicting prices in terms of Bitcoin and Euro (note that multiple currencies can be given to `convert`, separated by ",").


```r
# retrieve historical data for all (the first 3) of them
coin_hist2 <- crypto_history(coins, convert="BTC,EUR", limit=3, start_date="20210101", end_date="20210105", finalWait=FALSE)
#> > Scraping historical crypto data
#> 
#> > Processing historical crypto data
#> 

# and give the first two times of information per coin
coin_hist2 %>% group_by(slug,ref_cur) %>% slice(1:2)
#> # A tibble: 12 x 16
#> # Groups:   slug, ref_cur [6]
#>    timestamp              id slug     name     symbol ref_cur         open    high     low   close  volume marke~1 time_open           time_close          time_high          
#>    <dttm>              <int> <chr>    <chr>    <chr>  <chr>          <dbl>   <dbl>   <dbl>   <dbl>   <dbl>   <dbl> <dttm>              <dttm>              <dttm>             
#>  1 2021-01-01 23:59:43     1 bitcoin  Bitcoin  BTC    BTC          1   e+0 1.00e+0 9.98e-1 1   e+0 1.39e 6 1.86e 7 2021-01-01 00:00:00 2021-01-01 23:59:59 2021-01-01 12:38:43
#>  2 2021-01-02 23:59:43     1 bitcoin  Bitcoin  BTC    BTC          1   e+0 1.00e+0 9.99e-1 1   e+0 2.11e 6 1.86e 7 2021-01-02 00:00:00 2021-01-02 23:59:59 2021-01-02 19:49:42
#>  3 2021-01-01 23:59:06     1 bitcoin  Bitcoin  BTC    EUR          2.37e+4 2.43e+4 2.36e+4 2.42e+4 3.35e10 4.49e11 2021-01-01 00:00:00 2021-01-01 23:59:59 2021-01-01 12:38:43
#>  4 2021-01-02 23:59:06     1 bitcoin  Bitcoin  BTC    EUR          2.42e+4 2.73e+4 2.40e+4 2.65e+4 5.59e10 4.92e11 2021-01-02 00:00:00 2021-01-02 23:59:59 2021-01-02 19:49:42
#>  5 2021-01-01 23:59:43     2 litecoin Litecoin LTC    BTC          4.30e-3 4.56e-3 4.27e-3 4.30e-3 2.49e 5 2.85e 5 2021-01-01 00:00:00 2021-01-01 23:59:59 2021-01-01 03:02:03
#>  6 2021-01-02 23:59:43     2 litecoin Litecoin LTC    BTC          4.30e-3 4.24e-3 4.23e-3 4.26e-3 3.28e 5 2.82e 5 2021-01-02 00:00:00 2021-01-02 23:59:59 2021-01-02 19:34:03
#>  7 2021-01-01 23:59:06     2 litecoin Litecoin LTC    EUR          1.02e+2 1.09e+2 1.01e+2 1.04e+2 6.03e 9 6.88e 9 2021-01-01 00:00:00 2021-01-01 23:59:59 2021-01-01 03:02:03
#>  8 2021-01-02 23:59:06     2 litecoin Litecoin LTC    EUR          1.04e+2 1.16e+2 1.02e+2 1.13e+2 8.68e 9 7.47e 9 2021-01-02 00:00:00 2021-01-02 23:59:59 2021-01-02 19:34:03
#>  9 2021-01-01 23:59:43     3 namecoin Namecoin NMC    BTC          1.51e-5 1.58e-5 1.50e-5 1.54e-5 1.27e 0 2.26e 2 2021-01-01 00:00:00 2021-01-01 23:59:59 2021-01-01 16:52:02
#> 10 2021-01-02 23:59:43     3 namecoin Namecoin NMC    BTC          1.54e-5 1.57e-5 1.31e-5 1.32e-5 1.17e 0 1.95e 2 2021-01-02 00:00:00 2021-01-02 23:59:59 2021-01-02 17:33:02
#> 11 2021-01-01 23:59:06     3 namecoin Namecoin NMC    EUR          3.60e-1 3.80e-1 3.54e-1 3.71e-1 3.07e 4 5.47e 6 2021-01-01 00:00:00 2021-01-01 23:59:59 2021-01-01 16:52:02
#> 12 2021-01-02 23:59:06     3 namecoin Namecoin NMC    EUR          3.71e-1 4.21e-1 3.41e-1 3.50e-1 3.09e 4 5.16e 6 2021-01-02 00:00:00 2021-01-02 23:59:59 2021-01-02 17:33:02
#> # ... with 1 more variable: time_low <dttm>, and abbreviated variable name 1: market_cap
```

As a new features in version 1.4.4. we introduced the possibility to download historical listings and listing information (add `quote = TRUE`).


```r
latest_listings <- crypto_listings(which="latest", limit=10, quote=TRUE, finalWait=FALSE)
latest_listings
#> # A tibble: 10 x 23
#>       id name     symbol slug  self_~1 self_~2 tvl_r~3 last_upd~4 USD_p~5 USD_v~6 USD_v~7 USD_pe~8 USD_pe~9 USD_p~* USD_pe~* USD_pe~* USD_pe~* USD_m~* USD_m~* USD_f~* USD_tvl
#>    <int> <chr>    <chr>  <chr> <lgl>   <lgl>   <lgl>   <date>       <dbl>   <dbl>   <dbl>    <dbl>    <dbl>   <dbl>    <dbl>    <dbl>    <dbl>   <dbl>   <dbl>   <dbl> <lgl>  
#>  1     1 Bitcoin  BTC    bitc~ NA      NA      NA      2022-10-04 2.01e+4 3.41e10    9.60  6.11e-1  2.66     5.28    1.40e+0 -1.17e+1 -1.13    3.86e11  40.1   4.23e11 NA     
#>  2    52 XRP      XRP    xrp   NA      NA      NA      2022-10-04 4.83e-1 2.25e 9   24.3   1.05e+0  5.58     8.13    4.59e+1  3.12e+1 47.6     2.41e10   2.50  4.83e10 NA     
#>  3    74 Dogecoin DOGE   doge~ NA      NA      NA      2022-10-04 6.42e-2 6.27e 8  195.    3.24e-1  6.46     6.22    1.56e+0 -6.35e+0 -6.28    8.51e 9   0.884 8.51e 9 NA     
#>  4   825 Tether   USDT   teth~ NA      NA      NA      2022-10-04 1.00e+0 4.30e10    4.51  9.75e-4  0.0118   0.0170  1.26e-2  7.77e-3  0.105   6.80e10   7.06  7.02e10 NA     
#>  5  1027 Ethereum ETH    ethe~ NA      NA      NA      2022-10-04 1.35e+3 9.82e 9   -9.20  3.01e-1  2.46     2.25   -1.37e+1 -1.88e+1 16.8     1.66e11  17.2   1.66e11 NA     
#>  6  1839 BNB      BNB    bnb   NA      NA      NA      2022-10-04 2.96e+2 7.44e 8    3.08  6.63e-1  2.93     8.77    6.14e+0 -5.26e+0 24.0     4.78e10   4.96  5.92e10 NA     
#>  7  2010 Cardano  ADA    card~ NA      NA      NA      2022-10-04 4.34e-1 4.33e 8   -9.86  4.62e-1  1.65    -1.86   -1.33e+1 -1.44e+1 -5.51    1.49e10   1.54  1.95e10 NA     
#>  8  3408 USD Coin USDC   usd-~ NA      NA      NA      2022-10-04 1.00e+0 3.62e 9  -20.3  -2.03e-3 -0.00558 -0.0118 -2.85e-3 -1.32e-3 -0.00928 4.69e10   4.87  4.69e10 NA     
#>  9  4687 Binance~ BUSD   bina~ NA      NA      NA      2022-10-04 1.00e+0 6.65e 9    2.96  3.65e-2 -0.00872 -0.0715 -9.21e-3  5.15e-3  0.0532  2.10e10   2.18  2.10e10 NA     
#> 10  5426 Solana   SOL    sola~ NA      NA      NA      2022-10-04 3.42e+1 7.29e 8   14.2   6.47e-1  3.75     4.39    7.76e+0 -1.36e+1 -6.43    1.21e10   1.26  1.75e10 NA     
#> # ... with 2 more variables: USD_market_cap_by_total_supply <dbl>, USD_last_updated <chr>, and abbreviated variable names 1: self_reported_circulating_supply,
#> #   2: self_reported_market_cap, 3: tvl_ratio, 4: last_updated, 5: USD_price, 6: USD_volume_24h, 7: USD_volume_change_24h, 8: USD_percent_change_1h,
#> #   9: USD_percent_change_24h, *: USD_percent_change_7d, *: USD_percent_change_30d, *: USD_percent_change_60d, *: USD_percent_change_90d, *: USD_market_cap,
#> #   *: USD_market_cap_dominance, *: USD_fully_diluted_market_cap
```

Last and least, one can get information on exchanges. For this download a list of active/inactive/untracked exchanges using `exchange_list()`:


```r
exchanges <- exchange_list(only_active=TRUE)
exchanges
#> # A tibble: 527 x 6
#>       id name         slug         is_active first_historical_data last_historical_data
#>    <int> <chr>        <chr>            <int> <date>                <date>              
#>  1    16 Poloniex     poloniex             1 2018-04-26            2022-10-04          
#>  2    21 BTCC         btcc                 1 2018-04-26            2022-10-04          
#>  3    22 Bittrex      bittrex              1 2018-04-26            2022-10-04          
#>  4    24 Kraken       kraken               1 2018-04-26            2022-10-04          
#>  5    34 Bittylicious bittylicious         1 2018-04-26            2022-10-04          
#>  6    36 CEX.IO       cex-io               1 2018-04-26            2022-10-04          
#>  7    37 Bitfinex     bitfinex             1 2018-04-26            2022-10-04          
#>  8    42 HitBTC       hitbtc               1 2018-04-26            2022-10-04          
#>  9    50 EXMO         exmo                 1 2018-04-26            2022-10-04          
#> 10    61 Okcoin       okcoin               1 2018-04-26            2022-10-04          
#> # ... with 517 more rows
```

and then download information on "binance" and "kraken":


```r
ex_info <- exchange_info(exchanges %>% filter(slug %in% c('binance','kraken')), finalWait=FALSE)
#> > Scraping exchange info
#> 
#> Scraping exchanges from  https://web-api.coinmarketcap.com/v1/exchange/info?id=24,270  with  60  characters!
#> > Processing exchange info
#> 
ex_info
#> # A tibble: 2 x 19
#>      id name    slug    description             notice logo  type  date_~1 is_hi~2 is_re~3 maker~4 taker~5 spot_~6 spot_volume_last_~7 weekl~8 tags  urls     count~9 fiats   
#> * <int> <chr>   <chr>   <chr>                   <chr>  <chr> <chr> <chr>     <int> <lgl>     <dbl>   <dbl>   <dbl> <dttm>                <int> <lgl> <list>   <lgl>   <list>  
#> 1    24 Kraken  kraken  "## What Is Kraken?\n\~ ""     http~ ""    2011-0~       0 NA         0.02    0.05 6.16e 8 2022-10-04 18:55:16  1.07e6 NA    <tibble> NA      <tibble>
#> 2   270 Binance binance "## What Is Binance?\n~ "Bina~ http~ ""    2017-0~       0 NA         0.02    0.04 1.45e10 2022-10-04 18:55:16  1.70e7 NA    <tibble> NA      <tibble>
#> # ... with abbreviated variable names 1: date_launched, 2: is_hidden, 3: is_redistributable, 4: maker_fee, 5: taker_fee, 6: spot_volume_usd, 7: spot_volume_last_updated,
#> #   8: weekly_visits, 9: countries
```

Then we can access information on the fee structure,


```r
ex_info %>% select(contains("fee"))
#> # A tibble: 2 x 2
#>   maker_fee taker_fee
#>       <dbl>     <dbl>
#> 1      0.02      0.05
#> 2      0.02      0.04
```

the amount of cryptocurrencies being traded (in USD)


```r
ex_info %>% select(contains("spot"))
#> # A tibble: 2 x 2
#>   spot_volume_usd spot_volume_last_updated
#>             <dbl> <dttm>                  
#> 1      615726720. 2022-10-04 18:55:16     
#> 2    14543787127. 2022-10-04 18:55:16
```
or the fiat currencies allowed:


```r
ex_info %>% select(slug,fiats) %>% tidyr::unnest(fiats)
#> # A tibble: 53 x 2
#>    slug    value
#>    <chr>   <chr>
#>  1 kraken  USD  
#>  2 kraken  EUR  
#>  3 kraken  GBP  
#>  4 kraken  CAD  
#>  5 kraken  JPY  
#>  6 kraken  CHF  
#>  7 kraken  AUD  
#>  8 binance AED  
#>  9 binance ARS  
#> 10 binance AUD  
#> # ... with 43 more rows
```

### Author/License

- **Sebastian Stöckl** - Package Creator, Modifier & Maintainer - [sstoeckl on github](https://github.com/sstoeckl)

This project is licensed under the MIT License - see the
<license.md> file for details</license.md>

### Acknowledgments

- Thanks to the team at <https://coinmarketcap.com> for the great work they do, especially to [Alice Liu (Research Lead)](https://www.linkedin.com/in/alicejingliu/) and [Aaron K.](https://www.linkedin.com/in/aaroncwk/) for their support with regard to information on delistings.
- Thanks to Jesse Vent for providing the (not fully research compatible) [`crypto`](https://github.com/JesseVent/crypto)-package that inspired this package.

