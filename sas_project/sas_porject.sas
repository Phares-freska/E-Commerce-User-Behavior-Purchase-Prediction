/*DATA*/
FILENAME REFFILE '/home/u64510386/sas_project/ecommerce_user_behavior.csv';
/*EXPLANATION*/
/*importing DATA*/
PROC IMPORT DATAFILE=REFFILE
	DBMS=CSV
	OUT=ECB;
	GETNAMES=YES;

RUN;
/*Step1:
	Understanding the DATA*/
/*metaDATA*/
PROC CONTENTS DATA=ECB;
TITLE "metaDATA about the DATA";
RUN;

/*ECB*/
PROC PRINT DATA=ECB(obs=10);
TITLE "10 obs of DATA:";
RUN;

/*explaining what each column represents*/
PROC IMPORT DATAFILE='/home/u64510386/sas_project/data_explanation.csv'
	DBMS=CSV
	OUT=EXPLANATION;
	GETNAMES=YES;
RUN;
PROC PRINT DATA=EXPLANATION;
TITLE 'EXPLANATION OF EACH COLUMN';
RUN;

/*the problem,the goal, and the explanation*/
DATA _null_;
    file print;
    put "what we know from the DATA";
    put "the problem: classification";
    put "our goul: predict whether the customer will buy from the site or not";
    put "explanation: it affects sales and the profit of the combany";
   	TITLE="the problem,the goal, and the explanation";
RUN;
/*DATA decribe*/
PROC MEANS DATA=ECB PRINT;
TITLE "DATA describe";
RUN;
/*how many nulls */
/*numeric*/
PROC summary DATA=ECB PRINT nmiss;
	var _numeric_;
TITLE "nulls in numeric";
RUN;
/*catgorical*/
PROC FREQ DATA=ECB;
	tables
	_character_
	discount_seen
	ad_clicked
	returning_user
	purchase/missing;
	title"missing counts for categories";
	RUN;

/*------------------------------------------------*/
/*Step2:
	investigate the DATA*/
/* histogram identify distrubution*/
*time_on_site;
PROC SGPLOT DATA=ECB;
    HISTOGRAM time_on_site;
    DENSITY time_on_site/ type=normal;
    title "time_on_site";
RUN;
/*A boxplot to identfiy the outliers in:*/
PROC SGPLOT DATA=ECB;
    hbox time_on_site;
    title "time on site";
RUN;
/*a barplot between gender and devices*/
PROC SGPLOT DATA=ecb;
	TITLE "gender and devices";
	VBAR gender / RESPONSE=time_on_site
		GROUP=device_type
		GROUPDISPLAY=cluster;
RUN;
/* time on site vs pages viewed */
proc sgplot data=ECB;
TITLE"time on site vs pages viewed";
scatter x=time_on_site y=pages_viewed / group=purchase;
run;

/*Pages Viewed by Device and Returning Status  */
proc sgplot data=ecb;
 TITLE "Pages Viewed by Device and Returning Status";
 VBAR device_type /RESPONSE=pages_viewed
 	group=returning_user
 	groupdisplay=cluster;
run;
/* User Loyalty Matrix*/
proc sgplot data=ecb;
title"User Loyalty Matrix";
scatter x=previous_purchases y=avg_session_time /group=purchase;
run;
/*------------------------------------------------*/

/*step3:
	fixing the DATA*/
*droping uselss column;
DATA ECB_cleaned;
	SET ECB;
	drop user_id;
RUN;

/*handling missing values using sql*/
PROC SQL NOPRINT;
/* Categorical nulls */
UPDATE ECB_CLEANED SET device_type  = 'Mobile' WHERE device_type    IS NULL;
UPDATE ECB_CLEANED SET gender       = 'Male' WHERE gender         IS NULL or gender="female";
UPDATE ECB_CLEANED SET discount_seen = 1       WHERE discount_seen  IS NULL;
UPDATE ECB_CLEANED SET ad_clicked    = 0      WHERE ad_clicked     IS NULL;
UPDATE ECB_CLEANED SET returning_user = 1      WHERE returning_user IS NULL;

/* Compute averages into macro variables */
SELECT 
    ROUND(avg(age), 1),
    ROUND(avg(pages_viewed), 1),ROUND(avg(previous_purchases), 1),
    ROUND(avg(cart_items), 1),ROUND(avg(avg_session_time), 0.01),
    ROUND(avg(bounce_rate), 0.01),ROUND(avg(time_on_site), 0.01)
INTO 
    :avg_age,:avg_pages,:avg_prev,:avg_cart,:avg_sess,:avg_bounce,:avg_time
FROM ECB_CLEANED;

/* Impute numerical nulls with averages */
UPDATE ECB_CLEANED SET age                = &avg_age.    WHERE age                IS NULL;
UPDATE ECB_CLEANED SET pages_viewed       = &avg_pages.  WHERE pages_viewed       IS NULL;
UPDATE ECB_CLEANED SET previous_purchases = &avg_prev.   WHERE previous_purchases IS NULL;
UPDATE ECB_CLEANED SET cart_items         = &avg_cart.   WHERE cart_items         IS NULL;
UPDATE ECB_CLEANED SET avg_session_time   = &avg_sess.   WHERE avg_session_time   IS NULL;
UPDATE ECB_CLEANED SET bounce_rate        = &avg_bounce. WHERE bounce_rate        IS NULL;
UPDATE ECB_CLEANED SET time_on_site       = &avg_time.   WHERE time_on_site       IS NULL;

QUIT;
RUN;
/*standrizing*/
PROC STANDARD DATA=ECB_Cleaned MEAN=0 STD=1 OUT=ECB_CLEANED;
  VAR pages_viewed previous_purchases cart_items bounce_rate time_on_site avg_session_time ;
RUN;

/*one hot encoding*/
PROC GLMMOD DATA=ECB_cleaned OUTDESIGN=one_encoded noprint;
	CLASS device_type gender;
	model var1 =device_type gender;
RUN;
proc datasets lib=work nolist;
    modify one_encoded;
    attrib Col2 label=' '
           Col3 label=' '
           Col4 label=' '
           Col5 label=' '
           Col6 label=' ';
quit;
RUN;
proc sql;
CREATE TABLE ECB_model AS
    SELECT e.var1,
    	   e.age, 
           e.time_on_site, 
           e.discount_seen,
           e.avg_session_time, 
           e.pages_viewed, 
           e.previous_purchases,
           e.bounce_rate,
           e.cart_items,
           e.purchase,
           o.Col2 AS Desktop,
           o.Col3 AS Mobile,
           o.Col4 AS Tablet,
           o.Col5 AS Female,
           o.Col6 AS Male
    FROM ECB_cleaned e
    INNER JOIN one_encoded o ON o.var1 = e.var1;
quit;
run;
*a look at the cleaned data;
PROC summary DATA=ECB_model PRINT nmiss;
	var _numeric_;
TITLE "nulls in numeric";
RUN;
PROC PRINT DATA=ECB_model(OBS=10);
TITLE"DATA AFTER CLEANING";
RUN;
*time_on_site HISTOGRAM;
PROC SGPLOT DATA=ECB_model;
    HISTOGRAM time_on_site;
    DENSITY time_on_site/ type=normal;
    title " standerised avg session time";
RUN;

/*corrlation table*/
/* 1. Correlation output */
proc corr data=ECB_cleaned noprint outp=corr_out2 nomiss;
   var age time_on_site pages_viewed previous_purchases cart_items 
       discount_seen ad_clicked returning_user avg_session_time 
       bounce_rate purchase;
run;

/* 2. Reshape to long format */
data corr_long2;
   set corr_out2;
   if _TYPE_ = 'CORR';
   array vars age time_on_site pages_viewed previous_purchases cart_items 
              discount_seen ad_clicked returning_user avg_session_time 
              bounce_rate purchase;
   length var2name $32;
   xvar = _NAME_;
   do over vars;
      var2name = vname(vars);
      corr_val = vars;
      output;
   end;
   keep xvar var2name corr_val;
run;

/*3.Heatmap*/
ods graphics / width=850px height=850px;

proc sgplot data=corr_long2 noautolegend;
   title "Correlation Heatmap - ECB Cleaned (Feature Selection)";
   heatmapparm x=var2name y=xvar colorresponse=corr_val /
      colormodel=(CX2166AC CXFFFFFF CXD6604D)
      outline;
   text x=var2name y=xvar text=corr_val /
      textattrs=(size=7);
   xaxis display=(nolabel) fitpolicy=rotate;
   yaxis display=(nolabel);
run;
/*creating new features to capture non linear equation and help the model more*/
DATA ECB_model;
    SET ECB_model;
    time_on_site_CUBIED = time_on_site**3;
    pages_viewed_CUBIED = pages_viewed**3;
    bounce_rate_CUBIED  = bounce_rate**3;
    cart_items_CUBIED = cart_items**3;
    KEEP VAR1 time_on_site pages_viewed pages_viewed_CUBIED previous_purchases 
         cart_items bounce_rate time_on_site_CUBIED purchase bounce_rate_CUBIED cart_items_CUBIED ;
RUN;

/* 1. Correlation output from your model data */
proc corr data=ECB_model noprint outp=corr_out nomiss;
   var VAR1 time_on_site pages_viewed pages_viewed_CUBIED 
       previous_purchases cart_items bounce_rate 
       time_on_site_CUBIED purchase bounce_rate_CUBIED cart_items_CUBIED;
run;

/* 2. Reshape to long format */
data corr_long;
   set corr_out;
   if _TYPE_ = 'CORR';
   array vars VAR1 time_on_site pages_viewed pages_viewed_CUBIED 
              previous_purchases cart_items bounce_rate 
              time_on_site_CUBIED purchase bounce_rate_CUBIED cart_items_CUBIED;
   length var2name $32;
   xvar = _NAME_;
   do over vars;
      var2name = vname(vars);
      corr_val = vars;
      output;
   end;
   keep xvar var2name corr_val;
run;

/* 3. Heatmap */
ods graphics / width=750px height=750px;

proc sgplot data=corr_long noautolegend;
   title "Correlation Heatmap - ECB Model";
   heatmapparm x=var2name y=xvar colorresponse=corr_val /
      colormodel=(CX2166AC CXFFFFFF CXD6604D)   /* blue=neg, white=0, red=pos */
      outline;
   text x=var2name y=xvar text=corr_val /textattrs=(size=7) ;
   
   xaxis display=(nolabel) fitpolicy=rotate;
   yaxis display=(nolabel);
run;
/*data is ready for the model*/
/* spliting the data */
DATA train;
    SET ECB_model;
    IF var1 < 6000;
    KEEP time_on_site pages_viewed pages_viewed_CUBIED previous_purchases 
         cart_items bounce_rate time_on_site_CUBIED purchase bounce_rate_CUBIED cart_items_CUBIED;
RUN;

DATA test;
    SET ECB_model;
    IF var1 >= 6000;
    KEEP time_on_site pages_viewed pages_viewed_CUBIED previous_purchases 
         cart_items bounce_rate time_on_site_CUBIED purchase bounce_rate_CUBIED cart_items_CUBIED;
RUN;

data _null_;
	file print;
	title"feature selection";
	put"time_on_site:the longer the time the more likely to buy";
	put"";
	put"pages_viewed:the more pages the likely to buy";
	put"";
	put"previous_purchases:the more times the customer purchases the more loyal and more likely to buy";
	put"";
	put"cart_items:the more the more likely to buy";
	put"";
	put"bounce_rate:the less it is ,the more likely the customer stay and buy";
	put"";
	put"time_on_site_CUBIED purchase bounce_rate_CUBIED cart_items_CUBIED:to catch non";
run;
/* we are using logistic model */
/* training */
PROC LOGISTIC DATA=train DESCENDING NOPRINT;       
    MODEL purchase(event="1") = time_on_site pages_viewed pages_viewed_CUBIED
                                 previous_purchases cart_items bounce_rate
                                 time_on_site_CUBIED bounce_rate_CUBIED cart_items_CUBIED;  
    /* Score new data*/
    SCORE DATA=train OUT=training_scores;
    SCORE DATA=test  OUT=testing_scores;
    store work.my_model;
RUN;

/* taking a look on model data */
PROC PRINT DATA=training_scores (OBS=10);
    TITLE "training data";
RUN;

PROC PRINT DATA=testing_scores (OBS=10);
    TITLE "testing data";
RUN;

/* model evaluation */
/* making the sets */
PROC SQL;
    CREATE TABLE TRAIN_RESULTS AS
        SELECT F_purchase AS purchase,        
               I_purchase AS predict
        FROM training_scores;

    CREATE TABLE TEST_RESULTS AS
        SELECT F_purchase AS purchase,       
               I_purchase AS predict
        FROM testing_scores;
QUIT;

/* accuracy */
DATA TRAIN_CHECK;
    SET TRAIN_RESULTS;
    correct = (purchase = predict);
RUN;

DATA TEST_CHECK;
    SET TEST_RESULTS;
    correct = (purchase = predict);
RUN;

/* means */
PROC MEANS DATA=TRAIN_CHECK MEAN;
    VAR correct;
    TITLE "TRAINING ACCURACY";
RUN;

PROC MEANS DATA=TEST_CHECK MEAN;
    VAR correct;
    TITLE "TEST ACCURACY";
RUN;
/*model explaination*/
DATA _null_;
    file print;
    title"real world use:";
    PUT"by using the choosen features we can decides wither or not the customer going to buy from the site or wont, which we can use it later
    do more things for the customers who will buy from the site, like giving them more credits cash back,and gifts;furthermore ";
    RUN;
