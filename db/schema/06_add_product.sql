-- FOOD-104

SET search_path TO trondin_food, exts;

CREATE OR REPLACE PROCEDURE trondin_food.add_product(
    p_restaurant_id       UUID,
    p_product_category_id UUID,
    p_name                VARCHAR,
    p_price               NUMERIC,
    p_description         TEXT,
    p_rating              NUMERIC                     DEFAULT NULL,
    p_status              trondin_food.product_status DEFAULT 'доступно',
    p_photo_url           TEXT                        DEFAULT NULL
)
LANGUAGE plpgsql
SET search_path = trondin_food, exts
AS $$
BEGIN
    IF p_restaurant_id IS NULL THEN
        RAISE EXCEPTION 'Обязательный параметр p_restaurant_id не может быть NULL (передано: %)', p_restaurant_id;
    END IF;

    IF p_product_category_id IS NULL THEN
        RAISE EXCEPTION 'Обязательный параметр p_product_category_id не может быть NULL (передано: %)', p_product_category_id;
    END IF;

    IF p_name IS NULL THEN
        RAISE EXCEPTION 'Обязательный параметр p_name не может быть NULL (передано: %)', p_name;
    END IF;

    IF p_price IS NULL THEN
        RAISE EXCEPTION 'Обязательный параметр p_price не может быть NULL (передано: %)', p_price;
    END IF;

    IF p_description IS NULL THEN
        RAISE EXCEPTION 'Обязательный параметр p_description не может быть NULL (передано: %)', p_description;
    END IF;

    IF p_status IS NULL THEN
        RAISE EXCEPTION 'Обязательный параметр p_status не может быть NULL (передано: %)', p_status;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM trondin_food.restaurant r
        WHERE r.restaurant_id = p_restaurant_id
    ) THEN
        RAISE EXCEPTION 'Ресторан с restaurant_id = % не существует', p_restaurant_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM trondin_food.product_category pc
        WHERE pc.product_category_id = p_product_category_id
    ) THEN
        RAISE EXCEPTION 'Категория с product_category_id = % не существует', p_product_category_id;
    END IF;

    IF p_price < 0 THEN
        RAISE EXCEPTION 'Цена блюда не может быть отрицательной (p_price = %)', p_price;
    END IF;

    IF p_rating IS NOT NULL AND (p_rating < 0 OR p_rating > 5) THEN
        RAISE EXCEPTION 'Рейтинг блюда должен быть в диапазоне от 0 до 5 (p_rating = %)', p_rating;
    END IF;
    INSERT INTO trondin_food.product (
        product_name,
        product_category_id,
        price,
        restaurant_id,
        photo_url,
        rating,
        status,
        description
    )
    VALUES (
        p_name,
        p_product_category_id,
        p_price,
        p_restaurant_id,
        p_photo_url,
        p_rating,
        p_status,
        p_description
    );
END;
$$;
