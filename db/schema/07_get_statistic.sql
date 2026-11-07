-- FOOD-106

SET search_path TO trondin_food, exts;

CREATE OR REPLACE FUNCTION trondin_food.get_statistic()
RETURNS TABLE (
    restaurant_name   VARCHAR(100),
    best_product_name VARCHAR(100),
    total_amount      NUMERIC,
    avg_amount        NUMERIC,
    best_user         VARCHAR(50)
)
LANGUAGE plpgsql
SET search_path = trondin_food, exts
AS $$
BEGIN
    RETURN QUERY
    WITH delivered_orders AS MATERIALIZED (
        SELECT
            o.order_id,
            o.restaurant_id,
            o.client_id,
            o.total_amount
        FROM trondin_food."order" o
        WHERE o.status = 'доставлен'
    ),
    order_totals AS (
        SELECT
            d.restaurant_id,
            SUM(d.total_amount) AS sum_amount,
            AVG(d.total_amount) AS avg_order_amount
        FROM delivered_orders d
        GROUP BY d.restaurant_id
    ),
    product_totals AS (
        SELECT
            d.restaurant_id,
            os.product_id,
            SUM(os.quantity) AS total_quantity
        FROM delivered_orders d
        JOIN trondin_food.order_structure os
            ON os.order_id = d.order_id
        GROUP BY d.restaurant_id, os.product_id
    ),
    best_products AS (
        SELECT DISTINCT ON (pt.restaurant_id)
            pt.restaurant_id,
            p.product_name AS best_product_name
        FROM product_totals pt
        JOIN trondin_food.product p
            ON p.product_id = pt.product_id
        ORDER BY pt.restaurant_id, pt.total_quantity DESC, random()
    ),
    client_totals AS (
        SELECT
            d.restaurant_id,
            d.client_id,
            COUNT(*) AS order_count
        FROM delivered_orders d
        GROUP BY d.restaurant_id, d.client_id
    ),
    best_clients AS (
        SELECT DISTINCT ON (ct.restaurant_id)
            ct.restaurant_id,
            c.login AS best_user
        FROM client_totals ct
        JOIN trondin_food.client c
            ON c.client_id = ct.client_id
        ORDER BY ct.restaurant_id, ct.order_count DESC, random()
    )
    SELECT
        r.restaurant_name,
        bp.best_product_name,
        COALESCE(ot.sum_amount, 0) AS total_amount,
        COALESCE(ot.avg_order_amount, 0) AS avg_amount,
        bc.best_user
    FROM trondin_food.restaurant r
    LEFT JOIN order_totals ot
        ON ot.restaurant_id = r.restaurant_id
    LEFT JOIN best_products bp
        ON bp.restaurant_id = r.restaurant_id
    LEFT JOIN best_clients bc
        ON bc.restaurant_id = r.restaurant_id;
END;
$$;
