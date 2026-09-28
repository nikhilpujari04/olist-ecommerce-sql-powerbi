-- Row-level version for Power BI (one row per order, not pre-aggregated)
-- This lets Power BI relate it to `orders` via order_id, so slicers work.

SELECT
    d.order_id,
    r.review_score,
    CASE
        WHEN d.delay <= -7 THEN '1. Very early (7+ days)'
        WHEN d.delay > -7 AND d.delay <= 0 THEN '2. On-time'
        WHEN d.delay > 0 AND d.delay <= 3 THEN '3. Slightly late (1-3d)'
        WHEN d.delay > 3 AND d.delay <= 7 THEN '4. Late (4-7d)'
        ELSE '5. Very late (8+ days)'
    END AS delay_bucket
FROM (
    SELECT
        order_id,
        EXTRACT(EPOCH FROM (order_delivered_customer_date - order_estimated_delivery_date)) / 86400.0 AS delay
    FROM orders
    WHERE order_delivered_customer_date IS NOT NULL
) d
JOIN order_reviews r ON d.order_id = r.order_id;