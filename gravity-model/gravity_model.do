/*==============================================================================
  Gravity Model of International Trade, 1950-2016
  Author: Rob Jaleshgari

  Estimates log-linear gravity equations for bilateral trade using Penn World
  Table 11.0 GDP data with progressively richer fixed effects, traces the
  distance elasticity year by year, and illustrates omitted-variable bias in a
  2016 U.S. cross-section.

  Requires: reghdfe, ftools, estout (installed automatically if missing)
  Inputs:   data/pwt110.dta, data/trade_data.dta
  Outputs:  output/tables/gravity_table.tex
            output/tables/distance_elasticity_by_year.csv
            output/tables/us_2016.csv
            output/figures/*.png
            output/gravity.log
==============================================================================*/

clear all
set more off
version 16

* ---- Project root: set this to the folder that contains data/ and code/ ----
global root "~/Documents/gravity-model"
cd "$root"

cap mkdir "output"
cap mkdir "output/tables"
cap mkdir "output/figures"

cap log close
log using "output/gravity.log", replace text

* ---- Dependencies -----------------------------------------------------------
foreach pkg in ftools reghdfe estout {
    cap which `pkg'
    if _rc ssc install `pkg', replace
}

set scheme s1color


/*------------------------------------------------------------------------------
  1. BUILD THE ANALYSIS PANEL
------------------------------------------------------------------------------*/

* GDP of the origin (reporter) country
use countrycode year rgdpe using "data/pwt110.dta", clear
rename (countrycode rgdpe) (i gdp_i)
tempfile gdp_i
save `gdp_i'

* GDP of the destination (partner) country
use countrycode year rgdpe using "data/pwt110.dta", clear
rename (countrycode rgdpe) (j gdp_j)
tempfile gdp_j
save `gdp_j'

* Bilateral trade flows
use "data/trade_data.dta", clear

* Guard against running on a filtered or previously processed copy of the data
quietly count
if r(N) < 10000 {
    display as error "data/trade_data.dta has only " r(N) " rows; expected the full bilateral panel."
    display as error "It may have been saved after filtering. Restore the original file and rerun."
    exit 459
}

cap rename t year
keep if inrange(year, 1950, 2016)

merge m:1 i year using `gdp_i', keep(match) nogenerate
merge m:1 j year using `gdp_j', keep(match) nogenerate


/*------------------------------------------------------------------------------
  2. VARIABLES
------------------------------------------------------------------------------*/

* Total bilateral trade; log-linear model requires strictly positive flows
gen total_trade = exports + imports
keep if total_trade > 0 & !missing(total_trade)

gen ln_trade = ln(total_trade)
gen ln_gdp_i = ln(gdp_i)
gen ln_gdp_j = ln(gdp_j)
* ln_dist and ln_seadist are already in logs in the source data

* Numeric identifiers for fixed effects and clustering
encode i, gen(id_i)
encode j, gen(id_j)
egen pairid = group(id_i id_j)

label var ln_trade   "Log total trade"
label var ln_gdp_i   "Log GDP (origin)"
label var ln_gdp_j   "Log GDP (destination)"
label var ln_dist    "Log distance"
label var ln_seadist "Log sea distance"


/*------------------------------------------------------------------------------
  3. GRAVITY ESTIMATES
------------------------------------------------------------------------------*/

eststo clear

* (1) Baseline OLS, no fixed effects
eststo eq1: reg ln_trade ln_gdp_i ln_gdp_j ln_dist, vce(cluster pairid)

* (2) Origin, destination, and year fixed effects
eststo eq2: reghdfe ln_trade ln_gdp_i ln_gdp_j ln_dist, ///
    absorb(id_i id_j year) vce(cluster pairid)

* (3) Origin-year and destination-year fixed effects (multilateral resistance).
*     GDP is collinear with these fixed effects, so it is excluded.
eststo eq3: reghdfe ln_trade ln_dist, ///
    absorb(id_i#year id_j#year) vce(cluster pairid)

* (4) Adds sea distance
eststo eq4: reghdfe ln_trade ln_dist ln_seadist, ///
    absorb(id_i#year id_j#year) vce(cluster pairid)

* ---- Tables -----------------------------------------------------------------
local tabopts b(2) se(2) nostar label nodepvars noomitted nobaselevels ///
    noconstant nonotes order(ln_gdp_i ln_gdp_j ln_dist ln_seadist) ///
    mtitles("No FE" "Country + year FE" "Country-year FE" "+ Sea distance")

* Results window
esttab eq1 eq2 eq3 eq4, `tabopts' varwidth(24) ///
    stats(r2 N, fmt(%4.3f %9.0fc) labels("R-squared" "Observations")) ///
    title("Gravity Model Estimates") ///
    addnotes("Standard errors clustered by country pair in parentheses.")

* LaTeX
esttab eq1 eq2 eq3 eq4 using "output/tables/gravity_table.tex", ///
    replace booktabs `tabopts' ///
    stats(r2 N, fmt(%4.3f %9.0fc) labels("\$R^2\$" "Observations")) ///
    title("Gravity Model Estimates\label{tab:gravity}") ///
    addnotes("Standard errors clustered by country pair in parentheses." ///
             "Dependent variable: log of total bilateral trade (exports plus imports)." ///
             "Column (2) includes origin, destination, and year fixed effects." ///
             "Columns (3) and (4) include origin-year and destination-year fixed effects.")


/*------------------------------------------------------------------------------
  4. DISTANCE ELASTICITY OVER TIME
------------------------------------------------------------------------------*/

* One distance coefficient per year, with origin-year and destination-year FE
reghdfe ln_trade ibn.year#c.ln_dist, ///
    absorb(id_i#year id_j#year) vce(cluster pairid)

* Collect the year-specific coefficients and standard errors
tempname pf
tempfile coefs
postfile `pf' year b se using `coefs', replace
levelsof year if e(sample), local(years)
foreach y of local years {
    post `pf' (`y') (_b[`y'.year#c.ln_dist]) (_se[`y'.year#c.ln_dist])
}
postclose `pf'

preserve
use `coefs', clear
gen ci_lo = b - 1.96 * se
gen ci_hi = b + 1.96 * se
export delimited using "output/tables/distance_elasticity_by_year.csv", replace

twoway (rarea ci_lo ci_hi year, color(navy%20) lwidth(none)) ///
       (line b year, lcolor(navy) lwidth(medthick)), ///
    xtitle("Year") ytitle("Distance elasticity") ///
    xlabel(1950(5)2015) ylabel(, angle(horizontal)) ///
    title("Distance elasticity of trade, 1950-2016") ///
    legend(order(2 "Point estimate" 1 "95% CI") rows(1) position(6)) ///
    name(elasticity, replace)
graph export "output/figures/distance_elasticity_over_time.png", replace width(2000)
restore


/*------------------------------------------------------------------------------
  5. U.S. CROSS-SECTION, 2016: OMITTED-VARIABLE BIAS
------------------------------------------------------------------------------*/

preserve
keep if i_name == "United States" & year == 2016

* Imposes a unit GDP elasticity to net out partner size
gen ln_trade_adj = ln_trade - ln_gdp_j

* (a) Trade vs. partner GDP
quietly regress ln_trade ln_gdp_j
local s1 : display %5.3f _b[ln_gdp_j]
twoway (scatter ln_trade ln_gdp_j, mcolor(navy%60)) ///
       (lfit ln_trade ln_gdp_j, lcolor(maroon)), ///
    xtitle("Log GDP of partner country") ytitle("Log total trade") ///
    title("U.S. trade vs. partner GDP, 2016") ///
    note("Slope = `s1'") legend(off) name(us_gdp, replace)
graph export "output/figures/us_trade_vs_gdp_2016.png", replace width(2000)

* (b) Trade vs. distance, not controlling for partner GDP (biased)
quietly regress ln_trade ln_dist
local s2 : display %5.3f _b[ln_dist]
twoway (scatter ln_trade ln_dist, mcolor(navy%60)) ///
       (lfit ln_trade ln_dist, lcolor(maroon)), ///
    xtitle("Log distance") ytitle("Log total trade") ///
    title("U.S. trade vs. distance, 2016 (unadjusted)") ///
    note("Slope = `s2'") legend(off) name(us_dist_raw, replace)
graph export "output/figures/us_trade_vs_distance_unadjusted_2016.png", replace width(2000)

* (c) Size-adjusted trade vs. distance
quietly regress ln_trade_adj ln_dist
local s3 : display %5.3f _b[ln_dist]
twoway (scatter ln_trade_adj ln_dist, mcolor(navy%60)) ///
       (lfit ln_trade_adj ln_dist, lcolor(maroon)), ///
    xtitle("Log distance") ytitle("Log trade minus log partner GDP") ///
    title("U.S. trade vs. distance, 2016 (GDP-adjusted)") ///
    note("Slope = `s3'") legend(off) name(us_dist_adj, replace)
graph export "output/figures/us_trade_vs_distance_adjusted_2016.png", replace width(2000)

* Export the U.S. 2016 cross-section for the README figure (code/us_bias_figure.py)
export delimited j j_name ln_dist ln_trade ln_gdp_j ///
    using "output/tables/us_2016.csv", replace

display _n "U.S. 2016 slopes"
display "  Trade vs. partner GDP:          `s1'"
display "  Trade vs. distance (unadjusted): `s2'"
display "  Trade vs. distance (adjusted):   `s3'"
restore

log close
