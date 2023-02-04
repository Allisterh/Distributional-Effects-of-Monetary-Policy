
//fed funds
import delimited "/Users/saul/Downloads/FEDFUNDS-8.csv", clear

gen ddate = daily(date,"YMD")
format ddate %td

gen month=month(ddate)
gen year=year(ddate)

gen yq = qofd(ddate)
format yq %tq

collapse (mean) fedfunds, by(year)

save "/Users/saul/Downloads/FEDFUNDSPSID1996.dta", replace

use "/Users/saul/Downloads/mpsorth.dta", clear

gen year=year(Date)


gen mps_orth = real(MPS)
collapse (sum) mps_orth, by(year)


save "/Users/saul/Downloads/surprise1996.dta", replace

use "/Users/saul/Downloads/surprise1996.dta", clear

merge 1:1 year using "/Users/saul/Downloads/FEDFUNDSPSID1996.dta"
keep if _merge == 3
drop _merge


save "/Users/saul/Downloads/surprise1996.dta", replace 

use "/Users/saul/Downloads/newdata.dta", clear

merge m:1 year using "/Users/saul/Downloads/surprise1996.dta"
keep if _merge == 3
drop _merge

keep if year <= 1996

sort id year
by id: gen pChange = (wages[_n+1] - wages)/wages
xtset id year


winsor pChange, p(0.05) gen(wpchange)
winsor wages, p(0.05) gen(wincome)

sort year
egen quant=xtile(wincome), n(3) by(year)

regress fedfunds mps_orth
predict ffhat

save "/Users/saul/Downloads/J313773/psid1996male.dta", replace

import delimited "/Users/saul/Downloads/GDPC1.csv", clear
gen ddate = daily(date,"YMD")
format ddate %td
gen year=year(ddate)
gen gdpG = gdpc1_pca / 100
keep year gdpG
sort year
gen lagG = gdpG[_n -1]
drop gdpG
save "/Users/saul/Downloads/GDP.dta", replace

use "/Users/saul/Downloads/J313773/psid1996male.dta", clear
merge m:1 year using "/Users/saul/Downloads/GDP.dta"

xtreg wpchange i.quant##c.ffhat, fe 

xtivreg wpchange (fedfunds = mps_orth), fe

