[README.md](https://github.com/user-attachments/files/33845593/README.md)
# Gravity Model of International Trade, 1950–2016

An empirical study of what drives bilateral trade, using roughly 410,000 country-pair-year observations. It estimates structural gravity models with high-dimensional fixed effects, tracks how the effect of distance on trade has changed over seven decades, and shows how omitting economic size biases simple estimates.

Estimation in Stata (`reghdfe`, `estout`), with tables exported to LaTeX. The README figure is drawn in Python (`matplotlib`).

## Key findings

- **Distance matters a lot.** With exporter-year and importer-year fixed effects, the distance elasticity is **−1.55**: a 10% increase in distance between two countries is associated with about 15% less trade.
- **Sea routes carry part of that cost.** Adding maritime distance lowers the geographic distance elasticity to −1.18, with sea distance itself at −0.39. This suggests that shipping geography and port access account for a meaningful share of distance-related trade costs.
- **The distance puzzle.** Year-by-year estimates show the effect of distance roughly **doubled in magnitude**, from about −0.9 in the 1950s to about −1.8 by the late 2000s, despite large declines in transport costs over the same period.
- **Omitted-variable bias in practice.** In 2016 U.S. data, regressing trade on distance alone gives a slope of −0.47. Netting out partner GDP moves it to −1.67, because the largest U.S. trading partners include both close neighbors (Canada, Mexico) and large, distant economies (China, Japan, Germany).

## Results

| | (1) No FE | (2) Country + year FE | (3) Country-year FE | (4) + Sea distance |
|---|---|---|---|---|
| Log GDP (origin) | 1.10 (0.01) | 0.99 (0.03) | | |
| Log GDP (destination) | 1.01 (0.01) | 0.96 (0.03) | | |
| Log distance | −1.36 (0.02) | −1.56 (0.02) | −1.55 (0.02) | −1.18 (0.04) |
| Log sea distance | | | | −0.39 (0.05) |
| R² | 0.692 | 0.781 | 0.809 | 0.810 |
| Observations | 394,874 | 394,874 | 410,356 | 410,356 |

Dependent variable: log of total bilateral trade (exports plus imports). Standard errors clustered by country pair in parentheses. GDP terms are absorbed by the country-year fixed effects in columns (3) and (4).

## Method

The baseline gravity equation is

$$\ln X_{ijt} = \beta_1 \ln Y_{it} + \beta_2 \ln Y_{jt} + \beta_3 \ln \text{dist}_{ij} + \varepsilon_{ijt}$$

where $X_{ijt}$ is trade between countries $i$ and $j$ in year $t$ and $Y$ is GDP. The specifications add fixed effects in steps:

1. **No fixed effects**: pooled OLS.
2. **Country and year fixed effects**: control for time-invariant country characteristics and global shocks.
3. **Origin-year and destination-year fixed effects**: absorb each country's multilateral resistance (its overall remoteness from all trading partners) in every year, which theory says must be controlled for to identify bilateral trade costs.
4. **Adds sea distance** to separate maritime from overall geographic distance.

The time-varying analysis interacts log distance with a full set of year dummies under the specification (3) fixed effects, giving a separate distance elasticity for each year with 95% confidence intervals.

## Data

- **Penn World Table 11.0** (`pwt110.dta`): real GDP (`rgdpe`) by country and year. Available from the [Groningen Growth and Development Centre](https://www.rug.nl/ggdc/productivity/pwt/).
- **Bilateral trade data** (`trade_data.dta`): country-pair exports, imports, geographic distance, and sea distance for 1950–2016, provided as course data.

Data files are not included in this repository. Place them in `data/` to run the code. The do-file expects the original, unfiltered trade panel and stops with an error if it finds a filtered copy.

## Repository structure

```
gravity-model/
├── code/
│   ├── gravity_model.do      # data build, estimation, tables, Stata figures
│   └── us_bias_figure.py     # README figure for the U.S. cross-section
├── data/                     # not tracked; see Data
├── output/
│   ├── tables/               # LaTeX regression table, CSV outputs
│   └── figures/              # PNG figures
└── README.md
```

## How to run

1. Put `pwt110.dta` and `trade_data.dta` in `data/`.
2. Open `code/gravity_model.do` and set `global root` to the project folder.
3. Run the do-file in Stata 16 or later. Missing packages (`reghdfe`, `ftools`, `estout`) install automatically from SSC.
4. From the project folder, run `python code/us_bias_figure.py` (requires `pandas`, `numpy`, `matplotlib`).

## Limitations and extensions

- **Zero trade flows are dropped.** The log-linear model requires positive trade, so country pairs that don't trade are excluded. Santos Silva and Tenreyro (2006) show that this, along with heteroskedasticity, can bias OLS gravity estimates. A natural extension is to re-estimate with Poisson pseudo-maximum likelihood (`ppmlhdfe`) on the full sample including zeros.
- **Pair fixed effects.** Adding country-pair fixed effects would control for all time-invariant bilateral factors (common language, colonial ties, borders) in the time-varying analysis.
- **The U.S. cross-section** imposes a unit GDP elasticity when adjusting for partner size. It illustrates the bias rather than providing a structural estimate.

## Author

Rob Jaleshgari
