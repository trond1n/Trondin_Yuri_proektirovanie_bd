-- FOOD-103, FOOD-102
SET search_path TO trondin_food, exts;

CREATE OR REPLACE PROCEDURE trondin_food.erase_test_data()
LANGUAGE plpgsql
SET search_path = trondin_food, exts
AS $$
BEGIN
    TRUNCATE TABLE
        trondin_food.review,
        trondin_food.payment,
        trondin_food.order_structure,
        trondin_food."order",
        trondin_food.product,
        trondin_food.product_category,
        trondin_food.restaurant,
        trondin_food.client_address,
        trondin_food.client,
        trondin_food.address,
        trondin_food.courier_pay,
        trondin_food.courier;
END;
$$;

CREATE OR REPLACE PROCEDURE trondin_food.insert_test_data(value int)
LANGUAGE plpgsql
SET search_path = trondin_food, exts
AS $$
DECLARE
    v_period_start      TIMESTAMP := date_trunc('month', LOCALTIMESTAMP) - INTERVAL '5 months';
    v_now               TIMESTAMP := LOCALTIMESTAMP;

    v_category_ids      UUID[];
    v_client_ids        UUID[];
    v_courier_ids       UUID[];
    v_address_ids       UUID[];
    v_restaurant_ids    UUID[];
    v_product_ids       UUID[];
    v_order_ids         UUID[];
    v_payment_ids       UUID[];
    v_review_ids        UUID[];

    v_base_client_phone  BIGINT;
    v_base_courier_phone BIGINT;
BEGIN
    IF value IS NULL OR value < 1 THEN
        RAISE EXCEPTION 'Параметр value должен быть целым числом >= 1 (передано: %)', value;
    END IF;

    SELECT array_agg(exts.uuid_generate_v4())
    INTO v_category_ids
    FROM generate_series(1, value);

    INSERT INTO trondin_food.product_category (
        product_category_id,
        product_category_name
    )
    SELECT t.id,
           'Категория ' || t.rn
    FROM unnest(v_category_ids) WITH ORDINALITY AS t(id, rn);

    SELECT array_agg(exts.uuid_generate_v4())
    INTO v_client_ids
    FROM generate_series(1, value);

    SELECT COALESCE(MAX(phone_number)::bigint, 70000000000)
    INTO v_base_client_phone
    FROM trondin_food.client
    WHERE phone_number LIKE '70%';

    INSERT INTO trondin_food.client (
        client_id,
        login,
        password,
        phone_number
    )
    SELECT t.id,
           'user_' || replace(t.id::text, '-', ''),
           md5(random()::text),
           (v_base_client_phone + t.rn)::text
    FROM unnest(v_client_ids) WITH ORDINALITY AS t(id, rn);

    SELECT array_agg(exts.uuid_generate_v4())
    INTO v_courier_ids
    FROM generate_series(1, value);

    SELECT COALESCE(MAX(phone_number)::bigint, 70000000000)
    INTO v_base_courier_phone
    FROM trondin_food.courier
    WHERE phone_number LIKE '70%';

    INSERT INTO trondin_food.courier (
        courier_id,
        fio,
        phone_number,
        status,
        hire_date,
        dismissal_date,
        coefficient
    )
    SELECT t.id,
           'Курьер ' || t.rn,
           (v_base_courier_phone + t.rn)::text,
           (enum_range(NULL::trondin_food.courier_status))[1 + t.rn % 4],
           v_period_start::date,
           CASE
               WHEN (enum_range(NULL::trondin_food.courier_status))[1 + t.rn % 4] = 'уволен'
               THEN CURRENT_DATE
               ELSE NULL
           END,
           0.1
    FROM unnest(v_courier_ids) WITH ORDINALITY AS t(id, rn);

    SELECT array_agg(exts.uuid_generate_v4())
    INTO v_address_ids
    FROM generate_series(1, value * 5);

    INSERT INTO trondin_food.address (
        address_id,
        street,
        house_number,
        apartment_office
    )
    SELECT t.id,
           'ул. Шарикоподшипниковская, ' || t.id,
           ((t.rn - 1) % 200 + 1)::text,
           CASE
               WHEN t.rn % 3 = 0 THEN NULL
               ELSE ((t.rn - 1) % 500 + 1)::text
           END
    FROM unnest(v_address_ids) WITH ORDINALITY AS t(id, rn);

    INSERT INTO trondin_food.client_address (
        client_id,
        address_id
    )
    SELECT c.id,
           v_address_ids[value + c.k + j * value]
    FROM unnest(v_client_ids) WITH ORDINALITY AS c(id, k)
    CROSS JOIN generate_series(0, 3) AS j;

    SELECT array_agg(exts.uuid_generate_v4())
    INTO v_restaurant_ids
    FROM generate_series(1, value);

    INSERT INTO trondin_food.restaurant (
        restaurant_id,
        restaurant_name,
        address_id,
        description,
        work_start,
        work_end,
        company_details,
        rating,
        status
    )
    SELECT t.id,
           'Ресторан ' || t.rn,
           v_address_ids[t.rn],
           'Описание ресторана ' || t.rn,
           '08:00:00'::time + (t.rn % 4) * INTERVAL '1 hour',
           '20:00:00'::time + (t.rn % 4) * INTERVAL '1 hour',
           'ИНН ' || t.id,
           NULL,
           (enum_range(NULL::trondin_food.restaurant_status))[1 + t.rn % 2]
    FROM unnest(v_restaurant_ids) WITH ORDINALITY AS t(id, rn);

    SELECT array_agg(exts.uuid_generate_v4())
    INTO v_product_ids
    FROM generate_series(1, value * 5);

    INSERT INTO trondin_food.product (
        product_id,
        product_name,
        product_category_id,
        price,
        restaurant_id,
        photo_url,
        rating,
        status,
        description
    )
    SELECT t.id,
           'Блюдо ' || t.rn,
           v_category_ids[(t.rn - 1) % value + 1],
           ROUND((100 + random() * 1900)::numeric, 2),
           v_restaurant_ids[(t.rn - 1) % value + 1],
           CASE
               WHEN t.rn % 3 = 0 THEN NULL
               ELSE 'https://cdn.foodexpress.ru/products/' || t.id || '.jpg'
           END,
           NULL,
           (enum_range(NULL::trondin_food.product_status))[1 + t.rn % 3],
           'Описание блюда ' || t.rn
    FROM unnest(v_product_ids) WITH ORDINALITY AS t(id, rn);

    SELECT array_agg(exts.uuid_generate_v4())
    INTO v_order_ids
    FROM generate_series(1, value * 5);

    WITH orders_base AS MATERIALIZED (
        SELECT o.id AS order_id,
               o.rn::int AS rn,
               ((o.rn - 1) % value + 1)::int AS r,
               ((o.rn - 1) / value)::int AS j,
               (floor(random() * random() * value)::int + 1) AS k,
               (floor(random() * random() * value)::int + 1) AS courier_idx,
               floor(random() * 4)::int AS addr_j,
               v_period_start + random() * (v_now - v_period_start) AS order_ts,
               (15 + floor(random() * 106)::int) * INTERVAL '1 minute' AS deliv_delta
        FROM unnest(v_order_ids) WITH ORDINALITY AS o(id, rn)
    ),
    orders_gen AS MATERIALIZED (
        SELECT b.order_id,
               b.rn,
               b.r,
               v_restaurant_ids[b.r] AS restaurant_id,
               v_client_ids[b.k] AS client_id,
               v_courier_ids[b.courier_idx] AS courier_id,
               v_address_ids[value + b.k + b.addr_j * value] AS address_id,
               (enum_range(NULL::trondin_food.order_status))[1 + b.j] AS status,
               b.order_ts AS order_timestamp,
               CASE
                   WHEN (enum_range(NULL::trondin_food.order_status))[1 + b.j] = 'доставлен'
                   THEN LEAST(b.order_ts + b.deliv_delta, v_now)
                   ELSE NULL
               END AS delivery_timestamp,
               CASE
                   WHEN (enum_range(NULL::trondin_food.order_status))[1 + b.j] = 'доставлен'
                   THEN 3
                   ELSE 1 + (b.rn % 3)
               END AS item_count,
               'Комментарий к заказу ' || b.rn AS description
        FROM orders_base b
    ),
    lines AS MATERIALIZED (
        SELECT g.order_id,
               p.product_id,
               g.restaurant_id,
               p.price,
               CASE
                   WHEN t.pos = 0 THEN CEIL(1000.0 / p.price)
                   ELSE ROUND((0.5 + random() * 2.5)::numeric, 3)
               END AS quantity
        FROM orders_gen g
        CROSS JOIN LATERAL generate_series(0, g.item_count - 1) AS t(pos)
        JOIN trondin_food.product p
          ON p.product_id = v_product_ids[g.r + t.pos * value]
    ),
    totals AS (
        SELECT l.order_id,
               ROUND(SUM(l.price * l.quantity), 2) AS order_amount,
               ROUND(ROUND(SUM(l.price * l.quantity), 2) * 0.10, 2) AS commission
        FROM lines l
        GROUP BY l.order_id
    ),
    new_orders AS (
        INSERT INTO trondin_food."order" (
            order_id,
            courier_id,
            client_id,
            address_id,
            restaurant_id,
            order_timestamp,
            delivery_timestamp,
            order_amount,
            commission,
            total_amount,
            status,
            pay_status,
            description
        )
        SELECT g.order_id,
               g.courier_id,
               g.client_id,
               g.address_id,
               g.restaurant_id,
               g.order_timestamp,
               g.delivery_timestamp,
               tot.order_amount,
               tot.commission,
               tot.order_amount + tot.commission,
               g.status,
               -- 1-й элемент order_pay_status — 'ожидает' (обновится после вставки payment)
               (enum_range(NULL::trondin_food.order_pay_status))[1],
               g.description
        FROM orders_gen g
        JOIN totals tot ON tot.order_id = g.order_id
    )
    INSERT INTO trondin_food.order_structure (
        order_id,
        product_id,
        restaurant_id,
        quantity
    )
    SELECT l.order_id,
           l.product_id,
           l.restaurant_id,
           l.quantity
    FROM lines l;

    -- 9. payment (5 * value строк: по одной попытке на заказ) + обновление order.pay_status
    SELECT array_agg(exts.uuid_generate_v4())
    INTO v_payment_ids
    FROM generate_series(1, value * 5);

    INSERT INTO trondin_food.payment (
        payment_id,
        order_id,
        payment_type,
        amount,
        transaction_id,
        payment_timestamp,
        status
    )
    SELECT t.payment_id,
           o.order_id,
           (enum_range(NULL::trondin_food.payment_type))[1 + t.rn % 3],
           o.total_amount,
           'txn_' || t.payment_id,
           LEAST(o.order_timestamp + (1 + floor(random() * 30)::int) * INTERVAL '1 minute', v_now),
           -- 1-й элемент payment_status — 'успех' (по BR-8.1 у каждого заказа должна быть успешная оплата)
           (enum_range(NULL::trondin_food.payment_status))[1]
    FROM unnest(v_payment_ids, v_order_ids) WITH ORDINALITY AS t(payment_id, order_id, rn)
    JOIN trondin_food."order" o ON o.order_id = t.order_id;

    UPDATE trondin_food."order" o
    SET pay_status = CASE p.status
        WHEN 'успех'       THEN 'оплачен'::trondin_food.order_pay_status
        WHEN 'ошибка'      THEN 'ошибка'::trondin_food.order_pay_status
        WHEN 'в_обработке' THEN 'ожидает'::trondin_food.order_pay_status
    END
    FROM unnest(v_order_ids) AS u(order_id)
    JOIN trondin_food.payment p ON p.order_id = u.order_id
    WHERE o.order_id = u.order_id;

    -- 10. review (5 * value строк: по 5 отзывов на каждый из value доставленных заказов)
    SELECT array_agg(exts.uuid_generate_v4())
    INTO v_review_ids
    FROM generate_series(1, value * 5);

    INSERT INTO trondin_food.review (
        review_id,
        client_id,
        order_id,
        review_timestamp,
        entity_type,
        entity_id,
        description,
        photo_url,
        rating
    )
    SELECT t.id,
           o.client_id,
           o.order_id,
           LEAST(o.delivery_timestamp + (1 + floor(random() * 60)::int) * INTERVAL '1 minute', v_now),
           CASE
               WHEN (t.rn - 1) / value < 3 THEN (enum_range(NULL::trondin_food.review_entity_type))[1]
               WHEN (t.rn - 1) / value = 3 THEN (enum_range(NULL::trondin_food.review_entity_type))[2]
               ELSE                             (enum_range(NULL::trondin_food.review_entity_type))[3]
           END,
           CASE
               WHEN (t.rn - 1) / value < 3 THEN v_product_ids[((t.rn - 1) % value + 1) + ((t.rn - 1) / value) * value]
               WHEN (t.rn - 1) / value = 3 THEN o.restaurant_id
               ELSE                             o.order_id
           END,
           'Отзыв ' || t.rn,
           CASE
               WHEN t.rn % 5 = 0 THEN NULL
               ELSE 'https://cdn.foodexpress.ru/reviews/' || t.id || '.jpg'
           END,
           floor(random() * 5)::int + 1
    FROM unnest(v_review_ids) WITH ORDINALITY AS t(id, rn)
    -- При генерации заказов статус задаётся через enum_range[1 + j], где 'доставлен' — 4-й элемент (j = 3),
    -- поэтому доставленные заказы лежат в v_order_ids со смещением 3 * value.
    JOIN trondin_food."order" o
      ON o.order_id = v_order_ids[3 * value + ((t.rn - 1) % value + 1)];

    UPDATE trondin_food.product p
    SET rating = sub.avg_rating
    FROM (
        SELECT r.entity_id,
               ROUND(AVG(r.rating), 2) AS avg_rating
        FROM trondin_food.review r
        WHERE r.entity_type = 'блюдо'
          AND r.entity_id = ANY(v_product_ids)
        GROUP BY r.entity_id
    ) sub
    WHERE p.product_id = sub.entity_id;

    UPDATE trondin_food.restaurant rest
    SET rating = sub.avg_rating
    FROM (
        SELECT r.entity_id,
               ROUND(AVG(r.rating), 2) AS avg_rating
        FROM trondin_food.review r
        WHERE r.entity_type = 'ресторан'
          AND r.entity_id = ANY(v_restaurant_ids)
        GROUP BY r.entity_id
    ) sub
    WHERE rest.restaurant_id = sub.entity_id;

    WITH courier_grid AS (
        SELECT c.courier_id,
               gs.month_start,
               COALESCE(ord.delivered_cnt, 0) AS delivered_cnt,
               COALESCE(ord.commission_sum, 0) AS commission_sum,
               LAG(COALESCE(ord.delivered_cnt, 0)) OVER (
                   PARTITION BY c.courier_id ORDER BY gs.month_start
               ) AS prev_cnt
        FROM unnest(v_courier_ids) AS c(courier_id)
        CROSS JOIN generate_series(
            v_period_start,
            v_now,
            INTERVAL '1 month'
        ) AS gs(month_start)
        LEFT JOIN (
            SELECT o.courier_id,
                   date_trunc('month', o.order_timestamp) AS order_month,
                   COUNT(*) AS delivered_cnt,
                   SUM(o.commission) AS commission_sum
            FROM trondin_food."order" o
            WHERE o.status = 'доставлен'
              AND o.courier_id = ANY(v_courier_ids)
            GROUP BY o.courier_id, date_trunc('month', o.order_timestamp)
        ) ord
          ON ord.courier_id = c.courier_id
         AND ord.order_month = gs.month_start
    ),
    courier_months AS MATERIALIZED (
        SELECT cg.courier_id,
               cg.month_start,
               cg.delivered_cnt,
               cg.commission_sum,
               CASE
                   WHEN cg.prev_cnt IS NULL OR cg.prev_cnt <= 150 THEN 0.1
                   WHEN cg.prev_cnt <= 250                        THEN 0.2
                   WHEN cg.prev_cnt <= 500                        THEN 0.3
                   ELSE                                                0.5
               END AS coeff_used
        FROM courier_grid cg
    ),
    inserted_pay AS (
        INSERT INTO trondin_food.courier_pay (
            year,
            month,
            courier_id,
            amount,
            coefficient_used
        )
        SELECT EXTRACT(YEAR FROM cm.month_start)::int,
               EXTRACT(MONTH FROM cm.month_start)::int,
               cm.courier_id,
               ROUND(cm.coeff_used * cm.commission_sum, 2),
               cm.coeff_used
        FROM courier_months cm
    )
    UPDATE trondin_food.courier c
    SET coefficient = CASE
        WHEN c.status = 'уволен'     THEN cm.coeff_used
        WHEN cm.delivered_cnt <= 150 THEN 0.1
        WHEN cm.delivered_cnt <= 250 THEN 0.2
        WHEN cm.delivered_cnt <= 500 THEN 0.3
        ELSE                              0.5
    END
    FROM courier_months cm
    WHERE c.courier_id = cm.courier_id
      AND cm.month_start = date_trunc('month', v_now);
END;
$$;

