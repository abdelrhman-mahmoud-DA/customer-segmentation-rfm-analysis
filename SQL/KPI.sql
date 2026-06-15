-- What does a typical customer in each segment look like?

select
	segmant,
	avg(recency) 			as avg_recency,
    avg(frequency) 			as avg_frequency,
    ROUND(avg(monetary),2)  as avg_monetary
from rfm_scores 
GROUP BY segmant;

-- Which segments are driving the most revenue?

select segmant,
	ROUND((sum(monetary) / (select sum(monetary) from rfm_scores)) * 100,2) as revenue_pct
from rfm_scores
GROUP BY segmant
ORDER BY revenue_pct desc;

-- Who are our most valuable individual customers?

SELECT 
	customer_id,
    segmant,
    monetary
from rfm_scores
ORDER BY monetary desc
limit 10;