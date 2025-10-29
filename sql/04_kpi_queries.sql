-- ============================================
-- MAIN KPIs
-- ============================================

-- 1. Total revenue and growth
WITH revenue_by_month AS (
    SELECT 
        DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
        SUM(oi.price) AS revenue,
        COUNT(DISTINCT o.order_id) AS orders,
        COUNT(DISTINCT o.customer_id) AS customers
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
)
SELECT 
    month,
    revenue,
    orders,
    customers,
    revenue / NULLIF(orders, 0) AS avg_order_value,
    LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue,
    ROUND(
        ((revenue - LAG(revenue) OVER (ORDER BY month)) / 
        NULLIF(LAG(revenue) OVER (ORDER BY month), 0) * 100)::NUMERIC, 
        2
    ) AS revenue_growth_pct
FROM revenue_by_month
ORDER BY month;

-- 2. Top 10 products by revenue
SELECT 
    p.product_id,
    p.category_fashion,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    SUM(oi.price) AS total_revenue,
    ROUND(AVG(oi.price)::NUMERIC, 2) AS avg_price,
    SUM(oi.price + oi.freight_value) AS total_revenue_with_shipping
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_id, p.category_fashion
ORDER BY total_revenue DESC
LIMIT 10;

-- 3. Performance by category
SELECT 
    p.category_fashion,
    COUNT(DISTINCT oi.order_id) AS orders,
    SUM(oi.price) AS revenue,
    ROUND(AVG(oi.price)::NUMERIC, 2) AS avg_price,
    ROUND(SUM(oi.price) * 100.0 / SUM(SUM(oi.price)) OVER (), 2) AS revenue_share_pct
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.category_fashion
ORDER BY revenue DESC;

-- 4. Delivery performance analysis
SELECT 
    CASE 
        WHEN delivery_delay <= 0 THEN 'On Time'
        WHEN delivery_delay BETWEEN 1 AND 3 THEN '1-3 days late'
        WHEN delivery_delay BETWEEN 4 AND 7 THEN '4-7 days late'
        ELSE 'More than 7 days late'
    END AS delivery_performance,
    COUNT(*) AS orders_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage,
    ROUND(AVG(delivery_days)::NUMERIC, 1) AS avg_delivery_days
FROM orders
WHERE order_status = 'delivered'
GROUP BY 
    CASE 
        WHEN delivery_delay <= 0 THEN 'On Time'
        WHEN delivery_delay BETWEEN 1 AND 3 THEN '1-3 days late'
        WHEN delivery_delay BETWEEN 4 AND 7 THEN '4-7 days late'
        ELSE 'More than 7 days late'
    END
ORDER BY orders_count DESC;

-- 5. Analysis of payment methods
SELECT 
    p.payment_type,
    COUNT(DISTINCT p.order_id) AS orders,
    SUM(p.payment_value) AS total_value,
    ROUND(AVG(p.payment_value)::NUMERIC, 2) AS avg_value,
    ROUND(AVG(p.payment_installments)::NUMERIC, 1) AS avg_installments
FROM payments p
GROUP BY p.payment_type
ORDER BY orders DESC;