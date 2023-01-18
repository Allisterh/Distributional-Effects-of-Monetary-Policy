//fed funds
import delimited "/Users/saul/Downloads/FEDFUNDS-8.csv", clear

gen ddate = daily(date,"YMD")
format ddate %td

gen month=month(ddate)
gen year=year(ddate)

gen yq = qofd(ddate)
format yq %tq

collapse fedfunds month year, by(yq)

gen quarter = ceil(month/3)
drop yq month

save "/Users/saul/Downloads/fedfunds19902019.dta", replace

clear
//census 1990-2000
import excel "/Users/saul/Downloads/POP1990.xlsx", sheet("POPEST1990") firstrow
keep fips year tot_pop
save "/Users/saul/Downloads/Census1990.dta", replace

clear
//census 2000-2010
import excel "/Users/saul/Downloads/POP2000.xlsx", sheet("POPEST2000") firstrow
keep fips year tot_pop
save "/Users/saul/Downloads/census2000.dta", replace

//append 1990-2010
use "/Users/saul/Downloads/Census1990.dta"
append using "/Users/saul/Downloads/census2000.dta"
save "/Users/saul/Downloads/county19902010.dta", replace

//census 2010 - 2019
import delimited "/Users/saul/Downloads/co-est2019-alldata.csv", clear

tostring state, gen(fipsstate)
tostring county, gen(fipscounty)

//get leading zeros
gen fipsS = "0" + fipsstate if strlen(fipsstate) == 1 
replace fipsS = fipsstate if strlen(fipsstate) == 2

gen fipsC = "00" + fipscounty if strlen(fipscounty) == 1 
replace fipsC = "0" + fipscounty if strlen(fipscounty) == 2 
replace fipsC = fipscounty if strlen(fipscounty) == 3 

//gen fips code
gen fips = fipsS + fipsC

keep fips popestimate2010 popestimate2011 popestimate2012 popestimate2013 popestimate2014 popestimate2015 popestimate2016 popestimate2017 popestimate2018 popestimate2019

//wide to long
reshape long popestimate, i(fips) j(year)
gen tot_pop = popestimate
drop popestimate
save "/Users/saul/Downloads/county20102019.dta", replace

//append 1990-2010 to 2010-2019
use "/Users/saul/Downloads/county19902010.dta",clear 
append using "/Users/saul/Downloads/county20102019.dta"

egen hh = group(fips year)
sort hh
quietly by hh:  gen dup = cond(_N==1,0,_n)
drop if dup > 1
drop hh dup

save "/Users/saul/Downloads/county19902020.dta", replace


// aggregated qwi at county level (use emp to calc ratio)
import delimited "/Users/saul/Downloads/qwi_876ffb24f6d241eb84d367d8e6b26d95.csv", clear 
//leading zeros
tostring geography, gen(fips)
replace fips = "0" + fips if strlen(fips) == 4 

// merge emp counts
merge m:1 fips year using "/Users/saul/Downloads/county19902020.dta"


// drop not merged
keep if _merge == 3
drop _merge

//gen emp ratio
gen empratio = emptotal / tot_pop
keep fips year quarter empratio
save "/Users/saul/Downloads/qwi_county.dta", replace

//qwi dissaggregated with earns, emp, etc
import delimited "/Users/saul/Downloads/qwi_2af3eef2a42b43e3af2e2583e17a01e9.csv", clear 
tostring geography, gen(fips)
replace fips = "0" + fips if strlen(fips) == 4 

// some reason there are fips in disagg that aren't present in agg
merge m:1 fips year quarter using "/Users/saul/Downloads/qwi_county.dta"
keep if _merge == 3
drop _merge

keep fips industry race year quarter earnbeg earnhiras earnhirns earns earnseps payroll emp empend emps empspv emptotal empratio

merge m:1 year quarter using "/Users/saul/Downloads/fedfunds19902019.dta"
keep if _merge == 3
drop _merge



egen indByQuarter = group(industry year quarter)
// egen indByYear = group(industry year)

egen fipsByIndustry = group(fips industry)

gen counter = quarter + ((year - 2010)*4)

sort fips industry race counter
by fips industry race: gen empG = (earnbeg[_n + 8] - earnbeg)/earnbeg

// sort fips industry race counter
// by fips industry race: gen lempG = log(emp[_n + 6]) - log(emp)
sort fips industry race counter
by fips industry race: gen newempratio = empratio[_n - 1]

// gen ratioFF = newempratio * fedfunds


// merge m:1 year quarter using "/Users/saul/Downloads/mpssurprise"
merge m:1 year quarter using "/Users/saul/Downloads/quartershocks.dta"

regress fedfunds mps_orth
predict fredfundshat

// gen surpriseEmp = fredfundshat * empratio
gen surpriseEmplag = fredfundshat * newempratio
winsor empG, p(0.05) gen(newemp)

save "/Users/saul/Downloads/qwi_disagg.dta", replace
// reghdfe newemp surpriseEmplag newempratio, cluster(cbsa) absorb(indByQuarter fipsByIndustry)

keep if race == "A1"
reghdfe newemp surpriseEmplag newempratio, cluster(fips) absorb(indByQuarter fipsByIndustry)
outreg2 using censusresults, tex replace

use "/Users/saul/Downloads/qwi_disagg.dta", clear
keep if race == "A2"
reghdfe newemp surpriseEmplag newempratio, cluster(fips) absorb(indByQuarter fipsByIndustry)
outreg2 using censusresults, tex append



// reghdfe empG ratioFF newempratio, cluster(industry) absorb(indByYear fipsByIndustry)


// reghdfe empG surpriseEmp surpriseEmplag newempratio, cluster(industry) absorb(indByYear fipsByIndustry)

// use "/Users/saul/Downloads/qwi_disagg.dta", clear
//
// keep if race == "A2"
// reghdfe empG ratioFF newempratio, cluster(industry) absorb(indByYear fipsByIndustry)
// reghdfe empG surpriseEmplag newempratio, cluster(industry) absorb(indByYear fipsByIndustry)



