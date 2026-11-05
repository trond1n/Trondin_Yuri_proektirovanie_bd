-- FOOD-107

SET search_path TO trondin_food, exts;

CREATE OR REPLACE PROCEDURE trondin_food.courier_salary()
LANGUAGE plpgsql
SET search_path = trondin_food, exts
AS $$
DECLARE
    v_month_start TIMESTAMP := date_trunc('month', LOCALTIMESTAMP);
    v_year        INTEGER   := EXTRACT(YEAR FROM v_month_start)::int;
    v_month       INTEGER   := EXTRACT(MONTH FROM v_month_start)::int;
BEGIN
    WITH courier_stats AS (
        SELECT
            c.courier_id,
            COALESCE(ord.delivered_cnt, 0) AS delivered_cnt,
            COALESCE(ord.commission_sum, 0) AS commission_sum,
            COALESCE(cp.coefficient_used, c.coefficient) AS coeff_used
        FROM trondin_food.courier c
        LEFT JOIN (
            SELECT
                o.courier_id,
                COUNT(*) AS delivered_cnt,
                SUM(o.commission) AS commission_sum
            FROM trondin_food."order" o
            WHERE o.status = 'доставлен'
              AND o.order_timestamp >= v_month_start
              AND o.order_timestamp < v_month_start + INTERVAL '1 month'
            GROUP BY o.courier_id
        ) ord
            ON ord.courier_id = c.courier_id
        LEFT JOIN trondin_food.courier_pay cp
            ON cp.courier_id = c.courier_id
           AND cp.year = v_year
           AND cp.month = v_month
    ),
    upsert_pay AS (
        INSERT INTO trondin_food.courier_pay (
            year,
            month,
            courier_id,
            amount,
            coefficient_used
        )
        SELECT
            v_year,
            v_month,
            cs.courier_id,
            ROUND(cs.coeff_used * cs.commission_sum, 2),
            cs.coeff_used
        FROM courier_stats cs
        ON CONFLICT (year, month, courier_id) DO UPDATE
        SET amount           = EXCLUDED.amount,
            coefficient_used = EXCLUDED.coefficient_used
    )
    UPDATE trondin_food.courier c
    SET coefficient = CASE
        WHEN cs.delivered_cnt <= 150 THEN 0.1
        WHEN cs.delivered_cnt <= 250 THEN 0.2
        WHEN cs.delivered_cnt <= 500 THEN 0.3
        ELSE                              0.5
    END
    FROM courier_stats cs
    WHERE c.courier_id = cs.courier_id
      AND c.status <> 'уволен';
END;
$$;
