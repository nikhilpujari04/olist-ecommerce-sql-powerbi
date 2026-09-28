-- =============================================================
-- Delivery Delay (bucketed) vs Review Score
-- =============================================================

WITH delay_days AS (
    SELECT
        o.order_id,
        o.order_estimated_delivery_date,
        o.order_delivered_customer_date,
        oi.review_score,
        EXTRACT(EPOCH FROM (order_delivered_customer_date - order_estimated_delivery_date)) / 86400.0 AS delay
    FROM orders o
    JOIN order_reviews oi ON o.order_id = oi.order_id
    WHERE order_delivered_customer_date IS NOT NULL
)
SELECT
    CASE
        WHEN delay <= -7 THEN '1. Very early (7+ days)'
        WHEN delay > -7 AND delay <= 0 THEN '2. On-time'
        WHEN delay > 0 AND delay <= 3 THEN '3. Slightly late (1-3d)'
        WHEN delay > 3 AND delay <= 7 THEN '4. Late (4-7d)'
        ELSE '5. Very late (8+ days)'
    END AS delay_bucket,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    COUNT(*) AS num_orders
FROM delay_days
GROUP BY
    CASE
        WHEN delay <= -7 THEN '1. Very early (7+ days)'
        WHEN delay > -7 AND delay <= 0 THEN '2. On-time'
        WHEN delay > 0 AND delay <= 3 THEN '3. Slightly late (1-3d)'
        WHEN delay > 3 AND delay <= 7 THEN '4. Late (4-7d)'
        ELSE '5. Very late (8+ days)'
    END
ORDER BY delay_bucket;