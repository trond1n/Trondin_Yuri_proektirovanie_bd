-- FOOD-108

SET search_path TO trondin_food, exts;

CREATE OR REPLACE VIEW trondin_food.how_much_money AS
WITH RECURSIVE orders_by_month AS (
    SELECT
        date_trunc('month', o.order_timestamp) AS month_start,
        SUM(o.order_amount) AS sum_no_commission,
        SUM(o.total_amount) AS sum_with_commission
    FROM trondin_food."order" o
    WHERE o.status = 'доставлен'
    GROUP BY date_trunc('month', o.order_timestamp)
),
bounds AS (
    SELECT
        MIN(obm.month_start) AS min_month,
        MAX(obm.month_start) AS max_month
    FROM orders_by_month obm
),
months AS (
    SELECT
        b.min_month AS month_start,
        b.max_month
    FROM bounds b
    WHERE b.min_month IS NOT NULL
    UNION ALL
    SELECT
        m.month_start + INTERVAL '1 month',
        m.max_month
    FROM months m
    WHERE m.month_start < m.max_month
),
pay_by_month AS (
    SELECT
        make_date(cp.year, cp.month, 1)::timestamp AS month_start,
        SUM(cp.amount) AS courier_pay
    FROM trondin_food.courier_pay cp
    GROUP BY make_date(cp.year, cp.month, 1)::timestamp
),
monthly_totals AS (
    SELECT
        m.month_start,
        COALESCE(obm.sum_no_commission, 0) AS sum_no_commission,
        COALESCE(obm.sum_with_commission, 0) AS sum_with_commission,
        COALESCE(obm.sum_with_commission, 0) - COALESCE(obm.sum_no_commission, 0) AS commission,
        COALESCE(pbm.courier_pay, 0) AS courier_pay
    FROM months m
    LEFT JOIN orders_by_month obm
        ON obm.month_start = m.month_start
    LEFT JOIN pay_by_month pbm
        ON pbm.month_start = m.month_start
)
SELECT
    to_char(mt.month_start, 'YYYY-MM') AS year_month,
    mt.sum_no_commission,
    mt.sum_with_commission,
    mt.commission,
    LAG(mt.commission) OVER (ORDER BY mt.month_start) AS prev_commission,
    mt.commission - LAG(mt.commission) OVER (ORDER BY mt.month_start) AS commission_diff,
    mt.courier_pay,
    mt.commission - mt.courier_pay AS net_profit
FROM monthly_totals mt
ORDER BY mt.month_start;
