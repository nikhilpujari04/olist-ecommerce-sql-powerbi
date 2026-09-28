-- Row-level version for Power BI (one row per order_item, not pre-aggregated)
 
SELECT
    oi.order_id,
    oi.price,
    COALESCE(t.product_category_name_english, p.product_category_name, 'Unknown') AS category
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_translation t ON p.product_category_name = t.product_category_name;