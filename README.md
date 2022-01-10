
<!-- README.md is generated from README.Rmd. Please edit that file -->

# crypto2 <a href='https://github.com/sstoeckl/crypto2'><img src='man/figures/crypto2_hex.png' align="right" height="139" /></a>

<!-- badges: start -->

[![Project
Status](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)
[![Build
Status](https://travis-ci.org/sstoeckl/crypto2.svg?branch=master)](https://travis-ci.org/sstoeckl/crypto2)
[![CRAN
status](https://www.r-pkg.org/badges/version/crypto2)](https://CRAN.R-project.org/package=crypto2)
[![](http://cranlogs.r-pkg.org/badges/grand-total/crypto2)](https://cran.r-project.org/package=crypto2)
[![](http://cranlogs.r-pkg.org/badges/crypto2)](https://cran.r-project.org/package=crypto2)
[![](http://cranlogs.r-pkg.org/badges/last-week/crypto2)](https://cran.r-project.org/package=crypto2)
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

# Update

Since version 1.4.0 the package has been reworked to retrieve as many
assets as possible with one api call, as there is a new “feature”
introduced by CMC to send back the initially requested data for each api
call within 60 seconds. So one needs to wait 60s before calling the api
again.

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
website. It uses a variety of modification and web-scraping tools from
the `tidyverse` (especially `purrr`).

As this provides access not only to **active** coins but also to those
that have now been **delisted** and also those that are categorized as
**untracked**, including historical pricing information, this package
provides a valid basis for any **Asset Pricing Studies** based on crypto
currencies that require **survivorship-bias-free** information. In
addition to that, the package maintainer is currently working on also
providing **delisting returns** (similarly to CRSP for stocks) to also
eliminate the **delisting bias**.

## Package Usage

First we load the `crypto2`-package and download the set of active coins
from <https://coinmarketcap.com> (additionally one could load delisted
coins with `only_Active=FALSE` as well as untracked coins with
`add_untracked=TRUE`).

``` r
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

``` r
# retrieve information for all (the first 3) of those coins
coin_info <- crypto_info(coins,limit=3)
#> > Scraping crypto info
#> 
#> Scraping  https://web-api.coinmarketcap.com/v1/cryptocurrency/info?id=1,2,3  with  65  characters!
#> > Processing crypto info
#> 

# and give the first two lines of information per coin
coin_info
#> # A tibble: 3 x 18
#>      id name     symbol category description     slug   logo    subreddit notice
#> * <int> <chr>    <chr>  <chr>    <chr>           <chr>  <chr>   <chr>     <chr> 
#> 1     1 Bitcoin  BTC    coin     "## What Is Bi~ bitco~ https:~ bitcoin   ""    
#> 2     2 Litecoin LTC    coin     "## What Is Li~ litec~ https:~ litecoin  ""    
#> 3     3 Namecoin NMC    coin     "Namecoin (NMC~ namec~ https:~ namecoin  ""    
#> # ... with 9 more variables: date_added <chr>, twitter_username <chr>,
#> #   is_hidden <int>, date_launched <lgl>,
#> #   self_reported_circulating_supply <lgl>, tags <list>,
#> #   self_reported_tags <lgl>, urls <list>, platform <lgl>
```

In a next step we show the logos of the three coins as provided by
<https://coinmarketcap.com>.

<img src="https://s2.coinmarketcap.com/static/img/coins/64x64/1.png" width="5%" height="5%" style="display: block; margin: auto;" /><img src="https://s2.coinmarketcap.com/static/img/coins/64x64/2.png" width="5%" height="5%" style="display: block; margin: auto;" /><img src="https://s2.coinmarketcap.com/static/img/coins/64x64/3.png" width="5%" height="5%" style="display: block; margin: auto;" />

In addition we show tags provided by <https://coinmarketcap.com>.

``` r
coin_info %>% select(slug,tags) %>% tidyr::unnest(tags) %>% group_by(slug) %>% slice(1,n())
#> # A tibble: 6 x 2
#> # Groups:   slug [3]
#>   slug     tags               
#>   <chr>    <chr>              
#> 1 bitcoin  mineable           
#> 2 bitcoin  paradigm-portfolio 
#> 3 litecoin mineable           
#> 4 litecoin binance-smart-chain
#> 5 namecoin mineable           
#> 6 namecoin platform
```

Additionally: Here are some urls pertaining to these coins as provided
by <https://coinmarketcap.com>.

``` r
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

``` r
# retrieve historical data for all (the first 3) of them
coin_hist <- crypto_history(coins, limit=3, start_date="20210101", end_date="20210105")
#> > Scraping historical crypto data
#> 
#> > Processing historical crypto data
#> 

# and give the first two times of information per coin
coin_hist %>% group_by(slug) %>% slice(1:2)
#> # A tibble: 6 x 16
#> # Groups:   slug [3]
#>   timestamp              id slug   name   symbol ref_cur    open    high     low
#>   <dttm>              <int> <chr>  <chr>  <chr>  <chr>     <dbl>   <dbl>   <dbl>
#> 1 2021-01-01 23:59:59     1 bitco~ Bitco~ BTC    USD     2.90e+4 2.96e+4 2.88e+4
#> 2 2021-01-02 23:59:59     1 bitco~ Bitco~ BTC    USD     2.94e+4 3.32e+4 2.91e+4
#> 3 2021-01-01 23:59:59     2 litec~ Litec~ LTC    USD     1.25e+2 1.33e+2 1.23e+2
#> 4 2021-01-02 23:59:59     2 litec~ Litec~ LTC    USD     1.26e+2 1.40e+2 1.24e+2
#> 5 2021-01-01 23:59:59     3 namec~ Namec~ NMC    USD     4.39e-1 4.63e-1 4.32e-1
#> 6 2021-01-02 23:59:59     3 namec~ Namec~ NMC    USD     4.51e-1 5.10e-1 4.15e-1
#> # ... with 7 more variables: close <dbl>, volume <dbl>, market_cap <dbl>,
#> #   time_open <dttm>, time_close <dttm>, time_high <dttm>, time_low <dttm>
```

Alternatively, we could determine the price of these coins in other
currencies. A list of such currencies is available as `fiat_list()`

``` r
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
#>  7  2787 Chinese Yuan         ¥     CNY   
#>  8  2788 Czech Koruna         Kc    CZK   
#>  9  2789 Danish Krone         kr    DKK   
#> 10  2790 Euro                 €     EUR   
#> # ... with 83 more rows
```

So we download the time series again depicting prices in terms of
Bitcoin and Euro (note that multiple currencies can be given to
`convert`, separated by “,”).

``` r
# retrieve historical data for all (the first 3) of them
coin_hist2 <- crypto_history(coins, convert="BTC,EUR", limit=3, start_date="20210101", end_date="20210105")
#> > Scraping historical crypto data
#> 
#> > Processing historical crypto data
#> 

# and give the first two times of information per coin
coin_hist2 %>% group_by(slug,ref_cur) %>% slice(1:2)
#> # A tibble: 12 x 16
#> # Groups:   slug, ref_cur [6]
#>    timestamp              id slug   name  symbol ref_cur    open    high     low
#>    <dttm>              <int> <chr>  <chr> <chr>  <chr>     <dbl>   <dbl>   <dbl>
#>  1 2021-01-01 23:59:43     1 bitco~ Bitc~ BTC    BTC     1   e+0 1.00e+0 9.98e-1
#>  2 2021-01-02 23:59:43     1 bitco~ Bitc~ BTC    BTC     1   e+0 1.00e+0 9.99e-1
#>  3 2021-01-01 23:59:06     1 bitco~ Bitc~ BTC    EUR     2.37e+4 2.43e+4 2.36e+4
#>  4 2021-01-02 23:59:06     1 bitco~ Bitc~ BTC    EUR     2.42e+4 2.73e+4 2.40e+4
#>  5 2021-01-01 23:59:43     2 litec~ Lite~ LTC    BTC     4.30e-3 4.56e-3 4.27e-3
#>  6 2021-01-02 23:59:43     2 litec~ Lite~ LTC    BTC     4.30e-3 4.24e-3 4.23e-3
#>  7 2021-01-01 23:59:06     2 litec~ Lite~ LTC    EUR     1.02e+2 1.09e+2 1.01e+2
#>  8 2021-01-02 23:59:06     2 litec~ Lite~ LTC    EUR     1.04e+2 1.16e+2 1.02e+2
#>  9 2021-01-01 23:59:43     3 namec~ Name~ NMC    BTC     1.51e-5 1.58e-5 1.50e-5
#> 10 2021-01-02 23:59:43     3 namec~ Name~ NMC    BTC     1.54e-5 1.57e-5 1.31e-5
#> 11 2021-01-01 23:59:06     3 namec~ Name~ NMC    EUR     3.60e-1 3.80e-1 3.54e-1
#> 12 2021-01-02 23:59:06     3 namec~ Name~ NMC    EUR     3.71e-1 4.21e-1 3.41e-1
#> # ... with 7 more variables: close <dbl>, volume <dbl>, market_cap <dbl>,
#> #   time_open <dttm>, time_close <dttm>, time_high <dttm>, time_low <dttm>
```

Last and least, one can get information on exchanges. For this download
a list of active/inactive/untracked exchanges using `exchange_list()`:

``` r
exchanges <- exchange_list(only_active=TRUE)
exchanges
#> # A tibble: 454 x 6
#>       id name         slug         is_active first_historical_~ last_historical~
#>    <int> <chr>        <chr>            <int> <date>             <date>          
#>  1    16 Poloniex     poloniex             1 2018-04-26         2022-01-10      
#>  2    22 Bittrex      bittrex              1 2018-04-26         2022-01-10      
#>  3    24 Kraken       kraken               1 2018-04-26         2022-01-10      
#>  4    32 Bleutrade    bleutrade            1 2018-04-26         2021-10-04      
#>  5    34 Bittylicious bittylicious         1 2018-04-26         2022-01-10      
#>  6    36 CEX.IO       cex-io               1 2018-04-26         2022-01-10      
#>  7    37 Bitfinex     bitfinex             1 2018-04-26         2022-01-10      
#>  8    42 HitBTC       hitbtc               1 2018-04-26         2022-01-10      
#>  9    50 EXMO         exmo                 1 2018-04-26         2022-01-10      
#> 10    61 Okcoin       okcoin               1 2018-04-26         2022-01-10      
#> # ... with 444 more rows
```

and then download information on “binance” and “kraken”:

``` r
ex_info <- exchange_info(exchanges %>% filter(slug %in% c('binance','kraken')))
#> > Scraping exchange info
#> 
#> Scraping exchanges from  https://web-api.coinmarketcap.com/v1/exchange/info?id=24,270  with  60  characters!
#> > Processing exchange info
#> 
ex_info
#> # A tibble: 2 x 18
#>      id name    slug    description notice   logo  type  date_launched is_hidden
#> * <int> <chr>   <chr>   <lgl>       <chr>    <chr> <chr> <chr>             <int>
#> 1    24 Kraken  kraken  NA          ""       http~ ""    2011-07-28T0~         0
#> 2   270 Binance binance NA          "Binanc~ http~ ""    2017-07-14T0~         0
#> # ... with 9 more variables: is_redistributable <lgl>, maker_fee <dbl>,
#> #   taker_fee <dbl>, spot_volume_usd <dbl>, spot_volume_last_updated <dttm>,
#> #   tags <lgl>, urls <list>, countries <lgl>, fiats <list>
```

Then we can access information on the fee structure,

``` r
ex_info %>% select(contains("fee"))
#> # A tibble: 2 x 2
#>   maker_fee taker_fee
#>       <dbl>     <dbl>
#> 1     -0.02     0.075
#> 2      0.02     0.04
```

the amount of cryptocurrencies being traded (in USD)

``` r
ex_info %>% select(contains("spot"))
#> # A tibble: 2 x 2
#>   spot_volume_usd spot_volume_last_updated
#>             <dbl> <dttm>                  
#> 1     1292760024. 2022-01-10 19:30:16     
#> 2    18540127903. 2022-01-10 19:30:16
```

or the fiat currencies allowed:

``` r
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

-   **Sebastian Stöckl** - Package Creator, Modifier & Maintainer -
    [sstoeckl on github](https://github.com/sstoeckl)

This project is licensed under the MIT License - see the
&lt;license.md&gt; file for details&lt;/license.md&gt;

### Acknowledgments

-   Thanks to the team at <https://coinmarketcap.com> for the great work
    they do.
-   Thanks to Jesse Vent for providing the (not fully research
    compatible) [`crypto`](https://github.com/JesseVent/crypto)-package
    that inspired this package.
