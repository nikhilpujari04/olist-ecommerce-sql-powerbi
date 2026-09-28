-- =============================================================
-- Payment Behavior Analysis
-- =============================================================

-- 1. Distribution, avg installments, avg value by payment type
SELECT
    payment_type,
    COUNT(*) AS num_payments,
    ROUND(AVG(payment_installments), 2) AS avg_installments,
    ROUND(AVG(payment_value), 2) AS avg_payment_value
FROM order_payments
WHERE payment_type != 'not_defined'   -- only 3 rows, negligible noise
GROUP BY payment_type
ORDER BY num_payments DESC;


-- 2. Does installment count correlate with order value? (credit_card only,
--    since it's the only type that actually varies)
SELECT
    payment_installments,
    COUNT(*) AS num_payments,
    ROUND(AVG(payment_value), 2) AS avg_payment_value
FROM order_payments
WHERE payment_type = 'credit_card'
  AND payment_installments BETWEEN 1 AND 12   -- drop rare 13/14/0 outliers
GROUP BY payment_installments
ORDER BY payment_installments;