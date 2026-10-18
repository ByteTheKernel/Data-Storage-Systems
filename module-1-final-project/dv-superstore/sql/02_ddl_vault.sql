-- =====================================================================
-- 02_ddl_vault.sql — DDL Raw Data Vault для ClickHouse
--
-- ПРИНЦИПЫ ПРОЕКТИРОВАНИЯ
-- * Hub  — только бизнес-ключ + hash key + load_dts + record_source.
-- * Link — связь хабов (hash key каждого хаба) + служебные поля.
-- * Sat  — описательные атрибуты и меры с историей (load_dts) и hashdiff.
-- * Hash key = lower(hex(MD5(нормализованный бизнес-ключ))) -> FixedString(32).
--   (FixedString(16) с сырым MD5 был бы компактнее, но нечитаем в скриншотах.)
--
-- ОГРАНИЧЕНИЯ ЦЕЛОСТНОСТИ В CLICKHOUSE
-- ClickHouse НЕ поддерживает FOREIGN KEY и UNIQUE. PRIMARY KEY здесь —
-- это разреженный индекс сортировки, он НЕ гарантирует уникальность.
-- Поэтому:
--   * уникальность hash key обеспечивается ReplacingMergeTree (+ идемпотентная
--     загрузка NOT IN в 03_load.sql);
--   * FK зафиксированы в COMMENT и проверяются запросами из 04_checks.sql;
--   * вариант с настоящими PRIMARY/FOREIGN KEY — greenplum/ddl_greenplum.sql.
-- =====================================================================
CREATE DATABASE IF NOT EXISTS dv;

-- ---------------------------- HUBS -----------------------------------

DROP TABLE IF EXISTS dv.hub_ship_mode;
CREATE TABLE dv.hub_ship_mode
(
    hk_ship_mode  FixedString(32)           COMMENT 'PK: MD5 бизнес-ключа',
    ship_mode     LowCardinality(String)    COMMENT 'Бизнес-ключ: способ доставки',
    load_dts      DateTime                  COMMENT 'Время загрузки',
    record_source LowCardinality(String)    COMMENT 'Источник'
)
ENGINE = ReplacingMergeTree
PRIMARY KEY hk_ship_mode ORDER BY hk_ship_mode
COMMENT 'Hub: способ доставки';

DROP TABLE IF EXISTS dv.hub_segment;
CREATE TABLE dv.hub_segment
(
    hk_segment    FixedString(32)           COMMENT 'PK: MD5 бизнес-ключа',
    segment       LowCardinality(String)    COMMENT 'Бизнес-ключ: сегмент клиентов',
    load_dts      DateTime,
    record_source LowCardinality(String)
)
ENGINE = ReplacingMergeTree
PRIMARY KEY hk_segment ORDER BY hk_segment
COMMENT 'Hub: сегмент клиентов';

-- Составной бизнес-ключ: у почтового индекса в датасете нет собственного
-- идентификатора, а город/штат не уникальны сами по себе.
DROP TABLE IF EXISTS dv.hub_location;
CREATE TABLE dv.hub_location
(
    hk_location   FixedString(32)           COMMENT 'PK: MD5(country||state||city||postal_code)',
    country       LowCardinality(String)    COMMENT 'BK часть 1',
    state         LowCardinality(String)    COMMENT 'BK часть 2',
    city          String                    COMMENT 'BK часть 3',
    postal_code   FixedString(5)            COMMENT 'BK часть 4 (ZIP, 5 символов)',
    load_dts      DateTime,
    record_source LowCardinality(String)
)
ENGINE = ReplacingMergeTree
PRIMARY KEY hk_location ORDER BY hk_location
COMMENT 'Hub: географическая точка доставки';

-- Подкатегория не уникальна без категории -> составной ключ.
DROP TABLE IF EXISTS dv.hub_product_group;
CREATE TABLE dv.hub_product_group
(
    hk_product_group FixedString(32)        COMMENT 'PK: MD5(category||sub_category)',
    category         LowCardinality(String) COMMENT 'BK часть 1',
    sub_category     LowCardinality(String) COMMENT 'BK часть 2',
    load_dts         DateTime,
    record_source    LowCardinality(String)
)
ENGINE = ReplacingMergeTree
PRIMARY KEY hk_product_group ORDER BY hk_product_group
COMMENT 'Hub: товарная группа (категория + подкатегория)';

-- В датасете нет Order ID: транзакция идентифицируется номером строки источника.
DROP TABLE IF EXISTS dv.hub_sale_line;
CREATE TABLE dv.hub_sale_line
(
    hk_sale_line  FixedString(32)           COMMENT 'PK: MD5(source_row_id)',
    source_row_id UInt32                    COMMENT 'Бизнес-ключ: номер строки источника',
    load_dts      DateTime,
    record_source LowCardinality(String)
)
ENGINE = ReplacingMergeTree
PRIMARY KEY hk_sale_line ORDER BY hk_sale_line
COMMENT 'Hub: позиция продажи';

-- ---------------------------- LINK -----------------------------------

DROP TABLE IF EXISTS dv.lnk_sale_line;
CREATE TABLE dv.lnk_sale_line
(
    hk_lnk_sale_line FixedString(32) COMMENT 'PK: MD5 конкатенации hash key хабов',
    hk_sale_line     FixedString(32) COMMENT 'FK -> hub_sale_line',
    hk_ship_mode     FixedString(32) COMMENT 'FK -> hub_ship_mode',
    hk_segment       FixedString(32) COMMENT 'FK -> hub_segment',
    hk_location      FixedString(32) COMMENT 'FK -> hub_location',
    hk_product_group FixedString(32) COMMENT 'FK -> hub_product_group',
    load_dts         DateTime,
    record_source    LowCardinality(String)
)
ENGINE = ReplacingMergeTree
PRIMARY KEY hk_lnk_sale_line ORDER BY hk_lnk_sale_line
COMMENT 'Link: позиция продажи связывает доставку, сегмент, место и товарную группу';

-- -------------------------- SATELLITES -------------------------------

-- Region — описательный атрибут штата/города, не часть ключа -> спутник хаба location.
DROP TABLE IF EXISTS dv.sat_location_region;
CREATE TABLE dv.sat_location_region
(
    hk_location   FixedString(32)        COMMENT 'FK -> hub_location',
    load_dts      DateTime               COMMENT 'Начало версии',
    hashdiff      FixedString(32)        COMMENT 'MD5 атрибутов: детектор изменений',
    region        LowCardinality(String) COMMENT 'Регион продаж',
    record_source LowCardinality(String)
)
ENGINE = ReplacingMergeTree
PRIMARY KEY (hk_location, load_dts) ORDER BY (hk_location, load_dts)
COMMENT 'Satellite: регион точки доставки';

-- Меры продажи — спутник хаба позиции продажи (Link остаётся «чистым»).
DROP TABLE IF EXISTS dv.sat_sale_line_measures;
CREATE TABLE dv.sat_sale_line_measures
(
    hk_sale_line  FixedString(32)  COMMENT 'FK -> hub_sale_line',
    load_dts      DateTime         COMMENT 'Начало версии',
    hashdiff      FixedString(32)  COMMENT 'MD5 мер: детектор изменений',
    sales         Decimal(12, 4)   COMMENT 'Выручка',
    quantity      UInt16           COMMENT 'Количество',
    discount      Decimal(4, 2)    COMMENT 'Скидка 0..1',
    profit        Decimal(12, 4)   COMMENT 'Прибыль (может быть < 0)',
    record_source LowCardinality(String)
)
ENGINE = ReplacingMergeTree
PRIMARY KEY (hk_sale_line, load_dts) ORDER BY (hk_sale_line, load_dts)
COMMENT 'Satellite: числовые меры позиции продажи';
