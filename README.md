
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

First we load the `crypto2`-package and download the set of active coins
from <https://coinmarketcap.com> (additionally one could load delisted
coins with `only_Active=FALSE` as well as untracked coins with
`add_untracked=TRUE`).

``` r
library(crypto2)
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
```

Next we download information on the first three coins from that list.

``` r
# retrieve information for all (the first 3) of those coins
coin_info <- crypto_info(coins,limit=3)
#> > Scraping crypto info
#> 
#> > Processing historical crypto data
#> 

# and give the first two lines of information per coin
coin_info
#> # A tibble: 3 x 19
#>      id name   symbol category description      slug  logo      subreddit notice
#>   <int> <chr>  <chr>  <chr>    <chr>            <chr> <chr>     <chr>     <chr> 
#> 1     1 Bitco… BTC    coin     "## **What Is B… bitc… https://… bitcoin   ""    
#> 2     2 Litec… LTC    coin     "## What Is Lit… lite… https://… litecoin  ""    
#> 3     3 Namec… NMC    coin     "Namecoin (NMC)… name… https://… namecoin  ""    
#> # … with 10 more variables: date_added <chr>, twitter_username <chr>,
#> #   is_hidden <int>, date_launched <lgl>,
#> #   self_reported_circulating_supply <lgl>, self_reported_tags <lgl>,
#> #   status <dttm>, tags <list>, urls <list>, platform <lgl>
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
#> 2 bitcoin  paradigm-xzy-screener
#> 3 litecoin mineable             
#> 4 litecoin binance-chain        
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
#>   timestamp           slug      id name   symbol ref_cur    open    high     low
#>   <dttm>              <chr>  <int> <chr>  <chr>  <chr>     <dbl>   <dbl>   <dbl>
#> 1 2021-01-02 23:59:59 bitco…     1 Bitco… BTC    USD     2.94e+4 3.32e+4 2.91e+4
#> 2 2021-01-03 23:59:59 bitco…     1 Bitco… BTC    USD     3.21e+4 3.46e+4 3.21e+4
#> 3 2021-01-02 23:59:59 litec…     2 Litec… LTC    USD     1.26e+2 1.40e+2 1.24e+2
#> 4 2021-01-03 23:59:59 litec…     2 Litec… LTC    USD     1.37e+2 1.64e+2 1.36e+2
#> 5 2021-01-02 23:59:59 namec…     3 Namec… NMC    USD     4.51e-1 5.10e-1 4.15e-1
#> 6 2021-01-03 23:59:59 namec…     3 Namec… NMC    USD     4.26e-1 5.14e-1 4.25e-1
#> # … with 7 more variables: close <dbl>, volume <dbl>, market_cap <dbl>,
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
#>  8  2788 Czech Koruna         Kč    CZK   
#>  9  2789 Danish Krone         kr    DKK   
#> 10  2790 Euro                 €     EUR   
#> # … with 83 more rows
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
#>    timestamp           slug      id name  symbol ref_cur    open    high     low
#>    <dttm>              <chr>  <int> <chr> <chr>  <chr>     <dbl>   <dbl>   <dbl>
#>  1 2021-01-02 23:59:43 bitco…     1 Bitc… BTC    BTC     1   e+0 1.00e+0 9.99e-1
#>  2 2021-01-03 23:59:41 bitco…     1 Bitc… BTC    BTC     1   e+0 1.00e+0 1.00e+0
#>  3 2021-01-02 23:59:06 bitco…     1 Bitc… BTC    EUR     2.42e+4 2.73e+4 2.40e+4
#>  4 2021-01-03 23:59:06 bitco…     1 Bitc… BTC    EUR     2.65e+4 2.85e+4 2.64e+4
#>  5 2021-01-02 23:59:43 litec…     2 Lite… LTC    BTC     4.30e-3 4.24e-3 4.23e-3
#>  6 2021-01-03 23:59:41 litec…     2 Lite… LTC    BTC     4.26e-3 4.93e-3 4.18e-3
#>  7 2021-01-02 23:59:06 litec…     2 Lite… LTC    EUR     1.04e+2 1.16e+2 1.02e+2
#>  8 2021-01-03 23:59:06 litec…     2 Lite… LTC    EUR     1.13e+2 1.34e+2 1.12e+2
#>  9 2021-01-02 23:59:43 namec…     3 Name… NMC    BTC     1.54e-5 1.57e-5 1.31e-5
#> 10 2021-01-03 23:59:41 namec…     3 Name… NMC    BTC     1.32e-5 1.52e-5 1.32e-5
#> 11 2021-01-02 23:59:06 namec…     3 Name… NMC    EUR     3.71e-1 4.21e-1 3.41e-1
#> 12 2021-01-03 23:59:06 namec…     3 Name… NMC    EUR     3.51e-1 4.24e-1 3.50e-1
#> # … with 7 more variables: close <dbl>, volume <dbl>, market_cap <dbl>,
#> #   time_open <dttm>, time_close <dttm>, time_high <dttm>, time_low <dttm>
```

Last and least, one can get information on exchanges. For this download
a list of active/inactive/untracked exchanges using `exchange_list()`:

``` r
exchanges <- exchange_list(only_active=TRUE)
exchanges
#> # A tibble: 381 x 6
#>       id name       slug       is_active first_historical_da… last_historical_d…
#>    <int> <chr>      <chr>          <int> <date>               <date>            
#>  1    16 Poloniex   poloniex           1 2018-04-26           2021-06-24        
#>  2    22 Bittrex    bittrex            1 2018-04-26           2021-06-24        
#>  3    24 Kraken     kraken             1 2018-04-26           2021-06-24        
#>  4    32 Bleutrade  bleutrade          1 2018-04-26           2021-06-24        
#>  5    34 Bittylici… bittylici…         1 2018-04-26           2021-06-24        
#>  6    36 CEX.IO     cex-io             1 2018-04-26           2021-06-24        
#>  7    37 Bitfinex   bitfinex           1 2018-04-26           2021-06-24        
#>  8    42 HitBTC     hitbtc             1 2018-04-26           2021-06-24        
#>  9    50 EXMO       exmo               1 2018-04-26           2021-06-24        
#> 10    61 Okcoin     okcoin             1 2018-04-26           2021-06-24        
#> # … with 371 more rows
```

and then download information on “binance” and “kraken”:

``` r
ex_info <- exchange_info(exchanges %>% filter(slug %in% c('binance','kraken')))
#> > Scraping crypto info
#> 
#> > Processing historical crypto data
#> 
ex_info
#> # A tibble: 2 x 19
#>      id name   slug   description notice   logo    type  date_launched is_hidden
#>   <int> <chr>  <chr>  <lgl>       <chr>    <chr>   <chr> <chr>             <int>
#> 1    24 Kraken kraken NA          ""       https:… ""    2011-07-28T0…         0
#> 2   270 Binan… binan… NA          "Binanc… https:… ""    2017-07-14T0…         0
#> # … with 10 more variables: is_redistributable <lgl>, maker_fee <dbl>,
#> #   taker_fee <dbl>, spot_volume_usd <dbl>, spot_volume_last_updated <dttm>,
#> #   status <dttm>, tags <lgl>, urls <list>, countries <lgl>, fiats <list>
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
#> 1      988755413. 2021-06-24 21:40:15     
#> 2    18258047855. 2021-06-24 21:40:15
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
#> # … with 43 more rows
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
