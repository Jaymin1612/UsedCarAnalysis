*Importing data;
proc import datafile="autos_cleaned_2.csv" out=autos replace;
delimiter=',';
getnames=yes;
run;

*Drop the rows with missing data;
DATA auto2;
SET autos;

IF CMISS(OF _all_) THEN delete;

RUN;

*Creating dummy variables;
DATA auto;
SET auto2;

*We will require 1 dummy variable for AbTest, if dAbTest=1, Control, otherwise test;
dAbTest = (AbTest = 'control');

*We need 7 dummy variables for vehicleType. 
	Where, dvehicalType1 = 1, coupe	dvehicalType2 = 1, suv	dvehicalType3 = 1, luxury sedan
	       dvehicalType4 = 1, convertible	 dvehicalType5 = 1, bus	dvehicalTyp6 = 1, station_wagon
	       dvehicalType7 = 1, other		otherwise, vehicleType = non specified;
dvehicleType1 = (vehicleType = 'coupe');
dvehicleType2 = (vehicleType = 'suv');
dvehicleType3 = (vehicleType = 'luxury sedan');
dvehicleType4 = (vehicleType = 'convertible');
dvehicleType5 = (vehicleType = 'bus');
dvehicleType6 = (vehicleType = 'station_wagon');
dvehicleType7 = (vehicleType = 'other');

*We need 1 dummy variable for Gearbox, if dGearbox = 1, Automatic otherwise, dGearbox = 0, Manual.;
dGearbox = (Gearbox = 'Automatic');

*We need 1 dummy variable for FuelType. if dFuelType = 1, Diesel 	otherwise, Benzin;
dFuelType = (FuelType = 'Diesel');

*We need 2 dummy variables for NotRepairedDamage. If dNotRepairedDamage1 = 1, Yes	dNotRepairedDamage2 = 1, No
							otherwise NotRepairedDamage = null;
dNotRepairedDamage1 = (NotRepairedDamage = 'Yes');
dNotRepairedDamage2 = (NotRepairedDamage = 'No');

run;

*Removing outliers by IQR rule;
data auto_cleaning;
set auto;

price_IQR=1.5*(9292.5-1732.5); *1.5x(3 rd -1 st );
power_IQR=1.5*(156-86);
outlier_price=.;
outlier_power=.;

if Price>9292.5+price_IQR then outlier_price=1;
else outlier_price=0;

if Price=0 then delete;
if PowerPS=0 then delete;

if PowerPS>156+power_IQR then outlier_power=1;
else outlier_power=0;

if outlier_price=1 or outlier_power=1 then delete;

run;

*Taking 1000 observation;
proc surveyselect data=auto_cleaning method=srs n=1000 seed=495638
  out=auto;
run;
PROC PRINT;
RUN;


*Taking log for Price variable;
DATA auto;
SET auto_cleaning;
ln_price = log(Price);
RUN;

*Histogram of Price;
PROC UNIVARIATE DATA=auto NOPRINT;
HISTOGRAM ln_price / NORMAL;
RUN;

PROC CORR data=auto;
VAR ln_price dAbTest dvehicleType1 dvehicleType2 dvehicleType3 dvehicleType4 dvehicleType5
	dvehicleType6 dvehicleType7 YearOfRegistration dGearbox PowerPS Miles 
	MonthOfRegistration dFuelType dNotRepairedDamage1 dNotRepairedDamage2;

RUN;


*Fit the model 1;
PROC REG  data=auto PLOTS(MAXPOINTS=NONE);
MODEL ln_price = dAbTest dvehicleType1 dvehicleType2 dvehicleType3 dvehicleType4 dvehicleType5
	dvehicleType6 dvehicleType7 YearOfRegistration dGearbox PowerPS Miles 
	MonthOfRegistration dFuelType dNotRepairedDamage1 dNotRepairedDamage2;
RUN;


*Trying to take square root for Price;
DATA auto2;
set auto;
sqr_price = sqrt(Price);
RUN;

*Histogram of Price;
PROC UNIVARIATE DATA=auto2 NOPRINT;
HISTOGRAM sqr_price / NORMAL;
RUN;

PROC CORR data=auto2;
VAR sqr_price dAbTest dvehicleType1 dvehicleType2 dvehicleType3 dvehicleType4 dvehicleType5
	dvehicleType6 dvehicleType7 YearOfRegistration dGearbox PowerPS Miles 
	MonthOfRegistration dFuelType dNotRepairedDamage1 dNotRepairedDamage2;

RUN;


*Fit the model 1;
PROC REG  data=auto2;
MODEL sqr_price = dAbTest dvehicleType1 dvehicleType2 dvehicleType3 dvehicleType4 dvehicleType5
	dvehicleType6 dvehicleType7 YearOfRegistration dGearbox PowerPS Miles 
	MonthOfRegistration dFuelType dNotRepairedDamage1 dNotRepairedDamage2;
RUN;

*Fitting model 2 - Removing dGearbox;
PROC REG  data=auto2;
MODEL sqr_price = dAbTest dvehicleType1 dvehicleType2 dvehicleType3 dvehicleType4 dvehicleType5
	dvehicleType6 dvehicleType7 YearOfRegistration PowerPS Miles 
	MonthOfRegistration dFuelType dNotRepairedDamage1 dNotRepairedDamage2;
RUN; 

*Fitting model 3 - Removing dAbTest;
PROC REG  data=auto2;
MODEL sqr_price = dvehicleType1 dvehicleType2 dvehicleType3 dvehicleType4 dvehicleType5
	MonthOfRegistration dvehicleType6 dvehicleType7 YearOfRegistration PowerPS Miles dFuelType dNotRepairedDamage1;
RUN;

*Fitting model 4 - Removing dvehicleType7;
PROC REG  data=auto2;
MODEL sqr_price = dvehicleType1 dvehicleType2 dvehicleType3 dvehicleType4 dvehicleType5
	MonthOfRegistration dvehicleType6 YearOfRegistration PowerPS Miles dFuelType dNotRepairedDamage1;
RUN;

*Fitting model 5 - Removing MonthOfRegistration;
PROC REG  data=auto2;
MODEL sqr_price = dvehicleType1 dvehicleType2 dvehicleType3 dvehicleType4 dvehicleType5
	 dvehicleType6 YearOfRegistration PowerPS Miles dFuelType dNotRepairedDamage1;
RUN;
*After the step above ADJ R-SQ is 0.6823

*Finding Standardized coefficient;
PROC REG  data=auto2;
MODEL sqr_price = dvehicleType1 dvehicleType2 dvehicleType3 dvehicleType4 dvehicleType5
	 dvehicleType6 YearOfRegistration PowerPS Miles dFuelType dNotRepairedDamage1 / STB;
RUN;
*From the Standardized coefficient, PowerPS has strongest influence with 0.429 followed by Miles with -0.336;

*Finding multicollinearity;
PROC REG  data=auto2;
MODEL sqr_price = dvehicleType1 dvehicleType2 dvehicleType3 dvehicleType4 dvehicleType5
	 dvehicleType6 YearOfRegistration PowerPS Miles dFuelType dNotRepairedDamage1 / vif r;
PLOT student.*predicted;
PLOT student.*dvehicleType1 dvehicleType2 dvehicleType3 dvehicleType4 dvehicleType5
	dvehicleType6 YearOfRegistration PowerPS Miles dFuelType dNotRepairedDamage1;
PLOT npp.*student.;
RUN; 

*Removing outliers; 
DATA auto2;
SET auto2;
	IF (_n_ = 151) THEN DELETE;
	IF (_n_ = 193) THEN DELETE;
	IF (_n_ = 210) THEN DELETE;
	IF (_n_ = 312) THEN DELETE;
	IF (_n_ = 337) THEN DELETE;
	IF (_n_ = 379) THEN DELETE;
	IF (_n_ = 415) THEN DELETE;
	IF (_n_ = 582) THEN DELETE;
	IF (_n_ = 802) THEN DELETE;
	IF (_n_ = 848) THEN DELETE;
	IF (_n_ = 885) THEN DELETE;
	IF (_n_ = 907) THEN DELETE;
	IF (_n_ = 970) THEN DELETE;
RUN;

PROC REG  data=auto2;
MODEL sqr_price = dvehicleType1 dvehicleType2 dvehicleType3 dvehicleType4 dvehicleType5
	dvehicleType6 YearOfRegistration PowerPS Miles dFuelType dNotRepairedDamage1 / vif r;
RUN;

DATA auto2;
SET auto2;
	IF (_n_ = 604) THEN DELETE;
	IF (_n_ = 661) THEN DELETE;
	IF (_n_ = 722) THEN DELETE;
RUN;

*Checking residuals and ADJ R-SQ;
PROC REG  data=auto2;
MODEL sqr_price = dvehicleType1 dvehicleType2 dvehicleType3 dvehicleType4 dvehicleType5
	dvehicleType6 YearOfRegistration PowerPS Miles dFuelType dNotRepairedDamage1;
RUN;
*Now ADJ R-SQ value is 0.778 which increased from 0.6823 after removing outliers.;



*-----------MODEL VALIDATION------------;
*Creating train set with 75% of the data;
PROC SURVEYSELECT DATA=auto2 out=train seed=1234 samprate=0.75 outall;
RUN;

PROC PRINT DATA=train;
RUN;

*creating new variable sqr_train = sqr_price;
DATA train;
SET train;
	if selected then sqr_train = sqr_price;
RUN;
PROC PRINT DATA=train;
RUN;

*Fit models for train set;
PROC REG DATA=train;
	*Model 1;
	MODEL sqr_train = dAbTest dvehicleType1 dvehicleType2 dvehicleType3 dvehicleType4 dvehicleType5
	dvehicleType6 dvehicleType7 YearOfRegistration dGearbox PowerPS Miles 
	MonthOfRegistration dFuelType dNotRepairedDamage1 dNotRepairedDamage2;
	output out = outm1(where=(sqr_train=.)) p=yhat;
	*Model 2;
	MODEL sqr_train = dAbTest dvehicleType1 dvehicleType2 dvehicleType3 dvehicleType4 dvehicleType5
	dvehicleType6 dvehicleType7 YearOfRegistration PowerPS Miles 
	MonthOfRegistration dFuelType dNotRepairedDamage1 dNotRepairedDamage2;
	output out = outm2(where=(sqr_train=.)) p=yhat;
	*Model 3;
	MODEL sqr_train = dvehicleType1 dvehicleType2 dvehicleType3 dvehicleType4 dvehicleType5
	MonthOfRegistration dvehicleType6 dvehicleType7 YearOfRegistration PowerPS Miles dFuelType dNotRepairedDamage1;
	output out = outm3(where=(sqr_train=.)) p=yhat;
	*Model 4;
	MODEL sqr_train = dvehicleType1 dvehicleType2 dvehicleType3 dvehicleType4 dvehicleType5
	MonthOfRegistration dvehicleType6 YearOfRegistration PowerPS Miles dFuelType dNotRepairedDamage1;
	output out = outm4(where=(sqr_train=.)) p=yhat;
	*Model 5;
	MODEL sqr_train = dvehicleType1 dvehicleType2 dvehicleType3 dvehicleType4 dvehicleType5
	 dvehicleType6 YearOfRegistration PowerPS Miles dFuelType dNotRepairedDamage1;
	output out = outm5(where=(sqr_train=.)) p=yhat;
RUN;

*Analysis of predictions on trsting set for model m1
	create new dataset outm1_test that contains prediction for model m1 and the difference between observed and predicted values;
DATA outm1_test;
SET outm1;
	d = sqr_price - yhat;
	absd = abs (d);
	pe = abs(d/sqr_price);
RUN;

*RMSE: Root Mean Square Error
MAE: Mean Absolute Error
MAPE: Mean Absolute Percentage Error;
PROC SUMMARY DATA=outm1_test;
	VAR d absd;
	output out=outm1_stats std(d)=rmse mean(absd)=mae mean(pe)=mape;
RUN;
PROC PRINT DATA=outm1_stats;
TITLE "Model validation statistics for Model 1";
RUN;

*Computing correlation of observed and predicted value in test set for model 1;
PROC CORR DATA=outm1;
VAR sqr_price yhat;
RUN;

*Analysis of predictions on trsting set for model m2
	create new dataset outm2_test that contains prediction for model m2 and the difference between observed and predicted values;
DATA outm2_test;
SET outm2;
	d = sqr_price - yhat;
	absd = abs (d);
	pe = abs(d/sqr_price);
RUN;

*RMSE: Root Mean Square Error
MAE: Mean Absolute Error
MAPE: Mean Absolute Percentage Error;
PROC SUMMARY DATA=outm2_test;
	VAR d absd;
	output out=outm2_stats std(d)=rmse mean(absd)=mae mean(pe)=mape;
RUN;
PROC PRINT DATA=outm2_stats;
TITLE "Model validation statistics for Model 2";
RUN;

*Computing correlation of observed and predicted value in test set for model 2;
PROC CORR DATA=outm2;
VAR sqr_price yhat;
RUN;

*Analysis of predictions on trsting set for model m3
	create new dataset outm3_test that contains prediction for model m3 and the difference between observed and predicted values;
DATA outm3_test;
SET outm3;
	d = sqr_price - yhat;
	absd = abs (d);
	pe = abs(d/sqr_price);
RUN;

*RMSE: Root Mean Square Error
MAE: Mean Absolute Error
MAPE: Mean Absolute Percentage Error;
PROC SUMMARY DATA=outm3_test;
	VAR d absd;
	output out=outm3_stats std(d)=rmse mean(absd)=mae mean(pe)=mape;
RUN;
PROC PRINT DATA=outm3_stats;
TITLE "Model validation statistics for Model 3";
RUN;

*Computing correlation of observed and predicted value in test set for model 3;
PROC CORR DATA=outm3;
VAR sqr_price yhat;
RUN;

*Analysis of predictions on trsting set for model m4
	create new dataset outm1_test that contains prediction for model m4 and the difference between observed and predicted values;
DATA outm4_test;
SET outm4;
	d = sqr_price - yhat;
	absd = abs (d);
	pe = abs(d/sqr_price);
RUN;

*RMSE: Root Mean Square Error
MAE: Mean Absolute Error
MAPE: Mean Absolute Percentage Error;
PROC SUMMARY DATA=outm4_test;
	VAR d absd;
	output out=outm4_stats std(d)=rmse mean(absd)=mae mean(pe)=mape;
RUN;
PROC PRINT DATA=outm4_stats;
TITLE "Model validation statistics for Model 4";
RUN;

*Computing correlation of observed and predicted value in test set for model 4;
PROC CORR DATA=outm4;
VAR sqr_price yhat;
RUN;

*Analysis of predictions on trsting set for model m5
	create new dataset outm1_test that contains prediction for model m5 and the difference between observed and predicted values;
DATA outm5_test;
SET outm5;
	d = sqr_price - yhat;
	absd = abs (d);
	pe = abs(d/sqr_price);
RUN;

*RMSE: Root Mean Square Error
MAE: Mean Absolute Error
MAPE: Mean Absolute Percentage Error;
PROC SUMMARY DATA=outm5_test;
	VAR d absd;
	output out=outm5_stats std(d)=rmse mean(absd)=mae mean(pe)=mape;
RUN;
PROC PRINT DATA=outm5_stats;
TITLE "Model validation statistics for Model 5";
RUN;

*Computing correlation of observed and predicted value in test set for model 5;
PROC CORR DATA=outm5;
VAR sqr_price yhat;
RUN;



/**************************************************
K-FOLD CROSS VALIDATION
**************************************************/

* Compute 5-fold crossvalidation;
/* Apply 5-fold cross validation with backward model selection 
using prediction res#idual sum of squares as criterion for removing variables
(step=cv)*/
TITLE "5-fold crossvalidation";
PROC GLMSELECT DATA=auto2
	PLOTS=(asePlot Criteria);
MODEL sqr_price = dvehicleType1 dvehicleType2 dvehicleType3 dvehicleType4 dvehicleType5
	 dvehicleType6 YearOfRegistration PowerPS Miles dFuelType dNotRepairedDamage1 /
	selection=backward(stop=cv)cvMethod=split(5) cvDetails=all;
RUN;
/* apply 5-fold crossvalidation with stepwise selection 
and 25% of data removed for testing; */
TITLE "5-fold crossvalidation + 25% testing set";
PROC GLMSELECT DATA=auto2
	PLOTS=(asePlot Criteria);
	*partition defines a test set (25% of data) to validate model on new data;
	partition fraction(test=0.25);
	* selection=stepwise uses stepwise selection method;
	* stop=cv: minimizes prediction residual sum of squares for variable selection;
	MODEL sqr_price = dvehicleType1 dvehicleType2 dvehicleType3 dvehicleType4 dvehicleType5
	 dvehicleType6 YearOfRegistration PowerPS Miles dFuelType dNotRepairedDamage1 /
		selection=stepwise(stop=cv) cvMethod=split(5) cvDetails=all;
RUN;
