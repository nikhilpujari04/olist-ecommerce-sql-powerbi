-- =============================================================
-- 5.Category Performance: revenue, order count, avg review score
-- =============================================================

SELECT
    COALESCE(t.product_category_name_english, p.product_category_name, 'Unknown') AS category,
    ROUND(SUM(oi.price), 2) AS revenue,
    COUNT(DISTINCT oi.order_id) AS num_orders,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_translation t ON p.product_category_name = t.product_category_name
LEFT JOIN order_reviews r ON oi.order_id = r.order_id
GROUP BY COALESCE(t.product_category_name_english, p.product_category_name, 'Unknown')
ORDER BY revenue DESC;