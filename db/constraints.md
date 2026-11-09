# Обоснование ограничений

## Как заполнять

- **CHECK, UNIQUE, FK** — обосновывать обязательно. Ссылка на `BR-N.M` + краткое «почему».
- **NOT NULL** — обосновывать **только** когда бизнес явно требует. Очевидные случаи (PK, FK на NOT NULL поле, поля из BR с явным «обязательно») — не дублировать.
- **NULL** (где разрешено) — обосновывать, потому что это осознанное решение, а не забывчивость.
- **DEFAULT, GENERATED** — кратко, если не очевидно.

**Правило:** если не можешь указать `BR-N.M` — либо ограничение лишнее, либо пропущено бизнес-правило. Разберись, прежде чем оставлять.

**Формат обоснования:** «<что ограничиваем> — потому что <BR-N.M> требует <что>».

Пример хорошего обоснования:

> `CHECK (rating BETWEEN 0 AND 5)` на `restaurant.rating` — потому что BR-4.2 задаёт диапазон рейтинга.

> `UNIQUE (address_id)` на `restaurant` — потому что BR-3.3 запрещает двум ресторанам делить один адрес.

> `FK (restaurant_id) → restaurant(restaurant_id)` на `product` — потому что BR-5.1 требует, чтобы блюдо принадлежало ресторану.

Пример плохого обоснования (не принимается):

> `NOT NULL` на `name` — потому что имя должно быть.

> `CHECK` на `price` — потому что цена не может быть отрицательной.

(Второе — обоснование «здравым смыслом», а не ссылкой на BR. Не принимается.)

---

## Enum-типы

Перечисли типы, которые создал. Если добавил/изменил значения относительно BR — обоснуй.

| Тип | Значения | BR |
|---|---|---|
| `trondin_food.restaurant_status` | `'активен'`, `'неактивен'` | BR-4.3, BR-11.5 |
| `trondin_food.product_status` | `'доступно'`, `'нет_в_наличии'`, `'архив'` | BR-5.5, BR-11.5 |
| `trondin_food.courier_status` | `'свободен'`, `'занят'`, `'на_доставке'`, `'уволен'` | BR-6.2, BR-11.5 |
| `trondin_food.order_status` | `'создан'`, `'готовится'`, `'в_доставке'`, `'доставлен'`, `'отменён'` | BR-7.7, BR-11.5 |
| `trondin_food.order_pay_status` | `'ожидает'`, `'оплачен'`, `'ошибка'` | BR-7.9, BR-11.5 |
| `trondin_food.payment_type` | `'карта'`, `'наличные'`, `'безнал'` | BR-8.2, BR-11.5 |
| `trondin_food.payment_status` | `'успех'`, `'ошибка'`, `'в_обработке'` | BR-8.2, BR-11.5 |
| `trondin_food.review_entity_type` | `'блюдо'`, `'ресторан'`, `'заказ'` | BR-9.1, BR-11.5 |

Все 8 перечислений созданы как `CREATE TYPE ... AS ENUM` со значениями из `docs/company-rules.md` без добавлений и переименований.

---

## Ловушки

Здесь — не готовые решения, а **фиксация того, как ты решил** каждую ловушку. Преподаватель читает, чтобы понять ход мысли.

### Ловушка 1: `payment` — неполная сущность

**Какие атрибуты добавил в `payment` и почему** (BR-8.2):

В `docs/erd.md` у `payment` указаны только `payment_id` и `order_id`. Для выполнения правил раздела 8 (BR-8.1–BR-8.7) в таблицу `trondin_food.payment` добавлены 5 обязательных (`NOT NULL`) атрибутов:
1. `payment_type trondin_food.payment_type NOT NULL` — способ оплаты (`'карта'`, `'наличные'`, `'безнал'`), необходим для фиксации способа конкретной попытки оплаты (BR-8.2, BR-8.6).
2. `amount NUMERIC(10,2) NOT NULL` — сумма попытки оплаты (BR-8.2); по BR-8.4 она совпадает с общей суммой заказа `order.total_amount`, что обеспечивается составным внешним ключом `fk_payment_order_amount (order_id, amount) REFERENCES "order" (order_id, total_amount)` и ограничением `chk_payment_amount (amount >= 1000)`.
3. `transaction_id VARCHAR(100) NOT NULL` — внешний идентификатор финансовой транзакции от платежного провайдера (BR-1.7, BR-8.2, BR-8.3, BR-8.5; данные банковских карт не хранятся), уникальность защищена ограничением `uq_payment_transaction_id`.
4. `payment_timestamp TIMESTAMP NOT NULL DEFAULT LOCALTIMESTAMP` — дата и время транзакции в часовом поясе сервера (BR-8.2, BR-11.2).
5. `status trondin_food.payment_status NOT NULL DEFAULT 'в_обработке'` — статус попытки оплаты (`'успех'`, `'ошибка'`, `'в_обработке'`, BR-8.2).

Частичный уникальный индекс `uq_payment_order_success ON payment (order_id) WHERE status = 'успех'` обеспечивает, что успешная оплата у заказа **не более одной**. Схема не требует обязательного наличия успешной оплаты, так как по BR-8.7 заказ может находиться в статусах `'ожидает'` или `'ошибка'`. Генератор создаёт ровно одну успешную оплату на заказ, а статус `order.pay_status` обновляется триггером `trg_payment_pay_status_change` на таблице `payment`.

**Где хранится тип оплаты — `payment` или `order`** (BR-8.6):

В таблице `payment` (столбец `payment.payment_type`). По BR-8.6 тип оплаты относится к конкретной попытке оплаты, а не к заказу в целом. У одного заказа может быть несколько попыток с разными способами оплаты (например, неуспешная оплата картой и последующая успешная оплата наличными при получении). Хранение `payment_type` в `"order"` противоречит BR-8.6 и не позволяет сохранять разные типы оплаты для разных попыток одного заказа.

### Ловушка 2: `order.address_id` — принадлежность клиенту (BR-7.4)

**Как обеспечено, что адрес доставки принадлежит клиенту:**

Реализовано декларативно на уровне БД через **составной внешний ключ** на таблицу связей `client_address`:

```sql
CONSTRAINT fk_order_client_address
    FOREIGN KEY (client_id, address_id)
    REFERENCES trondin_food.client_address (client_id, address_id)
    ON DELETE RESTRICT
```

В таблице `client_address` пара `(client_id, address_id)` является первичным ключом (`pk_client_address`). Обычный внешний ключ `fk_order_address (address_id) → address(address_id)` проверяет лишь существование адреса в справочнике, а составной внешний ключ `fk_order_client_address (client_id, address_id) → client_address(client_id, address_id)` обеспечивает, что заказ оформляется только на адрес данного клиента (BR-7.4), без триггеров и проверок только в коде приложения.

### Ловушка 3: `order_structure` — один ресторан в заказе (BR-7.3)

**Как обеспечено, что все блюда из `order.restaurant_id`:**

Реализовано декларативно через два составных внешних ключа с общим столбцом `restaurant_id` в таблице `order_structure`:
1. В родительских таблицах созданы технические ограничения уникальности: `uq_order_id_restaurant UNIQUE (order_id, restaurant_id)` в таблице `"order"` и `uq_product_id_restaurant UNIQUE (product_id, restaurant_id)` в таблице `product`.
2. В таблицу `order_structure` добавлен столбец `restaurant_id UUID NOT NULL` и два составных внешних ключа:

```sql
CONSTRAINT fk_order_structure_order_restaurant
    FOREIGN KEY (order_id, restaurant_id)
    REFERENCES trondin_food."order" (order_id, restaurant_id),

CONSTRAINT fk_order_structure_product_restaurant
    FOREIGN KEY (product_id, restaurant_id)
    REFERENCES trondin_food.product (product_id, restaurant_id)
```

Поскольку оба внешних ключа в строке `order_structure` опираются на один и тот же столбец `restaurant_id`, СУБД обеспечивает равенство `order.restaurant_id = order_structure.restaurant_id = product.restaurant_id`. Вставить в заказ блюдо из другого ресторана невозможно на уровне ограничений целостности БД.

**Контроль непустого состава заказа:** трактуем BR-7.14 (заказ содержит одну или несколько позиций) как требование к схеме по аналогии с BR-11.4. Обычный `CHECK` не видит соседнюю таблицу, а немедленный триггер упал бы при создании заказа до вставки его позиций.
Решение — единая функция `check_order_has_items()` и два отложенных триггера (`CREATE CONSTRAINT TRIGGER ... DEFERRABLE INITIALLY DEFERRED`):
1. `trg_order_check_items` на `"order"` (`AFTER INSERT`) — откладывает проверку до `COMMIT`, требуя наличия хотя бы одной позиции;
2. `trg_order_structure_check_items` на `order_structure` (`AFTER DELETE OR UPDATE OF order_id`) — откладывает проверку до `COMMIT` при удалении или переносе позиций.

При каскадном удалении заказа (`ON DELETE CASCADE`) функция пропускает проверку, если сам заказ уже удален из `"order"`.
*Нюанс:* при ручной вставке в DBeaver заказ и позиции нужно вставлять в одной транзакции (`BEGIN; ... COMMIT;`), иначе проверка сработает на автокоммите первого оператора.

### Ловушка 4: `review` — полиморфизм (BR-9.1)

**Как реализована валидность `review.entity_id`:**

Выбран гибридный вариант: полиморфная связь `(entity_type, entity_id)` по контракту `docs/erd.md` + составной FK для проверки автора заказа + триггер для проверки целевой сущности:
1. Почему нет обычного FK на `entity_id`: по `docs/erd.md` и BR-9.1 отзывы на блюдо, ресторан и заказ хранятся в одной таблице `review`, где `entity_id UUID` в зависимости от `entity_type` (`'блюдо'`, `'ресторан'`, `'заказ'`) указывает на PK одной из трех разных таблиц (`product`, `restaurant`, `"order"`). В реляционной модели стандартный `FOREIGN KEY` не может условно ссылаться на разные таблицы по значению соседнего столбца.
2. **Защита автора заказа (BR-9.2):** в таблице `"order"` создано ограничение `uq_order_id_client UNIQUE (order_id, client_id)`, на которое ссылается составной внешний ключ `fk_review_order_client FOREIGN KEY (order_id, client_id) REFERENCES "order" (order_id, client_id) ON DELETE CASCADE`. Это обеспечивает, что отзыв по заказу может оставить только клиент, оформивший этот заказ.
3. Триггерная проверка `entity_id` (BR-9.1, BR-9.2): триггер `trg_review_check_entity` (`BEFORE INSERT OR UPDATE OF order_id, entity_type, entity_id ON review`, функция `check_review_entity()` в `db/schema/05_triggers.sql`) проверяет, что оцениваемая сущность существует и относится к заказу `NEW.order_id`:
   - при `entity_type = 'заказ'` требует `NEW.entity_id = NEW.order_id`;
   - при `entity_type = 'ресторан'` проверяет, что в `"order"` для `NEW.order_id` указан `restaurant_id = NEW.entity_id`;
   - при `entity_type = 'блюдо'` проверяет наличие строки в `order_structure` с `order_id = NEW.order_id` и `product_id = NEW.entity_id`.

   Следствие BR-9.2 (наше решение): триггер `trg_order_structure_check_reviewed_item` (`BEFORE DELETE OR UPDATE OF order_id, product_id ON order_structure`) запрещает удалять позицию или менять её блюдо, если на неё уже оставлен отзыв (изменение `quantity` разрешено). При каскадном удалении заказа проверка пропускается аналогично функции `check_order_has_items`.

---

## CHECK-ограничения

Каждое — с ссылкой на BR.

| Таблица | Столбец | Условие | BR | Обоснование |
|---|---|---|---|---|
| `address` | `street` | `chk_address_street`: `trim(street) <> ''` | BR-3.1, BR-11.6* | Непустая строка (см. сноску). |
| `address` | `house_number` | `chk_address_house_number`: `trim(house_number) <> ''` | BR-3.1, BR-11.6* | Непустая строка (см. сноску). |
| `address` | `apartment_office` | `chk_address_apartment_office`: `apartment_office IS NULL OR trim(apartment_office) <> ''` | BR-3.1, BR-3.2, BR-11.6* | Если указана, не может быть пустой строкой (см. сноску). |
| `client` | `login` | `chk_client_login`: `trim(login) <> ''` | BR-2.1, BR-2.6, BR-11.6* | Непустая строка (см. сноску). |
| `client` | `password` | `chk_client_password_md5`: `password ~ '^[0-9a-f]{32}$'` | BR-2.3, BR-11.6 | 32-значный hex MD5 в нижнем регистре — BR-2.3 требует MD5, нижний регистр выбран по нашему решению (BR-11.6). |
| `client` | `phone_number` | `chk_client_phone_number`: `phone_number ~ '^7[0-9]{10}$'` | BR-2.1, BR-2.2, BR-11.6 | Телефон в формате `7XXXXXXXXXX` — наше решение (BR-11.6) для уникальности (BR-2.2). |
| `courier` | `fio` | `chk_courier_fio`: `trim(fio) <> ''` | BR-6.1, BR-11.6* | Непустая строка (см. сноску). |
| `courier` | `phone_number` | `chk_courier_phone_number`: `phone_number ~ '^7[0-9]{10}$'` | BR-6.1, BR-11.6 | Телефон в формате `7XXXXXXXXXX` — наше решение (BR-11.6) для единообразия (BR-6.1). |
| `courier` | `coefficient` | `chk_courier_coefficient`: `coefficient BETWEEN 0.1 AND 0.5` | BR-6.4 | Коэффициент в диапазоне `0.1`–`0.5` по BR-6.4. |
| `courier` | `dismissal_date`, `hire_date` | `chk_courier_dismissal_date`: `dismissal_date IS NULL OR dismissal_date >= hire_date` | BR-6.1, BR-6.3, BR-11.6 | Дата увольнения не раньше найма — наше решение (BR-6.1, BR-6.3, BR-11.6) для непротиворечивости дат. |
| `courier` | `status`, `dismissal_date` | `chk_courier_dismissal_status`: `(status = 'уволен' AND dismissal_date IS NOT NULL) OR (status <> 'уволен' AND dismissal_date IS NULL)` | BR-6.2, BR-6.3, BR-11.3, BR-11.6 | У уволенного курьера дата увольнения обязательна (BR-6.3), у работающего отсутствует. Двусторонний CHECK — наша трактовка BR-6.3 и BR-11.3 (наше решение). |
| `product_category` | `product_category_name` | `chk_product_category_name`: `trim(product_category_name) <> ''` | BR-5.7, BR-11.6* | Непустая строка (см. сноску). |
| `restaurant` | `restaurant_name` | `chk_restaurant_name`: `trim(restaurant_name) <> ''` | BR-4.1, BR-11.6* | Непустая строка (см. сноску). |
| `restaurant` | `description` | `chk_restaurant_description`: `trim(description) <> ''` | BR-4.1, BR-11.6* | Непустая строка (см. сноску). |
| `restaurant` | `company_details` | `chk_restaurant_company_details`: `trim(company_details) <> ''` | BR-4.1, BR-4.5, BR-11.6* | Непустая строка (см. сноску). |
| `restaurant` | `work_start`, `work_end` | `chk_restaurant_schedule`: `work_end > work_start` | BR-4.4 | Закрытие позже открытия по BR-4.4 (ресторан не работает через полночь). |
| `restaurant` | `rating` | `chk_restaurant_rating`: `rating BETWEEN 0 AND 5` | BR-4.2 | Рейтинг от `0` до `5` по BR-4.2. |
| `courier_pay` | `month` | `chk_courier_pay_month`: `month BETWEEN 1 AND 12` | BR-10.1, BR-10.2 | Месяц от `1` до `12` по BR-10.1, BR-10.2. |
| `courier_pay` | `amount` | `chk_courier_pay_amount`: `amount >= 0` | BR-10.4 | Сумма выплаты курьеру неотрицательна по BR-10.4. |
| `courier_pay` | `coefficient_used` | `chk_courier_pay_coefficient_used`: `coefficient_used BETWEEN 0.1 AND 0.5` | BR-6.4, BR-10.2 | Коэффициент в диапазоне `0.1`–`0.5` по BR-6.4, BR-10.2. |
| `product` | `product_name` | `chk_product_name`: `trim(product_name) <> ''` | BR-5.2, BR-11.6* | Непустая строка (см. сноску). |
| `product` | `description` | `chk_product_description`: `trim(description) <> ''` | BR-5.2, BR-11.6* | Непустая строка (см. сноску). |
| `product` | `photo_url` | `chk_product_photo_url`: `photo_url IS NULL OR trim(photo_url) <> ''` | BR-5.2, BR-5.6, BR-11.6* | Непустая ссылка на фото, если указана (BR-5.6, см. сноску). |
| `product` | `price` | `chk_product_price`: `price >= 0` | BR-5.3 | Цена неотрицательна по BR-5.3. |
| `product` | `rating` | `chk_product_rating`: `rating BETWEEN 0 AND 5` | BR-5.4 | Рейтинг от `0` до `5` по BR-5.4. |
| `"order"` | `description` | `chk_order_description`: `trim(description) <> ''` | BR-11.3, BR-11.6* | Непустая строка (см. сноску). |
| `"order"` | `order_amount` | `chk_order_order_amount`: `order_amount > 0` | BR-1.8, BR-7.10, BR-7.11 | Сумма стоимости блюд положительна (BR-7.10, BR-7.11). Исторический снимок суммы, не пересчитывается при смене цен блюд. |
| `"order"` | `commission`, `order_amount` | `chk_order_commission`: `commission = ROUND(order_amount * 0.10, 2)` | BR-1.4, BR-7.10 | Комиссия равна 10% от стоимости блюд по BR-1.4, BR-7.10. |
| `"order"` | `total_amount`, `order_amount`, `commission` | `chk_order_total_amount_sum`: `total_amount = order_amount + commission` | BR-1.5, BR-7.10 | Полная сумма по формуле `order_amount + commission` (BR-1.5, BR-7.10). |
| `"order"` | `total_amount` | `chk_order_min_total`: `total_amount >= 1000` | BR-1.8, BR-7.11 | Минимальная сумма заказа 1000 ₽ по BR-1.8, BR-7.11. |
| `"order"` | `delivery_timestamp`, `order_timestamp` | `chk_order_delivery_timestamp_order`: `delivery_timestamp IS NULL OR delivery_timestamp >= order_timestamp` | BR-7.13 | Доставка не раньше создания заказа по BR-7.13. |
| `"order"` | `status`, `delivery_timestamp` | `chk_order_delivery_status_sync`: `(status = 'доставлен' AND delivery_timestamp IS NOT NULL) OR (status <> 'доставлен' AND delivery_timestamp IS NULL)` | BR-7.12, BR-11.3, BR-11.6 | Время доставки заполнено тогда и только тогда, когда статус `'доставлен'`. Заполнение при доставке — по BR-7.12; обязательность NULL до доставки — строже BR-7.12 (наше решение). |
| `review` | `description` | `chk_review_description`: `trim(description) <> ''` | BR-9.3, BR-11.6* | Непустая строка (см. сноску). |
| `review` | `photo_url` | `chk_review_photo_url`: `photo_url IS NULL OR trim(photo_url) <> ''` | BR-9.3, BR-11.6* | Непустая ссылка на фото, если указана (BR-9.3, см. сноску). |
| `review` | `rating` | `chk_review_rating`: `rating BETWEEN 1 AND 5` | BR-9.4 | Оценка от 1 до 5 по BR-9.4. |
| `order_structure` | `quantity` | `chk_order_structure_quantity`: `quantity > 0` | BR-7.15 | Положительное количество по BR-7.15. |
| `payment` | `amount` | `chk_payment_amount`: `amount >= 1000` | BR-1.8, BR-7.11, BR-8.4 | Сумма оплаты равна общей сумме заказа (BR-8.4), которая не менее 1000 ₽ (BR-1.8, BR-7.11). |
| `payment` | `transaction_id` | `chk_payment_transaction_id`: `trim(transaction_id) <> ''` | BR-8.2, BR-8.3, BR-11.6* | Непустая строка (см. сноску). |

\* **Сноска по непустым строкам (наше решение):** пустую строку или строку из одних пробелов приравниваем к отсутствию значения (`trim(...) <> ''`) — наше решение (BR-11.3, BR-11.6), иначе пустая строка обходила бы `NOT NULL`.

---

## UNIQUE-ограничения

| Таблица | Столбцы | BR | Обоснование |
|---|---|---|---|
| `address` | `address_id` (`pk_address`) | BR-3.1, BR-3.4, BR-11.1 | Суррогатный первичный ключ физического адреса — по BR-11.1 каждая сущность идентифицируется UUID, что позволяет связывать адрес с клиентами и рестораном (BR-3.4). |
| `client` | `client_id` (`pk_client`) | BR-2.1, BR-11.1 | Суррогатный первичный ключ клиента — по BR-11.1. |
| `courier` | `courier_id` (`pk_courier`) | BR-6.1, BR-11.1 | Суррогатный первичный ключ курьера — по BR-11.1. |
| `product_category` | `product_category_id` (`pk_product_category`) | BR-5.7, BR-11.1 | Первичный ключ справочника категорий — по BR-5.7, BR-11.1. |
| `restaurant` | `restaurant_id` (`pk_restaurant`) | BR-4.1, BR-11.1 | Суррогатный первичный ключ ресторана — по BR-11.1. |
| `product` | `product_id` (`pk_product`) | BR-5.1, BR-5.2, BR-11.1 | Суррогатный первичный ключ блюда — по BR-11.1. |
| `"order"` | `order_id` (`pk_order`) | BR-7.1, BR-11.1 | Суррогатный первичный ключ заказа — по BR-11.1. |
| `review` | `review_id` (`pk_review`) | BR-9.1, BR-9.2, BR-11.1 | Суррогатный первичный ключ отзыва — по BR-11.1. |
| `payment` | `payment_id` (`pk_payment`) | BR-8.1, BR-8.2, BR-11.1 | Суррогатный первичный ключ попытки оплаты — по BR-8.1, BR-11.1. |
| `client` | `login` (`uq_client_login`) | BR-2.2, BR-11.6 | Уникальность логина клиента по BR-2.2. Логин чувствителен к регистру — наше решение (BR-11.6). |
| `client` | `phone_number` (`uq_client_phone_number`) | BR-2.2, BR-11.6 | Уникальность номера телефона клиента — по BR-2.2. |
| `client_address` | `(client_id, address_id)` (`pk_client_address`) | BR-2.5 | Составной первичный ключ связки клиента и адреса — по BR-2.5 запрещено дублирование адреса у клиента. |
| `restaurant` | `address_id` (`uq_restaurant_address`) | BR-3.3, BR-3.4 | Уникальность адреса ресторана — по BR-3.3 рестораны не делят один адрес. |
| `courier_pay` | `(year, month, courier_id)` (`pk_courier_pay`) | BR-10.3 | Составной первичный ключ выплаты — по BR-10.3 ровно одна запись на курьера за месяц. |
| `product` | `(product_id, restaurant_id)` (`uq_product_id_restaurant`) | BR-5.1, BR-7.3 | Технический ключ для составного FK из `order_structure` (BR-7.3, Ловушка 3). |
| `"order"` | `(order_id, restaurant_id)` (`uq_order_id_restaurant`) | BR-7.2, BR-7.3 | Технический ключ для составного FK из `order_structure`, фиксирующий ресторан заказа (BR-7.3, Ловушка 3). |
| `"order"` | `(order_id, client_id)` (`uq_order_id_client`) | BR-7.2, BR-9.2 | Технический ключ для составного FK из `review`, подтверждающий автора заказа (BR-9.2, Ловушка 4). |
| `"order"` | `(order_id, total_amount)` (`uq_order_id_total_amount`) | BR-7.10, BR-8.4 | Технический ключ для составного FK из `payment`, фиксирующий сумму попытки оплаты (BR-8.4, Ловушка 1). |
| `order_structure` | `(order_id, product_id)` (`pk_order_structure`) | BR-7.16 | Составной первичный ключ позиции заказа — по BR-7.16 запрещены дубли блюд в заказе. |
| `review` | `(order_id, entity_type, entity_id)` (`uq_review_order_entity`) | BR-9.5 | Уникальность объекта отзыва в заказе — по BR-9.5 не более одного отзыва на объект. |
| `payment` | `transaction_id` (`uq_payment_transaction_id`) | BR-8.3, BR-11.6 | Уникальность идентификатора транзакции провайдера по BR-8.3. |
| `payment` | `(order_id) WHERE status = 'успех'` (`uq_payment_order_success`, частичный уникальный индекс в `03_indexes.sql`) | BR-8.1, BR-8.7 | Частичный уникальный индекс: не более одной успешной оплаты на заказ (наша трактовка BR-8.1 с учетом BR-8.7). |
| `address` | `(LOWER(street), LOWER(house_number), LOWER(COALESCE(apartment_office, '')))` (`uq_address_location`, уникальный индекс в `03_indexes.sql`) | BR-3.1, BR-3.2, BR-3.3, BR-3.4, BR-11.6 | Уникальность адреса без учета регистра — наше решение для исключения дублирования (BR-3.3, BR-3.4, BR-11.6). В локали `C` кириллица в `lower()` не меняется (осознанный риск). |

---

## FK-ограничения

| Таблица | Столбцы | → Таблица | BR | Обоснование |
|---|---|---|---|---|
| `client_address` | `client_id` (`fk_client_address_client`) | `client (client_id)` (`ON DELETE CASCADE`) | BR-2.4, BR-3.5 | Связь клиента с адресами доставки (BR-2.4); при удалении клиента удаляется только связка, сам адрес сохраняется (BR-3.5). |
| `client_address` | `address_id` (`fk_client_address_address`) | `address (address_id)` (`ON DELETE RESTRICT`) | BR-2.4, BR-3.4, BR-3.5 | Ссылка на адрес клиента — связка с адресом (BR-2.4, BR-3.4); RESTRICT — наше решение для сохранения адресов (BR-3.5). |
| `restaurant` | `address_id` (`fk_restaurant_address`) | `address (address_id)` (`ON DELETE RESTRICT`) | BR-3.3, BR-3.5 | Ссылка на адрес ресторана — по BR-3.3 у ресторана есть адрес; RESTRICT — наше решение для сохранения адресов (BR-3.5). |
| `courier_pay` | `courier_id` (`fk_courier_pay_courier`) | `courier (courier_id)` (`ON DELETE RESTRICT`) | BR-10.1, BR-10.2 | Привязка выплаты к курьеру — по BR-10.1, BR-10.2 зарплата начисляется существующему курьеру. |
| `product` | `restaurant_id` (`fk_product_restaurant`) | `restaurant (restaurant_id)` (`ON DELETE RESTRICT`) | BR-5.1 | Привязка блюда к ресторану — по BR-5.1 блюдо принадлежит одному ресторану. |
| `product` | `product_category_id` (`fk_product_category`) | `product_category (product_category_id)` (`ON DELETE RESTRICT`) | BR-5.1, BR-5.7 | Привязка блюда к категории по BR-5.1, BR-5.7. |
| `"order"` | `courier_id` (`fk_order_courier`) | `courier (courier_id)` (`ON DELETE RESTRICT`) | BR-1.3, BR-7.5 | Привязка заказа к курьеру — по BR-1.3 и BR-7.5 заказ доставляется курьером. |
| `"order"` | `restaurant_id` (`fk_order_restaurant`) | `restaurant (restaurant_id)` (`ON DELETE RESTRICT`) | BR-7.2 | Привязка заказа к ресторану — по BR-7.2 заказ относится к одному ресторану. |
| `"order"` | `client_id` (`fk_order_client`) | `client (client_id)` (`ON DELETE RESTRICT`) | BR-7.1, BR-7.2 | Привязка заказа к клиенту — по BR-7.1 заказ оформляет клиент. |
| `"order"` | `address_id` (`fk_order_address`) | `address (address_id)` (`ON DELETE RESTRICT`) | BR-1.3, BR-3.5, BR-7.4 | Прямая ссылка заказа на адрес по BR-1.3, BR-7.4; RESTRICT — сохранение истории заказов (BR-3.5). |
| `"order"` | `(client_id, address_id)` (`fk_order_client_address`) | `client_address (client_id, address_id)` (`ON DELETE RESTRICT`) | BR-7.4 | Составной FK — адрес доставки должен принадлежать клиенту заказа (BR-7.4, Ловушка 2). |
| `review` | `order_id` (`fk_review_order`) | `"order" (order_id)` (`ON DELETE CASCADE`) | BR-9.2 | Привязка отзыва к заказу по BR-9.2. |
| `review` | `client_id` (`fk_review_client`) | `client (client_id)` (`ON DELETE RESTRICT`) | BR-9.1, BR-9.2 | Привязка отзыва к клиенту по BR-9.1, BR-9.2. |
| `review` | `(order_id, client_id)` (`fk_review_order_client`) | `"order" (order_id, client_id)` (`ON DELETE CASCADE`) | BR-9.2 | Составной FK — отзыв может оставить только автор заказа (BR-9.2, Ловушка 4). |
| `order_structure` | `order_id` (`fk_order_structure_order`) | `"order" (order_id)` (`ON DELETE CASCADE`) | BR-7.14 | Привязка позиции к заказу по BR-7.14. Непустой состав контролируется отложенными триггерами (см. Ловушку 3). |
| `order_structure` | `product_id` (`fk_order_structure_product`) | `product (product_id)` (`ON DELETE RESTRICT`) | BR-7.14 | Привязка позиции к блюду по BR-7.14. |
| `order_structure` | `(order_id, restaurant_id)` (`fk_order_structure_order_restaurant`) | `"order" (order_id, restaurant_id)` | BR-7.3 | Составной FK позиции на заказ и ресторан — фиксация ресторана заказа в позиции (BR-7.3, Ловушка 3). |
| `order_structure` | `(product_id, restaurant_id)` (`fk_order_structure_product_restaurant`) | `product (product_id, restaurant_id)` | BR-7.3 | Составной FK позиции на блюдо и ресторан — запрет блюд из другого ресторана (BR-7.3, Ловушка 3). |
| `payment` | `order_id` (`fk_payment_order`) | `"order" (order_id)` (`ON DELETE RESTRICT`) | BR-8.1 | Привязка попытки оплаты к заказу по BR-8.1. |
| `payment` | `(order_id, amount)` (`fk_payment_order_amount`) | `"order" (order_id, total_amount)` (`ON DELETE RESTRICT ON UPDATE CASCADE`) | BR-8.4 | Составной FK на заказ и сумму — по BR-8.4 сумма оплаты равна сумме заказа (Ловушка 1). CASCADE держит равенство при правке суммы заказа. |

**Индексы внешних ключей и полиморфного поиска (`db/schema/03_indexes.sql`, 12 индексов `idx_*`):** PostgreSQL автоматически создает B-tree индексы для `PRIMARY KEY` и `UNIQUE`, но не индексирует столбцы `FOREIGN KEY`. В `03_indexes.sql` созданы 12 B-tree индексов (`idx_client_address_address_id`, `idx_courier_pay_courier_id`, `idx_product_category_id`, `idx_product_restaurant_id`, `idx_order_client_id`, `idx_order_address_id`, `idx_order_restaurant_id`, `idx_order_courier_id`, `idx_order_structure_product_id`, `idx_payment_order_id`, `idx_review_client_id`, `idx_review_entity`): они ускоряют `JOIN` по внешним ключам и каскадные проверки целостности.

---

## NOT NULL (только бизнес-обязательные)

Сюда — **только** те `NOT NULL`, которые нельзя объяснить очевидностью.

**Не дублируй:**
- PK (всегда NOT NULL по определению);
- FK на NOT NULL поле (очевидно, если родитель NOT NULL);
- поля из BR с явным «обязательно» — только если хочешь подчеркнуть, что это не случайность.

| Таблица | Столбец | BR | Обоснование |
|---|---|---|---|
| `"order"` | `courier_id` | BR-1.3, BR-7.5 | Курьер обязателен — по BR-1.3 и BR-7.5 каждый заказ доставляется курьером, самовывоза нет. |
| `"order"` | `address_id` | BR-1.3, BR-7.4 | Адрес доставки обязателен — по BR-1.3 и BR-7.4 заказы доставляются только по адресу клиента. |
| `order_structure` | `restaurant_id` | BR-7.3 | Ресторан позиции обязателен — необходим для составных FK Ловушки 3 (BR-7.3); при `NULL` составные FK пропускали бы проверку. |
| `payment` | `payment_type`, `amount`, `transaction_id`, `payment_timestamp`, `status` | BR-8.2, BR-8.3, BR-8.6 | Все атрибуты попытки оплаты (способ, сумма, идентификатор транзакции, время, статус) обязательны по BR-8.2, BR-8.3, BR-8.6. |
| `restaurant`, `product`, `"order"`, `review` | `description`, `company_details` | BR-4.1, BR-4.5, BR-5.2, BR-9.3, BR-11.3 | Описания, реквизиты и текст отзыва обязательны — по BR-11.3 всё, кроме разрешённых исключений, обязательно. |

---

## NULL (осознанно разрешено)

| Таблица | Столбец | BR | Почему NULL |
|---|---|---|---|
| `address` | `apartment_office` | BR-3.2, BR-11.3 | Квартира или офис необязательны — по BR-3.2 и BR-11.3 у частных домов номера квартиры нет. |
| `courier` | `dismissal_date` | BR-6.3, BR-11.3, BR-11.6 | У работающего курьера дата отсутствует. Двусторонний CHECK — наша трактовка BR-6.3 и BR-11.3 (наше решение). |
| `restaurant` | `rating` | BR-4.2, BR-9.6, BR-9.7 | При отсутствии отзывов рейтинг NULL по BR-9.7. |
| `product` | `photo_url` | BR-5.6, BR-11.3 | Фотография блюда необязательна по BR-5.6, BR-11.3. |
| `product` | `rating` | BR-5.4, BR-9.6, BR-9.7 | При отсутствии отзывов рейтинг NULL по BR-9.7. |
| `"order"` | `delivery_timestamp` | BR-7.12, BR-11.3, BR-11.6 | Время доставки пустое до завершения доставки. Обязательность NULL до доставки — строже BR-7.12 (наше решение). |
| `review` | `photo_url` | BR-9.3, BR-11.3 | Фотография в отзыве необязательна по BR-9.3, BR-11.3. |
| `get_statistic()` (результат функции) | `best_product_name`, `best_user` | FOOD-106, BR-13.2 | У ресторанов без доставок `best_product_name` и `best_user` равны `NULL` (FOOD-106, BR-13.2). При наличии доставок `best_product_name` не `NULL` благодаря контролю непустого состава (см. Ловушку 3). |
| `how_much_money` (результат представления) | `prev_commission`, `commission_diff` | FOOD-108, BR-11.9 | У первого месяца в выборке нет предшествующего месяца, поэтому `prev_commission` и `commission_diff` равны `NULL` (BR-11.9). |

---

## DEFAULT и GENERATED

| Таблица | Столбец | Что | Обоснование |
|---|---|---|---|
| `address`, `client`, `courier`, `product_category`, `restaurant`, `product`, `"order"`, `review`, `payment` | `*_id` | `DEFAULT exts.uuid_generate_v4()` | Генерация UUID на сервере по BR-11.1, BR-13.3. |
| `courier` | `coefficient` | `DEFAULT 0.1` | Начальный коэффициент нового курьера по BR-6.5. |
| `courier` | `status` | `DEFAULT 'свободен'` | Начальный статус нового курьера — наше решение (BR-6.2, BR-6.6, BR-11.6). |
| `courier` | `hire_date` | `DEFAULT CURRENT_DATE` | Текущая дата найма — наше решение (BR-6.1, BR-11.2, BR-11.6). |
| `restaurant` | `status` | `DEFAULT 'активен'` | Начальный статус ресторана — наше решение (BR-4.3, BR-11.6). |
| `product` | `status` | `DEFAULT 'доступно'` | Начальный статус блюда — наше решение (BR-5.5, BR-11.6). |
| `"order"` | `order_timestamp` | `DEFAULT LOCALTIMESTAMP` | Время создания заказа — наше решение (BR-7.1, BR-11.2, BR-11.6). |
| `"order"` | `status` | `DEFAULT 'создан'` | Начальный статус заказа — наше решение (BR-7.7, BR-11.6). |
| `"order"` | `pay_status` | `DEFAULT 'ожидает'` | Начальный статус оплаты — наше решение (BR-7.9, BR-8.7, BR-11.6). |
| `review` | `review_timestamp` | `DEFAULT LOCALTIMESTAMP` | Время создания отзыва — наше решение (BR-9.3, BR-11.2, BR-11.6). |
| `payment` | `payment_timestamp` | `DEFAULT LOCALTIMESTAMP` | Время транзакции — наше решение (BR-8.2, BR-11.2, BR-11.6). |
| `payment` | `status` | `DEFAULT 'в_обработке'` | Начальный статус попытки оплаты — наше решение (BR-8.2, BR-8.7, BR-11.6). |
| `"order"` | `commission`, `total_amount` | Обычные столбцы `NUMERIC(10,2) NOT NULL` с `CHECK` (`chk_order_commission`, `chk_order_total_amount_sum`), **не** `GENERATED ALWAYS AS` | Обычные столбцы с ограничениями `chk_order_commission` и `chk_order_total_amount_sum`: бэкенд и генератор передают вычисленные суммы при `INSERT` напрямую по контракту ERD (столбцы `GENERATED ALWAYS` запретили бы прямую передачу значений), а `CHECK` проверяет корректность формул (BR-1.4, BR-1.5, BR-7.10). |

---

## Нормализация (3НФ)

Короткое обоснование, что таблицы приведены к 3НФ, кроме пяти осознанных отступлений, перечисленных в п. 2:

1. **Соответствие 1НФ, 2НФ и 3НФ:**
   - **1НФ:** во всех 12 таблицах схемы `trondin_food` атрибуты атомарны. Связи «многие-ко-многим» вынесены в отдельные таблицы `client_address` (клиенты — адреса, BR-2.4) и `order_structure` (заказы — блюда, BR-7.14).
   - **2НФ:** в 9 таблицах с простым PK частичная зависимость невозможна по определению. В таблицах с составным PK неключевые атрибуты зависят от полного ключа (`courier_pay (year, month, courier_id)`, `client_address` без неключевых полей, `order_structure (order_id, product_id)` с отступлением по `restaurant_id`, см. п. 2).
   - **3НФ:** неключевые атрибуты зависят напрямую от первичного ключа и не зависят от других неключевых полей (справочники вынесены в `product_category`, адреса — в `address`), кроме пяти осознанных отступлений и денормализаций (производные суммы заказа, хранимые рейтинги, статус оплаты, избыточный `client_id` в отзывах, а также отступление от 2НФ в `order_structure.restaurant_id` — см. п. 2).

2. **Особые случаи, отступления от нормальных форм и контролируемая денормализация:**
   - **`"order".order_amount`, `"order".commission` (`10%` от `order_amount`) и `"order".total_amount` (`order_amount + commission`) (BR-1.4, BR-1.5, BR-7.10):** транзитивная зависимость между неключевыми атрибутами (`order_id → order_amount → commission → total_amount`) — отступление от 3НФ. Поле `order_amount` фиксирует исторический снимок стоимости блюд на момент заказа. Поля `commission` и `total_amount` заданы ERD, используются в отчетах и составном FK `fk_payment_order_amount` (BR-8.4). Согласованность формул обеспечивают ограничения `chk_order_commission` и `chk_order_total_amount_sum` (выбор CHECK вместо GENERATED обоснован в разделе «DEFAULT и GENERATED»).
   - **`product.rating` и `restaurant.rating` (BR-4.2, BR-5.4, BR-9.6, BR-9.7):** хранимые агрегаты (`ROUND(AVG(review.rating), 2)`) по контракту ERD. Денормализация для быстрого чтения каталога без постоянного пересчета `AVG`. Согласованность с отзывами поддерживает триггер `rating_change` (FOOD-105).
   - **`"order".pay_status` (BR-7.8, BR-7.9, BR-8.7):** статус оплаты заказа из ERD, синхронизируется триггером `payment_pay_status_change()` по событиям в `payment`.
   - **`order_structure.restaurant_id` (BR-7.3):** частичная зависимость от `order_id` (отступление от 2НФ ради Ловушки 3). Оставлен ради двух составных внешних ключей, исключающих блюда из чужого ресторана.
   - **`review.client_id` (BR-9.2):** транзитивная зависимость (`review_id → order_id → client_id`) по контракту ERD; используется в составном FK `fk_review_order_client` (Ловушка 4).
   - **`review.entity_type` и `review.entity_id` (BR-9.1, BR-9.2):** полиморфная ссылка на объект отзыва. Зависят только от PK `review_id` (3НФ не нарушена), а ссылочная целостность контролируется триггерами (Ловушка 4).

3. **Технические решения по именованию и типам данных (BR-11.6, BR-13.1, BR-13.3):**
   - **Таблица `"order"` (BR-13.1):** имя сохранено по ERD с экранированием (`trondin_food."order"`), чтобы проверочные запросы из тестов выполнялись без изменения имен таблиц.
   - **Схема `exts` (BR-13.3):** не пересоздается в `00_init.sql`, а используется для вызовов `exts.uuid_generate_v4()`.
   - **Типы и размерности столбцов (BR-11.6):** `CHAR(32)` для MD5-пароля (BR-2.3); `CHAR(11)` для номеров телефонов `7XXXXXXXXXX`; `NUMERIC(10,2)` для денежных сумм; `NUMERIC(8,3)` для количества `order_structure.quantity` (BR-7.15); `NUMERIC(2,1)` для коэффициентов курьеров `0.1`–`0.5` (BR-6.4); `NUMERIC(3,2)` для рейтингов `0.00`–`5.00` и `SMALLINT` для оценки в отзыве `1`–`5` (BR-9.4).

---

## Решения по функциям и отчетам

### `insert_test_data()` и `erase_test_data()` (FOOD-102, 103)

- **Повторный вызов дополняет данные (C.9):** `insert_test_data(value)` не очищает таблицы, а дописывает строки. Конфликты `UNIQUE` исключены: телефоны нумеруются от `MAX`, логины, улицы и транзакции содержат UUID, а выплаты генерируются только для новых курьеров текущего вызова.
- **Оплаты (BR-8.1, BR-11.7):** генератор создаёт ровно одну успешную оплату на заказ (`status = 'успех'`) для объёма `5 × value` строк.
- **`erase_test_data()`:** выполняет `TRUNCATE TABLE` всех 12 таблиц без `RESTART IDENTITY`, так как все PK имеют тип `UUID` (BR-11.1).

### `add_product()` (FOOD-104)

- **Параметры и валидация:** процедура принимает все атрибуты кроме `product_id` (генерируется по умолчанию). До `INSERT` проверяются `NOT NULL` обязательных параметров, существование ресторана и категории, цена `>= 0` и рейтинг `0..5` (AC FOOD-104).
- **Параметр `p_rating`:** по умолчанию `NULL` (по BR-9.7 без отзывов рейтинг отсутствует), но может быть явно передан при добавлении блюда (по уточнению преподавателя: ресторан оплачивает начальный рейтинг нового блюда).

### `rating_change` (FOOD-105, BR-9.6, BR-9.7)

- **Единая триггерная функция:** обрабатывает `INSERT`, `UPDATE` и `DELETE` на таблице `review` через `TG_OP`, пересчитывая `ROUND(AVG(rating), 2)` для блюда и ресторана (для заказов рейтинг не хранится по BR-9.6). При переносе отзыва пересчитываются старая (`OLD`) и новая (`NEW`) сущности.
- **Возврат к `NULL` (BR-9.7):** при удалении всех отзывов рейтинг сбрасывается в `NULL`.

### `get_statistic()` (FOOD-106, BR-2.6, BR-11.8, BR-13.2)

- **Рестораны без доставок и состав заказа:** рестораны без доставок возвращают `0` в суммах и `NULL` в названии блюда и логине клиента. При наличии доставок `best_product_name` не `NULL` благодаря контролю непустого состава заказа (см. Ловушку 3).
- **Оптимизация (BR-11.8):** доставленные заказы отбираются один раз в `CTE MATERIALIZED`, выбор лучшего блюда и клиента идёт через `GROUP BY` + `DISTINCT ON (restaurant_id)` без оконных функций, лучший клиент возвращается логином (BR-2.6).

### `courier_salary()` (FOOD-107, BR-10.1–BR-10.7)

- **Расчетный месяц по `order_timestamp`:** наше решение — привязывать заказ к месяцу создания `order_timestamp` (согласовано с проверочным запросом C.8).
- **Уволенные курьеры и повторный вызов (BR-10.2, BR-10.6):** уволенный курьер получает строку в `courier_pay` (при отсутствии доставок — 0.00), но коэффициент на следующий месяц ему не обновляется. Повторный вызов в том же месяце берёт уже сохранённый `coefficient_used` из `courier_pay` (`ON CONFLICT DO UPDATE`).

### `how_much_money` (FOOD-108, BR-11.9)

- **Сетка месяцев и пропуски (BR-11.9):** непрерывная сетка строится через `WITH RECURSIVE` от первого до последнего месяца с доставками. Для пустых месяцев суммы приводятся к `0` через `COALESCE`.
- **Оконная функция LAG (BR-11.9):** `prev_commission` вычисляется через `LAG`, у первого месяца равен `NULL` (BR-11.9 допускает LAG или рекурсию, выбран LAG).

### Права `inspector` (`db/schema/grants.sql`, FOOD-109)

- **Объём прав:** выданы `ALL PRIVILEGES ON ALL TABLES, SEQUENCES, ROUTINES IN SCHEMA trondin_food`, так как одних прав на схему недостаточно для выполнения процедур и тестов.
- **Порядок запуска:** `grants.sql` выполняется последним — после создания всех объектов схемы или после восстановления `.backup`.

### Бэкап (`db/foodexpress_trondin.backup`, FOOD-110, BR-13.3)

- **Формат и состав (BR-13.3):** архив создан в формате `pg_dump -Fc -n trondin_food -s --no-privileges`, содержит только схему `trondin_food` без расширения `uuid-ossp` и без данных.

### Осознанные риски

- **Прямой `UPDATE pay_status`:** триггер пересчитывает статус при изменениях в `payment`, а прямая запись остается возможной.
- **Вырожденные данные генератора:** генератор создаёт один доставленный заказ на ресторан, поэтому `total_amount = avg_amount`, а в `best_product_name` и `best_user` попадает единственный заказ этого ресторана.
- **Оплата у отмененного заказа:** упрощение генератора (каждому заказу создается ровно одна успешная оплата, включая отмененные заказы).
- **Явные `UPDATE` в генераторе:** в генераторе оставлены прямые обновления рейтингов и статусов: по разделу 10 samples/all_examples.sql рейтинги в генераторе выставляются сразу, не через rating_change.
