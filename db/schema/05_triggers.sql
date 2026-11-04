-- FOOD-105, FOOD-101 (BR-8.7, BR-9.1, BR-9.2, BR-9.6, BR-9.7)

SET search_path TO trondin_food, exts;

-- 1. Проверка валидности полиморфной ссылки review.entity_id и принадлежности заказу (BR-9.1, BR-9.2)
CREATE OR REPLACE FUNCTION trondin_food.check_review_entity()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = trondin_food, exts
AS $$
BEGIN
    IF NEW.entity_type = 'заказ' THEN
        IF NEW.entity_id <> NEW.order_id THEN
            RAISE EXCEPTION 'Отзыв с типом "заказ" должен ссылаться на order_id этого заказа (entity_id = %, order_id = %)',
                NEW.entity_id, NEW.order_id;
        END IF;
    ELSIF NEW.entity_type = 'ресторан' THEN
        IF NOT EXISTS (
            SELECT 1
            FROM trondin_food."order" o
            WHERE o.order_id = NEW.order_id
              AND o.restaurant_id = NEW.entity_id
        ) THEN
            RAISE EXCEPTION 'Ресторан (entity_id = %) не соответствует ресторану заказа (order_id = %)',
                NEW.entity_id, NEW.order_id;
        END IF;
    ELSIF NEW.entity_type = 'блюдо' THEN
        IF NOT EXISTS (
            SELECT 1
            FROM trondin_food.order_structure os
            WHERE os.order_id = NEW.order_id
              AND os.product_id = NEW.entity_id
        ) THEN
            RAISE EXCEPTION 'Блюдо (entity_id = %) отсутствует в составе заказа (order_id = %)',
                NEW.entity_id, NEW.order_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_review_check_entity ON trondin_food.review;
CREATE TRIGGER trg_review_check_entity
BEFORE INSERT OR UPDATE OF order_id, entity_type, entity_id
ON trondin_food.review
FOR EACH ROW
EXECUTE FUNCTION trondin_food.check_review_entity();


-- 2. Пересчёт агрегированного рейтинга блюда и ресторана (FOOD-105, BR-9.6, BR-9.7)
CREATE OR REPLACE FUNCTION trondin_food.rating_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = trondin_food, exts
AS $$
BEGIN
    -- Пересчёт для старой сущности при DELETE или при смене сущности в UPDATE
    IF TG_OP = 'DELETE' OR (
        TG_OP = 'UPDATE'
        AND (OLD.entity_type IS DISTINCT FROM NEW.entity_type OR OLD.entity_id IS DISTINCT FROM NEW.entity_id)
    ) THEN
        IF OLD.entity_type = 'блюдо' THEN
            UPDATE trondin_food.product p
            SET rating = (
                SELECT ROUND(AVG(r.rating), 2)
                FROM trondin_food.review r
                WHERE r.entity_type = 'блюдо'
                  AND r.entity_id = OLD.entity_id
            )
            WHERE p.product_id = OLD.entity_id;
        ELSIF OLD.entity_type = 'ресторан' THEN
            UPDATE trondin_food.restaurant rest
            SET rating = (
                SELECT ROUND(AVG(r.rating), 2)
                FROM trondin_food.review r
                WHERE r.entity_type = 'ресторан'
                  AND r.entity_id = OLD.entity_id
            )
            WHERE rest.restaurant_id = OLD.entity_id;
        END IF;
    END IF;

    -- Пересчёт для новой сущности при INSERT или UPDATE
    IF TG_OP = 'INSERT' OR (
        TG_OP = 'UPDATE'
        AND (
            OLD.entity_type IS DISTINCT FROM NEW.entity_type
            OR OLD.entity_id IS DISTINCT FROM NEW.entity_id
            OR OLD.rating IS DISTINCT FROM NEW.rating
        )
    ) THEN
        IF NEW.entity_type = 'блюдо' THEN
            UPDATE trondin_food.product p
            SET rating = (
                SELECT ROUND(AVG(r.rating), 2)
                FROM trondin_food.review r
                WHERE r.entity_type = 'блюдо'
                  AND r.entity_id = NEW.entity_id
            )
            WHERE p.product_id = NEW.entity_id;
        ELSIF NEW.entity_type = 'ресторан' THEN
            UPDATE trondin_food.restaurant rest
            SET rating = (
                SELECT ROUND(AVG(r.rating), 2)
                FROM trondin_food.review r
                WHERE r.entity_type = 'ресторан'
                  AND r.entity_id = NEW.entity_id
            )
            WHERE rest.restaurant_id = NEW.entity_id;
        END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_review_rating_change ON trondin_food.review;
CREATE TRIGGER trg_review_rating_change
AFTER INSERT OR UPDATE OR DELETE
ON trondin_food.review
FOR EACH ROW
EXECUTE FUNCTION trondin_food.rating_change();


-- 3. Пересчёт агрегированного статуса оплаты заказа order.pay_status (BR-8.7)
CREATE OR REPLACE FUNCTION trondin_food.payment_pay_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = trondin_food, exts
AS $$
DECLARE
    v_new_pay_status trondin_food.order_pay_status;
BEGIN
    IF TG_OP = 'DELETE' OR (TG_OP = 'UPDATE' AND OLD.order_id IS DISTINCT FROM NEW.order_id) THEN
        SELECT CASE
            WHEN COUNT(*) FILTER (WHERE p.status = 'успех') > 0 THEN 'оплачен'::trondin_food.order_pay_status
            WHEN COUNT(*) > 0 AND COUNT(*) FILTER (WHERE p.status = 'ошибка') = COUNT(*) THEN 'ошибка'::trondin_food.order_pay_status
            ELSE 'ожидает'::trondin_food.order_pay_status
        END
        INTO v_new_pay_status
        FROM trondin_food.payment p
        WHERE p.order_id = OLD.order_id;

        UPDATE trondin_food."order" o
        SET pay_status = v_new_pay_status
        WHERE o.order_id = OLD.order_id
          AND o.pay_status IS DISTINCT FROM v_new_pay_status;
    END IF;

    IF TG_OP = 'INSERT' OR (
        TG_OP = 'UPDATE'
        AND (OLD.order_id IS DISTINCT FROM NEW.order_id OR OLD.status IS DISTINCT FROM NEW.status)
    ) THEN
        SELECT CASE
            WHEN COUNT(*) FILTER (WHERE p.status = 'успех') > 0 THEN 'оплачен'::trondin_food.order_pay_status
            WHEN COUNT(*) > 0 AND COUNT(*) FILTER (WHERE p.status = 'ошибка') = COUNT(*) THEN 'ошибка'::trondin_food.order_pay_status
            ELSE 'ожидает'::trondin_food.order_pay_status
        END
        INTO v_new_pay_status
        FROM trondin_food.payment p
        WHERE p.order_id = NEW.order_id;

        UPDATE trondin_food."order" o
        SET pay_status = v_new_pay_status
        WHERE o.order_id = NEW.order_id
          AND o.pay_status IS DISTINCT FROM v_new_pay_status;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_payment_pay_status_change ON trondin_food.payment;
CREATE TRIGGER trg_payment_pay_status_change
AFTER INSERT OR UPDATE OR DELETE
ON trondin_food.payment
FOR EACH ROW
EXECUTE FUNCTION trondin_food.payment_pay_status_change();
