-- ============================================
-- ADVANCED ANALYSIS
-- ============================================

-- 1. RFM Analysis (Recency, Frequency, Monetary)
WITH customer_metrics AS (
    SELECT 
        o.customer_id,
        MAX(o.order_purchase_timestamp) AS last_purchase,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price) AS monetary_value,
        CURRENT_DATE - MAX(o.order_purchase_timestamp)::DATE AS recency_days
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY o.customer_id
),
rfm_scores AS (
    SELECT 
        customer_id,
        recency_days,
        frequency,
        monetary_value,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS recency_score,
        NTILE(5) OVER (ORDER BY frequency) AS frequency_score,
        NTILE(5) OVER (ORDER BY monetary_value) AS monetary_score
    FROM customer_metrics
)
SELECT 
    customer_id,
    recency_score,
    frequency_score,
    monetary_score,
    (recency_score + frequency_score + monetary_score) AS rfm_total,
    CASE 
        WHEN (recency_score + frequency_score + monetary_score) >= 13 THEN 'Champions'
        WHEN (recency_score + frequency_score + monetary_score) >= 10 THEN 'Loyal'
        WHEN (recency_score + frequency_score + monetary_score) >= 7 THEN 'Potential'
        WHEN recency_score <= 2 THEN 'At Risk'
        ELSE 'Need Attention'
    END AS customer_segment
FROM rfm_scores
ORDER BY rfm_total DESC;

-- 2. Cohort Analysis (Retention per month)
WITH customer_cohorts AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', MIN(order_purchase_timestamp)) AS cohort_month
    FROM orders
    GROUP BY customer_id
),
order_cohort AS (
    SELECT 
        o.customer_id,
        cc.cohort_month,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month,
        (EXTRACT(YEAR FROM o.order_purchase_timestamp) - EXTRACT(YEAR FROM cc.cohort_month)) * 12 +
        (EXTRACT(MONTH FROM o.order_purchase_timestamp) - EXTRACT(MONTH FROM cc.cohort_month)) AS months_since_first
    FROM orders o
    JOIN customer_cohorts cc ON o.customer_id = cc.customer_id
)
SELECT 
    cohort_month,
    months_since_first,
    COUNT(DISTINCT customer_id) AS customers,
    SUM(COUNT(DISTINCT customer_id)) OVER (PARTITION BY cohort_month ORDER BY months_since_first) AS cumulative_customers
FROM order_cohort
GROUP BY cohort_month, months_since_first
ORDER BY cohort_month, months_since_first;

-- 3. Customer Lifetime Value (CLV) simplified
WITH customer_stats AS (
    SELECT 
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.price) AS total_spent,
        MIN(o.order_purchase_timestamp) AS first_order,
        MAX(o.order_purchase_timestamp) AS last_order,
        EXTRACT(DAYS FROM (MAX(o.order_purchase_timestamp) - MIN(o.order_purchase_timestamp))) AS customer_lifetime_days
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY o.customer_id
)
SELECT 
    customer_id,
    total_orders,
    total_spent,
    ROUND((total_spent / NULLIF(total_orders, 0))::NUMERIC, 2) AS avg_order_value,
    CASE 
        WHEN customer_lifetime_days > 0 
        THEN ROUND((total_spent / NULLIF(customer_lifetime_days, 0) * 365)::NUMERIC, 2)
        ELSE total_spent
    END AS estimated_annual_value,
    CASE 
        WHEN total_orders = 1 THEN 'One-time'
        WHEN total_orders BETWEEN 2 AND 3 THEN 'Occasional'
        WHEN total_orders >= 4 THEN 'Regular'
    END AS customer_type
FROM customer_stats
ORDER BY total_spent DESC
LIMIT 100;

-- 4. Product Affinity Analysis (Products purchased together)
WITH product_pairs AS (
    SELECT 
        oi1.product_id AS product_a,
        oi2.product_id AS product_b,
        COUNT(DISTINCT oi1.order_id) AS times_bought_together
    FROM order_items oi1
    JOIN order_items oi2 
        ON oi1.order_id = oi2.order_id 
        AND oi1.product_id < oi2.product_id
    GROUP BY oi1.product_id, oi2.product_id
    HAVING COUNT(DISTINCT oi1.order_id) >= 5
)
SELECT 
    p1.category_fashion AS category_a,
    p2.category_fashion AS category_b,
    pp.times_bought_together,
    ROUND(
        pp.times_bought_together * 100.0 / 
        (SELECT COUNT(DISTINCT order_id) FROM orders), 
        2
    ) AS co_purchase_rate
FROM product_pairs pp
JOIN products p1 ON pp.product_a = p1.product_id
JOIN products p2 ON pp.product_b = p2.product_id
ORDER BY pp.times_bought_together DESC
LIMIT 20;

-- 5. Seasonal Trends Analysis
SELECT 
    o.month,
    o.quarter,
    COUNT(DISTINCT o.order_id) AS orders,
    SUM(oi.price) AS revenue,
    ROUND(AVG(oi.price)::NUMERIC, 2) AS avg_order_value,
    COUNT(DISTINCT o.customer_id) AS unique_customers
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.month, o.quarter
ORDER BY o.month;