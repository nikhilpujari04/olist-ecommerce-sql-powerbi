-- Q>1
-- =============================================================
-- Repeat Customer Analysis
-- Olist marks each ORDER with a fresh customer_id, but tracks the
-- actual person via customer_unique_id. So "repeat customer" means
-- the same customer_unique_id appearing across multiple orders.
-- =============================================================

-- 1. Overall repeat-customer rate
--    (order_count comes from a CTE so we only count each unique
--     person once, regardless of how many orders they placed)
WITH customer_order_counts AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*)                                            AS total_customers,
    COUNT(*) FILTER (WHERE order_count > 1)              AS repeat_customers,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE order_count > 1) / COUNT(*),
        2
    )                                                     AS repeat_pct
FROM customer_order_counts;


-- 2. Distribution: how many customers placed 1, 2, 3... orders
WITH customer_order_counts AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    order_count,
    COUNT(*) AS num_customers
FROM customer_order_counts
GROUP BY order_count
ORDER BY order_count;


-- 3. Top 10 most frequent repeat customers, with their total spend
--    (joins in order_items to sum actual revenue per customer)
WITH customer_order_counts AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
),
customer_revenue AS (
    SELECT
        c.customer_unique_id,
        SUM(oi.price + oi.freight_value) AS total_spend
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY c.customer_unique_id
)
SELECT
    coc.customer_unique_id,
    coc.order_count,
    ROUND(cr.total_spend, 2) AS total_spend
FROM customer_order_counts coc
JOIN customer_revenue cr ON cr.customer_unique_id = coc.customer_unique_id
WHERE coc.order_count > 1
ORDER BY coc.order_count DESC, cr.total_spend DESC
LIMIT 10;


-- 4. Average days between first and second order, for repeat customers
--    (uses window functions: ROW_NUMBER + LAG to find consecutive orders)
WITH customer_orders_ranked AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp
        ) AS order_seq,
        LAG(o.order_purchase_timestamp) OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp
        ) AS prev_order_timestamp
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
)
SELECT
    ROUND(
        AVG(EXTRACT(EPOCH FROM (order_purchase_timestamp - prev_order_timestamp)) / 86400.0),
        1
    ) AS avg_days_between_orders
FROM customer_orders_ranked
WHERE order_seq = 2;  -- only the gap between order #1 and order #2

