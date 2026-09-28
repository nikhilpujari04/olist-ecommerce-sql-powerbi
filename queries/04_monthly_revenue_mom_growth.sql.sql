-- 3.2 Month over Month 
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month,
        SUM(oi.price) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
)
SELECT
    order_month,
    revenue,
    LAG(revenue) OVER (ORDER BY order_month) AS prev_month_revenue,
    ROUND(
        100.0 * (revenue - LAG(revenue) OVER (ORDER BY order_month))
        / LAG(revenue) OVER (ORDER BY order_month),
        1
    ) AS mom_growth_pct
FROM monthly
ORDER BY order_month;
