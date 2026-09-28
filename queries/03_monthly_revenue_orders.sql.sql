---JOIN orders to order_items (to get price)
--GROUP BY the truncated month
--SUM(price) for revenue, COUNT(DISTINCT order_id) for order count (remember why DISTINCT matters here — same reason as before, order_items has multiple rows per order)
---ORDER BY the month so it prints chronologically
--- 3. revenue and order by month
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month,
    COUNT ( DISTINCT o.order_id) as order_id,
	SUM(oi.price)AS Revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER by order_month
