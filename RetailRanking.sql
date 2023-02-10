use retail_segmentation;
#STEP1 Create categories for instore shoppers, online shopers, and multichanel shoppers.
#Table1 
DROP TABLE IF EXISTS Table1;
CREATE TABLE Table1 AS
SELECT household_id, 
       sum(CASE WHEN Home_Shopping_Flg = 0 THEN visits ELSE 0 END) AS 'Total Visits 0', 
       round(sum(CASE WHEN Home_Shopping_Flg = 0 THEN tot_spend ELSE 0 END), 2) AS 'Total Spend 0', 
       sum(CASE WHEN Home_Shopping_Flg = 0 THEN tot_qty ELSE 0 END) AS 'Total Quantity 0',
       sum(CASE WHEN Home_Shopping_Flg = 1 THEN visits ELSE 0 END) AS 'Total Visits 1', 
       round(sum(CASE WHEN Home_Shopping_Flg = 1 THEN tot_spend ELSE 0 END), 2) AS 'Total Spend 1',
       sum(CASE WHEN Home_Shopping_Flg = 1 THEN tot_qty ELSE 0 END) AS 'Total Quantity 1',
       sum(visits) AS 'Total Visits',
       round(sum(tot_spend), 2) AS 'Total Spend', 
       sum(tot_qty) AS 'Total Quantity', 
       CASE WHEN count(Home_Shopping_Flg) = 2 THEN "Multichannel" ELSE CASE WHEN Home_Shopping_Flg = 1 THEN "Online Only" ELSE "Instore Only" END END AS "Shopping mode Segment"
FROM txn
GROUP BY household_id;

SELECT * FROM table1;

#STEP2 Join data from the new table and customer table
DROP TABLE IF EXISTS Table1_cust;
CREATE TABLE Table1_cust AS
SELECT c.household_id, c.loyalty, c.preferred_store_format, c.lifestyle, c.gender, 
	   t.`Total Visits 0`, t.`Total Spend 0`, t.`Total Quantity 0`, t.`Total Visits 1`, t.`Total Spend 1`, t.`Total Quantity 1`, t.`Total Visits`, t.`Total Spend`, t.`Total Quantity`, t.`Shopping mode Segment`
FROM cust AS c JOIN table1 AS t
ON c.household_id = t.household_id;

SELECT * FROM Table1_cust;

#STEP3 
#ShopingmodeAVG 
SELECT `Shopping mode Segment`, 
        round(avg(`Total Visits`),2) AS 'Avg Total Visits',
        round(avg(`Total Spend`),2) AS 'Avg Total Spends',
        round(avg(`Total Quantity`),2) AS 'Avg Total Quantity'
FROM Table1_cust
GROUP BY `Shopping mode Segment`;

#Shoping mode vs loyalty
SELECT `Shopping mode Segment`, 
        round(100 * sum(CASE WHEN loyalty = 'Very Frequent Shoppers' THEN 1 ELSE 0 END)/count(1), 2) AS 'Very Frequent Shoppers',
        round(100 * sum(CASE WHEN loyalty = 'Occasional Shoppers' THEN 1 ELSE 0 END)/ count(1), 2) AS 'Occasional Shoppers',
        round(100 * sum(CASE WHEN loyalty = 'No longer Shopping' THEN 1 ELSE 0 END)/ count(1), 2) AS 'No longer Shopping',
        round(100 * sum(CASE WHEN loyalty = 'Lapsing Shoppers' THEN 1 ELSE 0 END)/ count(1), 2) AS 'Lapsing Shoppers'
FROM Table1_cust
GROUP BY `Shopping mode Segment`;

#Shoping mode vs Preferred store
SELECT `Shopping mode Segment`,
        round(100 * sum(CASE WHEN preferred_store_format = 'Very Large Stores' THEN 1 ELSE 0 END)/count(1), 2) AS 'Very Large Stores',
        round(100 * sum(CASE WHEN preferred_store_format = 'Large Stores' THEN 1 ELSE 0 END)/count(1), 2) AS 'Large Stores',
        round(100 * sum(CASE WHEN preferred_store_format = 'Others' THEN 1 ELSE 0 END)/count(1), 2) AS 'Others',
        round(100 * sum(CASE WHEN preferred_store_format = 'Small Stores' THEN 1 ELSE 0 END)/count(1), 2) AS 'Small Stores',
        round(100 * sum(CASE WHEN preferred_store_format = 'Mom and Pop Stores' THEN 1 ELSE 0 END)/count(1), 2) AS 'Mom and Pop Stores'
FROM Table1_cust
GROUP BY `Shopping mode Segment`;

#Shoping mode vs lifestyle
SELECT `Shopping mode Segment`, 
        round(100 * sum(CASE WHEN lifestyle= 'Middle Class' THEN 1 ELSE 0 END)/count(1),2) AS 'Middle Class',
        round(100 * sum(CASE WHEN lifestyle= 'Low Affluent Customers' THEN 1 ELSE 0 END)/count(1),2) AS 'Low Affluent Customers',
        round(100 * sum(CASE WHEN lifestyle= 'Very Affluent Customers' THEN 1 ELSE 0 END)/count(1),2) AS 'Very Affluent Customers'
FROM Table1_cust
GROUP BY `Shopping mode Segment`;

#Shoping mode vs Gender
SELECT `Shopping mode Segment`, 
        round(100*sum(CASE WHEN gender='M' THEN 1 ELSE 0 END)/count(1),2) AS 'M',
		round(100*sum(CASE WHEN gender='F' THEN 1 ELSE 0 END)/count(1),2) AS 'F',
		round(100*sum(CASE WHEN gender='X' THEN 1 ELSE 0 END)/count(1),2) AS 'X'
FROM Table1_cust
GROUP BY `Shopping mode Segment`;

#STEP4 
#Score based on the percentile of spend and visit
DROP TABLE IF EXISTS Table1_;
CREATE TABLE Table1_ AS
SELECT T.household_id, T.`Total Visits`, T.`Total Spend`, 
       CASE WHEN P.Percentile_Visit > 0.66 THEN 3 ELSE CASE WHEN P.Percentile_Visit > 0.33 THEN 2 ELSE 1 END END AS "Total Visit Score",
       CASE WHEN P.Percentile_Spend > 0.66 THEN 3 ELSE CASE WHEN P.Percentile_Spend > 0.33 THEN 2 ELSE 1 END END AS "Total Spend Score",
       (CASE WHEN P.Percentile_Visit > 0.66 THEN 3 ELSE CASE WHEN P.Percentile_Visit > 0.33 THEN 2 ELSE 1 END END) + (CASE WHEN P.Percentile_Spend > 0.66 THEN 3 ELSE CASE WHEN P.Percentile_Spend > 0.33 THEN 2 ELSE 1 END END) AS "Total Score"
FROM Table1 AS T JOIN (SELECT household_id, `Total Visits`, `Total Spend`,
                        PERCENT_RANK()
                        OVER (ORDER BY `Total Visits`) AS Percentile_Visit,
                        PERCENT_RANK()
                        OVER (ORDER BY `Total Spend`) AS Percentile_Spend
                        FROM Table1) AS P
                ON T.household_id = P.household_id;

select * from Table1_;

#Segment clients based on the total score
DROP TABLE IF EXISTS Table2;
CREATE TABLE Table2 AS
SELECT T.household_id, T.`Total Visits`, T.`Total Spend`, T.`Total Visit Score`, T.`Total Spend Score`, T.`Total Score`,
        CASE WHEN PS.Percentile_Score > 0.66 THEN "Champions" ELSE CASE WHEN PS.Percentile_Score > 0.33 THEN "Potential" ELSE "Laggards" END END AS `Value Segments`
FROM Table1_ AS T JOIN (SELECT household_id, `Total Score`,
                        PERCENT_RANK()
                        OVER (ORDER BY `Total Score`) AS Percentile_Score
                        FROM Table1_) AS PS
                ON T.household_id = PS.household_id;

Select * from Table2;

#STEP5
#Join customer information with value segments
DROP TABLE IF EXISTS Table2_cust;
CREATE TABLE Table2_cust AS
SELECT c.household_id, c.loyalty, c.preferred_store_format, c.lifestyle, c.gender, c.`Total Visits`, c.`Total Spend`, c.`Total Quantity`,c.`Shopping mode Segment`, T.`Value Segments`
FROM Table1_cust AS c JOIN table2 AS t
ON c.household_id = t.household_id;

SELECT * FROM Table2_cust;

#ValueSegmentAVG
SELECT `Value Segments`, 
        round(avg(`Total Visits`),2) AS 'Avg Total Visits',
        round(avg(`Total Spend`),2) AS 'Avg Total Spends',
        round(avg(`Total Quantity`),2) AS 'Avg Total Quantity'
FROM Table2_cust
GROUP BY `Value Segments`;

#ValueSegment vs loyalty
SELECT `Value Segments`, 
        round(100 * sum(CASE WHEN loyalty = 'Very Frequent Shoppers' THEN 1 ELSE 0 END)/count(1), 2) AS 'Very Frequent Shoppers',
        round(100 * sum(CASE WHEN loyalty = 'Occasional Shoppers' THEN 1 ELSE 0 END)/count(1), 2) AS 'Occasional Shoppers',
        round(100 * sum(CASE WHEN loyalty = 'No longer Shopping' THEN 1 ELSE 0 END)/count(1), 2) AS 'No longer Shopping',
        round(100 * sum(CASE WHEN loyalty = 'Lapsing Shoppers' THEN 1 ELSE 0 END)/count(1), 2) AS 'Lapsing Shoppers'
FROM Table2_cust 
GROUP BY `Value Segments`;

#ValueSegment vs Preferred store
SELECT `Value Segments`,
        round(100 * sum(CASE WHEN preferred_store_format = 'Very Large Stores' THEN 1 ELSE 0 END)/count(1), 2) AS 'Very Large Stores',
        round(100 * sum(CASE WHEN preferred_store_format = 'Large Stores' THEN 1 ELSE 0 END)/count(1), 2) AS 'Large Stores',
        round(100 * sum(CASE WHEN preferred_store_format = 'Others' THEN 1 ELSE 0 END)/count(1), 2) AS 'Others',
        round(100 * sum(CASE WHEN preferred_store_format = 'Small Stores' THEN 1 ELSE 0 END)/count(1), 2) AS 'Small Stores',
        round(100 * sum(CASE WHEN preferred_store_format = 'Mom and Pop Stores' THEN 1 ELSE 0 END)/count(1), 2) AS 'Mom and Pop Stores'
FROM Table2_cust
GROUP BY `Value Segments`;

#ValueSegment vs lifestyle
SELECT `Value Segments`, 
        round(100 * sum(CASE WHEN lifestyle= 'Middle Class' THEN 1 ELSE 0 END)/count(1),2) AS 'Middle Class',
        round(100 * sum(CASE WHEN lifestyle= 'Low Affluent Customers' THEN 1 ELSE 0 END)/count(1),2) AS 'Low Affluent Customers',
        round(100 * sum(CASE WHEN lifestyle= 'Very Affluent Customers' THEN 1 ELSE 0 END)/count(1),2) AS 'Very Affluent Customers'
FROM Table2_cust
GROUP BY `Value Segments`;

#ValueSegment vs Gender
SELECT `Value Segments`, 
        round(100*sum(CASE WHEN gender='M' THEN 1 ELSE 0 END)/count(1),2) AS 'M',
	round(100*sum(CASE WHEN gender='F' THEN 1 ELSE 0 END)/count(1),2) AS 'F',
	round(100*sum(CASE WHEN gender='X' THEN 1 ELSE 0 END)/count(1),2) AS 'X'
FROM Table2_cust
GROUP BY `Value Segments`;

#ValueSegment vs ShoppingModeSegment
SELECT `Value Segments`, 
        round(100*sum(CASE WHEN `Shopping mode Segment`='Instore Only' THEN 1 ELSE 0 END)/count(1),2) AS 'Instore Only',
	round(100*sum(CASE WHEN `Shopping mode Segment`='Online Only' THEN 1 ELSE 0 END)/count(1),2) AS 'Online Only',
	round(100*sum(CASE WHEN `Shopping mode Segment`='Multichannel' THEN 1 ELSE 0 END)/count(1),2) AS 'Multichannel'
FROM Table2_cust
GROUP BY `Value Segments`;