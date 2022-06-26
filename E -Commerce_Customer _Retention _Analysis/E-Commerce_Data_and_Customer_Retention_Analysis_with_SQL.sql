
----------------------------------------------------------- E-COMMERCE-DATA-PROJECT -----------------------------------------------------------


-- 1. Using the columns of “market_fact”, “cust_dimen”, “orders_dimen”, “prod_dimen”, “shipping_dimen”, Create a new table, named as “combined_table”. --

CREATE VIEW combined_table
AS
SELECT	
		C.First_name,
		C.Last_name,
		C.Region,
		C.Customer_Segment,
		
		P.Prod_Main_id,
		P.Product_Sub_Category,
				
		O.Order_Date,
		O.Order_Priority,
				
		S.Order_ID,
		S.Ship_Mode,
		S.Ship_Date,
		
		M.Ship_id,
		M.Ord_id,
		M.Prod_id,
		M.Cust_id,
		M.Sales,
		M.Discount,
		M.Order_Quantity,
		M.Product_Base_Margin
FROM dbo.market_fact M
LEFT JOIN dbo.prod_dimen P ON M.Prod_id = P.Prod_id
LEFT JOIN dbo.orders_dimen O ON M.Ord_id = O.Ord_id
LEFT JOIN dbo.shipping_dimen S ON M.Ship_id = S.Ship_id
LEFT JOIN dbo.cust_dimen C ON M.Cust_id = C.Cust_id

SELECT *
FROM combined_table



-- 2. Find the top 3 customers who have the maximum count of orders. --

select TOP 3 Cust_id,First_name,Last_name, count (Ord_id) as cnt_ord
from combined_table
group by Cust_id, First_name,Last_name
ORDER BY cnt_ord DESC

-- 3. Create a new column at combined_table as DaysTakenForDelivery that contains the date difference of Order_Date and Ship_Date. -- 

SELECT		*, DATEDIFF(DAY, Order_Date, Ship_Date) DaysTakenForDelivery
FROM		combined_table
;

-- 4. Find the customer whose order took the maximum time to get delivered. --

SELECT TOP 1 First_name, Last_Name,  DATEDIFF(DAY, Order_Date, Ship_Date) AS MaxTime
FROM combined_table
ORDER BY MaxTime DESC


-- 5. Count the total number of unique customers in January and how many of them came back every month over the entire year in 2011 --


SELECT MONTH(Order_Date) Month_in_2011,COUNT(DISTINCT Cust_id) CustCameBack
FROM combined_table
WHERE Cust_id in
    (
    SELECT DISTINCT Cust_id
    FROM combined_table
    WHERE month(Order_Date) = 1 AND year(Order_Date) = 2011
    ) 
AND year(Order_Date) =2011
GROUP BY month(Order_Date)


-- 6.Write a query to return for each user the time elapsed between the first purchasing and the third purchasing, in ascending order by Customer ID. --

SELECT	Cust_id,
		DATEDIFF(DAY, first_order, third_order) date_diff
FROM	(
		SELECT	C.Cust_id, O.Ord_id,
				MIN(O.Order_Date)	OVER (PARTITION BY C.Cust_id ORDER BY O.Order_Date) first_order,
				LEAD(Order_Date, 2) OVER (PARTITION BY C.Cust_id ORDER BY O.Order_Date) third_order,
				ROW_NUMBER() OVER (PARTITION BY C.Cust_id ORDER BY O.Order_Date) row_num
		FROM	orders_dimen O, market_fact M, cust_dimen C
		WHERE	O.Ord_id = M.Ord_id
		AND		M.Cust_id = C.Cust_id
		) A
WHERE	row_num = 1
AND		DATEDIFF(DAY, first_order, third_order) IS NOT NULL


-- 7. Write a query that returns customers who purchased both product 11 and product 14, 
-- as well as the ratio of these products to the total number of products purchased by the customer.

CREATE VIEW cust_order_products
AS

SELECT	Ord_id, Cust_id, Prod_id,
		SUM(Order_Quantity) Order_Product_Quantity,
		SUM(Order_Quantity) OVER (PARTITION BY Cust_id) Total_Product_Quantity

FROM	market_fact
WHERE Cust_id IN
		(
		SELECT		Cust_id
		FROM		market_fact
		WHERE		Prod_id = 11
		INTERSECT
		SELECT		Cust_id
		FROM		market_fact
		WHERE		Prod_id = 14
		)
GROUP BY Ord_id, Cust_id, Prod_id, Order_Quantity
;

SELECT		Cust_id, Prod_id,
			CAST((1.0 * Order_Product_Quantity / Total_Product_Quantity) AS NUMERIC(4,2)) Product_Ratio
FROM		cust_order_products
WHERE		Prod_id IN (11, 14)
ORDER BY	Cust_id
;


-- Customer Segmentation --
-- Categorize customers based on their frequency of visits. --


-- 1. Create a “view” that keeps visit logs of customers on a monthly basis. (For each log, three field is kept: Cust_id, Year, Month) 


CREATE VIEW log_table
AS
(
	SELECT Cust_id, Year(Order_Date) as year_of_order, Month(Order_Date) as month_of_order
	FROM combined_table
	GROUP BY Cust_id, Year(Order_Date), Month(Order_Date)
)

SELECT *
FROM log_table
ORDER BY 1, 2, 3
;

-- 2. Create a “view” that keeps the number of monthly visits by users. (Show separately all months from the beginning business)  

CREATE VIEW Monthly_visit AS
(
	SELECT Cust_id,First_name, Last_name, YEAR(Order_Date) as Order_year, Month(Order_Date) as Order_month,
	COUNT (Order_Date) monthly_visit_num, Order_Date
	FROM combined_table
	Group by Cust_id,First_name, Last_name, YEAR(Order_Date), Month (Order_Date), Order_Date
)
select *
FROM [dbo].[Monthly_visit]


-- 3. For each visit of customers, create the next month of the visit as a separate column.

SELECT	DISTINCT Cust_id,First_name, Last_name, YEAR(Order_Date) as Order_year, Month(Order_Date) as Order_month,
		LEAD(MONTH(Order_Date)) OVER(PARTITION BY Cust_id ORDER BY Order_Date) next_visit
FROM	combined_table
Group by Cust_id, First_name, Last_name, Order_Date
;


-- 4. Calculate the monthly time gap between two consecutive visits by each customer.

SELECT	*,
		DATEDIFF(MONTH, Order_Date, next_visit) time_gap
FROM
		(
		SELECT		M.Cust_id, O.Order_Date, 
					LEAD((Order_Date)) OVER(PARTITION BY Cust_id ORDER BY Order_Date) next_visit
		FROM		market_fact M, orders_dimen O
		WHERE		M.Ord_id = O.Ord_id
		) A


-- 5. Categorise customers using average time gaps. Choose the most fitted labeling model for you.
-- For example:
-- o Labeled as churn if the customer hasn't made another purchase in the months since they made their first purchase.
-- o Labeled as regular if the customer has made a purchase every month. Etc.

CREATE VIEW time_gaps
AS
SELECT	*,
		DATEDIFF(MONTH, Order_Date, next_visit) time_gap
FROM
		(
		SELECT		M.Cust_id, O.Order_Date, 
					LEAD((Order_Date)) OVER(PARTITION BY Cust_id ORDER BY Order_Date) next_visit
		FROM		market_fact M, orders_dimen O
		WHERE		M.Ord_id = O.Ord_id
		) A
----------------------------------
CREATE VIEW total_avg_gap
AS
SELECT AVG(avg_time_gap*1.0) avg_gap
FROM(
SELECT Cust_id, AVG( time_gap ) avg_time_gap
	 FROM  time_gaps
	 GROUP BY Cust_id) A
;
------------------------------------
SELECT cust_id, avg_time_gap,
	CASE
		WHEN avg_time_gap <= (select * from total_avg_gap)	  THEN 'Regular'
		WHEN (avg_time_gap > (select * from total_avg_gap)) or (avg_time_gap IS NULL) THEN 'Churn'
		--WHEN avg_time_gap IS NULL THEN 'Churn'
	END cust_avg_time_gaps
FROM(SELECT Cust_id, AVG( time_gap ) avg_time_gap
	 FROM  time_gaps
	 GROUP BY Cust_id) A



---- Month-Wise Retention Rate
-- Find month-by-month customer retention ratei since the start of the business.

-- 1. Find the number of customers retained month-wise. (You can use time gaps)

CREATE VIEW RetentionMonthWise AS
SELECT	DISTINCT *,
		COUNT (Cust_id)	OVER (PARTITION BY next_visit ORDER BY Cust_id, next_visit) retention_month_wise
FROM	time_gaps
where	time_gap =1
 ;
 --DROP VIEW IF EXISTS retention_month_vise
 SELECT * FROM RetentionMonthWise;

--

/*2. Calculate the month-wise retention rate.
Month-Wise Retention Rate = 1.0 * Number of Customers Retained in The Current Month / Total
Number of Customers in the Current Month
If you want, you can track your own way.*/

CREATE VIEW time_gap_4
AS
SELECT Cust_id, Month(Order_Date) as Month_of_order, YEAR(Order_Date) as Year_of_Order, time_gap,
		CASE
			WHEN time_gap = 1 THEN 'retained'
		
		END AS Ret_num
from  time_gaps;
--------------------------------

SELECT * FROM time_gap_4;
--------------------------------

CREATE VIEW Toplamretinsayisi3
AS
SELECT Year_of_Order,Month_of_order, COUNT(Cust_id) as toplamret
FROM time_gap_4
WHERE Ret_num='retained'
GROUP BY  Year_of_Order, Month_of_order
-- ORDER BY 1,2

---------------------------
SELECT  *
FROM    Toplamretinsayisi3

---------------------------
CREATE VIEW Year_Month_Cust
AS
SELECT DISTINCT YEAR(Order_date) AS Yearly, MONTH(Order_Date) as Monthly, 
       count(cust_id) OVER (PARTITION BY YEAR(Order_date), MONTH(Order_Date)) as MonthlyCustomer
FROM combined_table
GROUP BY YEAR(Order_date), MONTH(Order_Date), Cust_id

---------------
SELECT *
FROM Year_Month_Cust

---------------

WITH ret_table AS 
(
SELECT  A.*, B.toplamret, 
        MIN(1.0*B.toplamret/A.MonthlyCustomer) OVER (PARTITION BY Yearly, Monthly) AS retention
FROM    Year_Month_Cust A, Toplamretinsayisi3 B
WHERE   A.Yearly = B.Year_of_Order AND A.Monthly = B.Month_of_Order
)
SELECT Yearly, Monthly,MonthlyCustomer,toplamret, CAST(retention AS NUMERIC (3,2)) as Retention_Rate
FROM ret_table