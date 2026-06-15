-- transforming the customer table

UPDATE customers
set city = NULL
WHERE city = '';

-- ivestgating the duplicates of the transaction files

with dublicate as(
select * ,
ROW_NUMBER() OVER(PARTITION BY customer_id,Product_name,quantity,
							revenue,cost,transaction_date) as row_num
FROM transactions
) 

select *
from dublicate
where row_num > 1;

drop TABLE tranactions_cleaned;

-- creating a cleaned Table for cleaned transaction
-- iserting the undublicated data

DROP TABLE transactions_cleaned;

CREATE TABLE transactions_cleaned AS
WITH duplicates AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id, product_name, quantity, 
                         revenue, transaction_date
        ) AS row_num
    FROM transactions
)
SELECT transaction_id, customer_id, product_name, category, quantity, unit_price,
       discount, revenue, cost, profit, transaction_date, 
       payment_method, order_status
FROM duplicates
WHERE row_num = 1;

-- investegating the anomely in the prices

WITH avg_prices AS (
    SELECT product_name,
           AVG(unit_price) AS avg_price
    FROM transactions_cleaned
    GROUP BY product_name
)
SELECT 
    t.transaction_id,
    t.customer_id,
    t.product_name,
    t.unit_price,
    a.avg_price,
    CASE 
        WHEN t.unit_price < (a.avg_price * 0.5) THEN 'Anomaly'
        ELSE 'Normal'
    END AS price_flag
FROM transactions_cleaned t
JOIN avg_prices a ON t.product_name = a.product_name;

-- adding the flaged rows

ALTER TABLE transactions_cleaned ADD COLUMN price_flag VARCHAR(10);

UPDATE transactions_cleaned t
JOIN (
    SELECT product_name, AVG(unit_price) * 0.5 AS threshold
    FROM transactions_cleaned
    GROUP BY product_name
) a ON t.product_name = a.product_name
SET t.price_flag = CASE 
    WHEN t.unit_price < a.threshold THEN 'Anomaly'
    ELSE 'Normal'
END;


-- adding table for RFM

create table transactions_rfm as
with avg_price as (
	select product_name,
		avg(unit_price) * 0.5 as threshold
	from transactions_cleaned
    GROUP BY product_name
)

select t.*
from transactions_cleaned as t
join avg_price as a on t.product_name = a.product_name
where order_status = 'completed'
	and t.unit_price >= a.threshold;

-- investgating the RFM Scores

-- findindg the RFM

with RFM as (
select 
customer_id,
DATEDIFF('2024-12-30',max(transaction_date)) as recency,
COUNT(DISTINCT(transaction_date)) 			 as frequency,
ROUND(sum(revenue),2) 						 as monetary
from transactions_rfm
GROUP BY customer_id
),

-- calcualting the score

rfm_score as (
select *,
	ntile(4) over(order by recency desc) as r_score,
	ntile(4) over(order by frequency asc) as f_score,
	ntile(4) over(order by monetary asc) as m_score
from RFM
),

-- finding the segmants

rfm_segmant as(
select *,
	case 
		when r_score = 4 and f_score = 4 then 'champion' 
		when r_score >= 3 and f_score >= 3 then 'loyal'
		when r_score >= 3 and f_score <=2 then 'promising'
		when r_score <= 2 and f_score >= 3 then 'at risk'
		when r_score = 1 and f_score <= 2 then 'lost'
		else 'regular'
	end as segmant
from rfm_score
)

select *
from rfm_segmant;


-- inserting the final scores in a new table

create table rfm_scores as
with RFM as (
select 
customer_id,
DATEDIFF('2024-12-30',max(transaction_date)) as recency,
COUNT(DISTINCT(transaction_date)) 			 as frequency,
ROUND(sum(revenue),2) 						 as monetary
from transactions_rfm
GROUP BY customer_id
),

-- calcualting the score

rfm_score as (
select *,
	ntile(4) over(order by recency desc) as r_score,
	ntile(4) over(order by frequency asc) as f_score,
	ntile(4) over(order by monetary asc) as m_score
from RFM
),

-- finding the segmants

rfm_segmant as(
select *,
	case 
		when r_score = 4 and f_score = 4 then 'champion' 
		when r_score >= 3 and f_score >= 3 then 'loyal'
		when r_score >= 3 and f_score <=2 then 'promising'
		when r_score <= 2 and f_score >= 3 then 'at risk'
		when r_score = 1 and f_score <= 2 then 'lost'
		else 'regular'
	end as segmant
from rfm_score
)

select *
from rfm_segmant;