[![codecov](https://codecov.io/gh/sstoeckl/crypto2/branch/master/graph/badge.svg)](https://codecov.io/gh/sstoeckl/crypto2)

## Historical Cryptocurrency Prices For active and dead Tokens!

This is a modification of the original crypto package by [jesse vent](https://github.com/JesseVent/crypto). It allows to additionally retrieve historic (and possibly dead) coins for research puposes

- Retrieves historical crypto currency data `crypto_history()`
- Retrieves list of all active/dead crypto currencies `crypto_list()`

### Prerequisites

Below are the high level dependencies for the package to install correctly.

```
R (>= 3.4.0), rvest, xml2

# Ubuntu 
sudo apt install libxml2-dev libcurl4-openssl-dev libssl-dev
```

### Installing

The _crypto2_ R-package is installable through CRAN or through github.

# Installing via Github
devtools::install_github("sstoeckl/crypto2")
```

## Package Usage

```R
library(crypto2)

# List all active coins
coins <- coin_list()

# retrieve historical data for all (the first 10) of them
coin_hist <- crypto_history(coins, limit=10, start_date="20200101")

```

### Author/License

- **Jesse Vent** - Package Creator - [jessevent](https://github.com/jessevent)
- **Sebastian Stöckl** - Package Modificator & Maintainer - [sstoeckl](https://github.com/sstoeckl)

This project is licensed under the MIT License - see the
<license.md> file for details</license.md>

### Acknowledgments

- Thanks to the team at <https://coinmarketcap.com> for the great work they do
- Thanks to Jesse Vent for providing the original (nut fully research compatible) crypto package
