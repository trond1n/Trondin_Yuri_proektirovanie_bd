-- FOOD-101

SET search_path TO trondin_food, exts, public;


CREATE TABLE trondin_food.address (
address_id       UUID         NOT NULL DEFAULT exts.uuid_generate_v4(),
    street           VARCHAR(150) NOT NULL,
    house_number     VARCHAR(15)  NOT NULL,
    apartment_office VARCHAR(15)  NULL,

    
    CONSTRAINT pk_address
        PRIMARY KEY (address_id),
    
    CONSTRAINT chk_address_street
        CHECK (street ~ '\S'),
    
    CONSTRAINT chk_address_street_trimmed
        CHECK (street !~ '^\s|\s$'),
    
    CONSTRAINT chk_address_house_number
        CHECK (house_number ~ '\S'),
    
    CONSTRAINT chk_address_house_number_trimmed
        CHECK (house_number !~ '^\s|\s$'),
    
    CONSTRAINT chk_address_apartment_office
        CHECK (apartment_office ~ '\S'),
    
    CONSTRAINT chk_address_apartment_office_trimmed
        CHECK (apartment_office !~ '^\s|\s$')
);

CREATE TABLE trondin_food.client (
    client_id    UUID        NOT NULL DEFAULT exts.uuid_generate_v4(),
    login        VARCHAR(50) NOT NULL,
    password     CHAR(32)    NOT NULL,
    phone_number CHAR(11)    NOT NULL,

    
    CONSTRAINT pk_client
        PRIMARY KEY (client_id),
    
    CONSTRAINT uq_client_login
        UNIQUE (login),
    
    CONSTRAINT uq_client_phone_number
        UNIQUE (phone_number),
    
    CONSTRAINT chk_client_login
        CHECK (login ~ '\S'),
    
    CONSTRAINT chk_client_login_trimmed
        CHECK (login !~ '^\s|\s$'),
    
    CONSTRAINT chk_client_password_md5
        CHECK (password ~ '^[0-9a-f]{32}$'),
    
    CONSTRAINT chk_client_phone_number
        CHECK (phone_number ~ '^7[0-9]{10}$')
);


CREATE TABLE trondin_food.courier (
    courier_id     UUID         NOT NULL DEFAULT exts.uuid_generate_v4(),
    fio            VARCHAR(150) NOT NULL,
    phone_number   CHAR(11)     NOT NULL,
    status         trondin_food.courier_status NOT NULL DEFAULT 'свободен',
    hire_date      DATE         NOT NULL DEFAULT CURRENT_DATE,
    dismissal_date DATE,
    coefficient    NUMERIC(2,1) NOT NULL DEFAULT 0.1,

    CONSTRAINT pk_courier
        PRIMARY KEY (courier_id),

    CONSTRAINT chk_courier_fio
        CHECK (fio ~ '\S'),

    CONSTRAINT chk_courier_fio_trimmed
        CHECK (fio !~ '^\s|\s$'),

    CONSTRAINT chk_courier_phone_number
        CHECK (phone_number ~ '^7[0-9]{10}$'),

    CONSTRAINT chk_courier_coefficient
        CHECK (coefficient BETWEEN 0.1 AND 0.5),

    CONSTRAINT chk_courier_dismissal_date
        CHECK (
            dismissal_date IS NULL
            OR dismissal_date >= hire_date
        ),

    CONSTRAINT chk_courier_dismissal_status
        CHECK (
            (status = 'уволен' AND dismissal_date IS NOT NULL)
            OR status <> 'уволен'
        )
);



CREATE TABLE trondin_food.product_category (
    product_category_id   UUID         NOT NULL DEFAULT exts.uuid_generate_v4(),
    product_category_name VARCHAR(100) NOT NULL,

    CONSTRAINT pk_product_category
        PRIMARY KEY (product_category_id),

    CONSTRAINT chk_product_category_name
        CHECK (product_category_name ~ '\S'),

    CONSTRAINT chk_product_category_name_trimmed
        CHECK (product_category_name !~ '^\s|\s$')
);


CREATE TABLE trondin_food.client_address (
    client_id  UUID NOT NULL,
    address_id UUID NOT NULL,

    CONSTRAINT pk_client_address
        PRIMARY KEY (client_id, address_id),

    CONSTRAINT fk_client_address_client
        FOREIGN KEY (client_id)
        REFERENCES trondin_food.client (client_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_client_address_address
        FOREIGN KEY (address_id)
        REFERENCES trondin_food.address (address_id)
        ON DELETE RESTRICT
);

CREATE TABLE trondin_food.restaurant (
    restaurant_id   UUID         NOT NULL DEFAULT exts.uuid_generate_v4(),
    restaurant_name VARCHAR(100) NOT NULL,
    address_id      UUID         NOT NULL,
    description     TEXT         NOT NULL,
    work_start      TIME         NOT NULL,
    work_end        TIME         NOT NULL,
    company_details TEXT         NOT NULL,
    rating          NUMERIC(3,2),
    status          trondin_food.restaurant_status NOT NULL DEFAULT 'активен',

    CONSTRAINT pk_restaurant
        PRIMARY KEY (restaurant_id),

    CONSTRAINT uq_restaurant_address
        UNIQUE (address_id),

    CONSTRAINT fk_restaurant_address
        FOREIGN KEY (address_id)
        REFERENCES trondin_food.address (address_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_restaurant_name
        CHECK (restaurant_name ~ '\S'),

    CONSTRAINT chk_restaurant_name_trimmed
        CHECK (restaurant_name !~ '^\s|\s$'),

    CONSTRAINT chk_restaurant_description
        CHECK (description ~ '\S'),

    CONSTRAINT chk_restaurant_company_details
        CHECK (company_details ~ '\S'),

    CONSTRAINT chk_restaurant_schedule
        CHECK (work_end > work_start),

    CONSTRAINT chk_restaurant_rating
        CHECK (rating BETWEEN 0 AND 5)
);


CREATE TABLE trondin_food.courier_pay (
    year             INTEGER       NOT NULL,
    month            INTEGER       NOT NULL,
    courier_id       UUID          NOT NULL,
    amount           NUMERIC(10,2) NOT NULL,
    coefficient_used NUMERIC(2,1)  NOT NULL,

    CONSTRAINT pk_courier_pay
        PRIMARY KEY (year, month, courier_id),

    CONSTRAINT fk_courier_pay_courier
        FOREIGN KEY (courier_id)
        REFERENCES trondin_food.courier (courier_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_courier_pay_month
        CHECK (month BETWEEN 1 AND 12),

    CONSTRAINT chk_courier_pay_amount
        CHECK (amount >= 0),

    CONSTRAINT chk_courier_pay_coefficient_used
        CHECK (coefficient_used BETWEEN 0.1 AND 0.5)
);

CREATE TABLE trondin_food.product (
    product_id          UUID          NOT NULL DEFAULT exts.uuid_generate_v4(),
    product_name        VARCHAR(100)  NOT NULL,
    product_category_id UUID          NOT NULL,
    price               NUMERIC(10,2) NOT NULL,
    restaurant_id       UUID          NOT NULL,
    photo_url           TEXT,
    rating              NUMERIC(3,2),
    status              trondin_food.product_status NOT NULL DEFAULT 'доступно',
    description         TEXT          NOT NULL,

    CONSTRAINT pk_product
        PRIMARY KEY (product_id),

    CONSTRAINT uq_product_id_restaurant
        UNIQUE (product_id, restaurant_id),

    CONSTRAINT fk_product_restaurant
        FOREIGN KEY (restaurant_id)
        REFERENCES trondin_food.restaurant (restaurant_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_product_category
        FOREIGN KEY (product_category_id)
        REFERENCES trondin_food.product_category (product_category_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_product_name
        CHECK (product_name ~ '\S'),

    CONSTRAINT chk_product_name_trimmed
        CHECK (product_name !~ '^\s|\s$'),

    CONSTRAINT chk_product_description
        CHECK (description ~ '\S'),

    CONSTRAINT chk_product_photo_url
        CHECK (
            photo_url IS NULL
            OR photo_url ~ '\S'
        ),

    CONSTRAINT chk_product_price
        CHECK (price >= 0),

    CONSTRAINT chk_product_rating
        CHECK (rating BETWEEN 0 AND 5)
);


CREATE TABLE trondin_food."order" (
    order_id           UUID          NOT NULL DEFAULT exts.uuid_generate_v4(),
    courier_id         UUID          NOT NULL,
    client_id          UUID          NOT NULL,
    address_id         UUID          NOT NULL,
    restaurant_id      UUID          NOT NULL,
    order_timestamp    TIMESTAMP     NOT NULL DEFAULT LOCALTIMESTAMP,
    delivery_timestamp TIMESTAMP,
    order_amount       NUMERIC(10,2) NOT NULL,
    commission         NUMERIC(10,2) NOT NULL,
    total_amount       NUMERIC(10,2) NOT NULL,
    status             trondin_food.order_status NOT NULL DEFAULT 'создан',
    pay_status         trondin_food.order_pay_status NOT NULL DEFAULT 'ожидает',
    description        TEXT          NOT NULL,

    CONSTRAINT pk_order
        PRIMARY KEY (order_id),

    CONSTRAINT uq_order_id_restaurant
        UNIQUE (order_id, restaurant_id),

    CONSTRAINT uq_order_id_client
        UNIQUE (order_id, client_id),

    CONSTRAINT uq_order_id_total_amount
        UNIQUE (order_id, total_amount),

    CONSTRAINT fk_order_courier
        FOREIGN KEY (courier_id)
        REFERENCES trondin_food.courier (courier_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_order_restaurant
        FOREIGN KEY (restaurant_id)
        REFERENCES trondin_food.restaurant (restaurant_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_order_client
        FOREIGN KEY (client_id)
        REFERENCES trondin_food.client (client_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_order_address
        FOREIGN KEY (address_id)
        REFERENCES trondin_food.address (address_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_order_client_address
        FOREIGN KEY (client_id, address_id)
        REFERENCES trondin_food.client_address (client_id, address_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_order_description
        CHECK (description ~ '\S'),

    CONSTRAINT chk_order_order_amount
        CHECK (order_amount > 0),

    CONSTRAINT chk_order_commission
        CHECK (commission = ROUND(order_amount * 0.10, 2)),

    CONSTRAINT chk_order_total_amount_sum
        CHECK (total_amount = order_amount + commission),

    CONSTRAINT chk_order_min_total
        CHECK (total_amount >= 1000),

    CONSTRAINT chk_order_delivery_timestamp_order
        CHECK (
            delivery_timestamp IS NULL
            OR delivery_timestamp >= order_timestamp
        ),

    CONSTRAINT chk_order_delivery_status_sync
        CHECK (
            (status = 'доставлен' AND delivery_timestamp IS NOT NULL)
            OR
            (status <> 'доставлен' AND delivery_timestamp IS NULL)
        )
);

CREATE TABLE trondin_food.review (
    review_id        UUID          NOT NULL DEFAULT exts.uuid_generate_v4(),
    client_id        UUID          NOT NULL,
    order_id         UUID          NOT NULL,
    review_timestamp TIMESTAMP     NOT NULL DEFAULT LOCALTIMESTAMP,
    entity_type      trondin_food.review_entity_type NOT NULL,
    entity_id        UUID          NOT NULL,
    description      TEXT          NOT NULL,
    photo_url        TEXT,
    rating           SMALLINT      NOT NULL,

    CONSTRAINT pk_review
        PRIMARY KEY (review_id),

    CONSTRAINT uq_review_order_entity
        UNIQUE (order_id, entity_type, entity_id),

    CONSTRAINT fk_review_order
        FOREIGN KEY (order_id)
        REFERENCES trondin_food."order" (order_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_review_client
        FOREIGN KEY (client_id)
        REFERENCES trondin_food.client (client_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_review_order_client
        FOREIGN KEY (order_id, client_id)
        REFERENCES trondin_food."order" (order_id, client_id)
        ON DELETE CASCADE,

    CONSTRAINT chk_review_description
        CHECK (description ~ '\S'),

    CONSTRAINT chk_review_photo_url
        CHECK (
            photo_url IS NULL
            OR photo_url ~ '\S'
        ),

    CONSTRAINT chk_review_rating
        CHECK (rating BETWEEN 1 AND 5)
);

CREATE TABLE trondin_food.order_structure (
    order_id      UUID         NOT NULL,
    product_id    UUID         NOT NULL,
    restaurant_id UUID         NOT NULL,
    quantity      NUMERIC(8,3) NOT NULL,

    CONSTRAINT pk_order_structure
        PRIMARY KEY (order_id, product_id),

    CONSTRAINT fk_order_structure_order
        FOREIGN KEY (order_id)
        REFERENCES trondin_food."order" (order_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_order_structure_product
        FOREIGN KEY (product_id)
        REFERENCES trondin_food.product (product_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_order_structure_order_restaurant
        FOREIGN KEY (order_id, restaurant_id)
        REFERENCES trondin_food."order" (order_id, restaurant_id),

    CONSTRAINT fk_order_structure_product_restaurant
        FOREIGN KEY (product_id, restaurant_id)
        REFERENCES trondin_food.product (product_id, restaurant_id),

    CONSTRAINT chk_order_structure_quantity
        CHECK (quantity > 0)
);

CREATE TABLE trondin_food.payment (
    payment_id        UUID          NOT NULL DEFAULT exts.uuid_generate_v4(),
    order_id          UUID          NOT NULL,
    payment_type      trondin_food.payment_type   NOT NULL,
    amount            NUMERIC(10,2) NOT NULL,
    transaction_id    VARCHAR(100)  NOT NULL,
    payment_timestamp TIMESTAMP     NOT NULL DEFAULT LOCALTIMESTAMP,
    status            trondin_food.payment_status NOT NULL DEFAULT 'в_обработке',


CONSTRAINT pk_payment
        PRIMARY KEY (payment_id),
    
    CONSTRAINT uq_payment_transaction_id
        UNIQUE (transaction_id),
    
    CONSTRAINT fk_payment_order
        FOREIGN KEY (order_id)
        REFERENCES trondin_food."order" (order_id) ON DELETE RESTRICT,
    
    CONSTRAINT fk_payment_order_amount
        FOREIGN KEY (order_id, amount)
        REFERENCES trondin_food."order" (order_id, total_amount) ON DELETE RESTRICT ON UPDATE CASCADE,
    
    CONSTRAINT chk_payment_amount
        CHECK (amount >= 1000),
    
    CONSTRAINT chk_payment_transaction_id
        CHECK (transaction_id ~ '\S'),
    
    CONSTRAINT chk_payment_transaction_id_trimmed
        CHECK (transaction_id !~ '^\s|\s$')
);
