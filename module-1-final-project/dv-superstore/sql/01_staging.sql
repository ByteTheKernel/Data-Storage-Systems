-- =====================================================================
-- 01_staging.sql — STAGE-слой (Data Vault: staging area)
-- Источник: Kaggle "Sample Superstore" (SampleSuperstore.csv, 13 колонок).
-- ВАЖНО: в этом наборе НЕТ Order ID / Customer ID / Product ID / дат.
-- Одна строка = одна позиция продажи. Естественного ключа у строки нет,
-- поэтому бизнес-ключом транзакции служит номер строки файла (source_row_id).
-- =====================================================================
CREATE DATABASE IF NOT EXISTS dv;

DROP TABLE IF EXISTS dv.stg_superstore;
CREATE TABLE dv.stg_superstore
(
    source_row_id UInt32,                          -- порядковый номер строки в CSV (бизнес-ключ транзакции)
    ship_mode     LowCardinality(String),          -- 4 значения -> LowCardinality экономит место
    segment       LowCardinality(String),          -- 3 значения
    country       LowCardinality(String),          -- 1 значение (United States)
    state         LowCardinality(String),
    city          String,
    postal_code   FixedString(5),                  -- US ZIP, нужны ведущие нули -> строка, не число
    region        LowCardinality(String),          -- 4 значения
    category      LowCardinality(String),          -- 3 значения
    sub_category  LowCardinality(String),          -- 17 значений
    sales         Decimal(12, 4),                  -- деньги -> Decimal, не Float (без ошибок округления)
    quantity      UInt16,
    discount      Decimal(4, 2),                   -- 0.00 .. 1.00
    profit        Decimal(12, 4),                  -- может быть отрицательной
    load_dts      DateTime DEFAULT now(),          -- метка загрузки
    record_source LowCardinality(String) DEFAULT 'kaggle.superstore'
)
ENGINE = MergeTree
ORDER BY source_row_id;

-- Загрузка из CSV (файл лежит в ./data/SampleSuperstore.csv и виден контейнеру через file()).
-- max_threads = 1 нужен, чтобы rowNumberInAllBlocks() давал номера в порядке файла.
INSERT INTO dv.stg_superstore
    (source_row_id, ship_mode, segment, country, state, city, postal_code,
     region, category, sub_category, sales, quantity, discount, profit)
SELECT
    toUInt32(rowNumberInAllBlocks() + 1),
    `Ship Mode`, Segment, Country, State, City,
    leftPad(`Postal Code`, 5, '0'),                -- в CSV индексы Новой Англии потеряли ведущий 0
    Region, Category, `Sub-Category`,
    Sales, Quantity, Discount, Profit
FROM file(
    'SampleSuperstore.csv', 'CSVWithNames',
    '`Ship Mode` String, Segment String, Country String, City String, State String,
     `Postal Code` String, Region String, Category String, `Sub-Category` String,
     Sales Decimal(12,4), Quantity UInt16, Discount Decimal(4,2), Profit Decimal(12,4)'
)
SETTINGS max_threads = 1;

-- Представление с хеш-ключами: единое место, где определяется нормализация
-- бизнес-ключей (trim + upper) и вычисление MD5 hash key / hashdiff.
CREATE OR REPLACE VIEW dv.v_stg_hashed AS
SELECT
    source_row_id, ship_mode, segment, country, state, city, postal_code,
    region, category, sub_category, sales, quantity, discount, profit,
    load_dts, record_source,
    lower(hex(MD5(toString(source_row_id))))                                              AS hk_sale_line,
    lower(hex(MD5(upper(trim(ship_mode)))))                                               AS hk_ship_mode,
    lower(hex(MD5(upper(trim(segment)))))                                                 AS hk_segment,
    lower(hex(MD5(concat(upper(trim(country)),'||',upper(trim(state)),'||',
                         upper(trim(city)),'||',postal_code))))                           AS hk_location,
    lower(hex(MD5(concat(upper(trim(category)),'||',upper(trim(sub_category))))))         AS hk_product_group,
    lower(hex(MD5(upper(trim(region)))))                                                  AS hashdiff_location,
    lower(hex(MD5(concat(toString(sales),'||',toString(quantity),'||',
                         toString(discount),'||',toString(profit)))))                     AS hashdiff_measures
FROM dv.stg_superstore;
