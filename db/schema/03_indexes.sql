-- FOOD-101

SET search_path TO trondin_food, exts;

CREATE UNIQUE INDEX uq_address_location
    ON trondin_food.address (
        street,
        house_number,
        COALESCE(apartment_office, '')
    );

CREATE UNIQUE INDEX uq_payment_order_success
    ON trondin_food.payment (order_id)
    WHERE status = 'успех';


CREATE INDEX idx_client_address_address_id
    ON trondin_food.client_address (address_id);

CREATE INDEX idx_courier_pay_courier_id
    ON trondin_food.courier_pay (courier_id);

CREATE INDEX idx_product_category_id
    ON trondin_food.product (product_category_id);

CREATE INDEX idx_product_restaurant_id
    ON trondin_food.product (restaurant_id);

CREATE INDEX idx_order_client_id
    ON trondin_food."order" (client_id);

CREATE INDEX idx_order_address_id
    ON trondin_food."order" (address_id);

CREATE INDEX idx_order_restaurant_id
    ON trondin_food."order" (restaurant_id);

CREATE INDEX idx_order_courier_id
    ON trondin_food."order" (courier_id);

CREATE INDEX idx_order_structure_product_id
    ON trondin_food.order_structure (product_id);

CREATE INDEX idx_payment_order_id
    ON trondin_food.payment (order_id);

CREATE INDEX idx_review_client_id
    ON trondin_food.review (client_id);

CREATE INDEX idx_review_entity
    ON trondin_food.review (entity_type, entity_id);

