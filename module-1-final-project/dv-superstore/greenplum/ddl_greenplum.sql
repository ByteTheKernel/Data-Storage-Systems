-- =====================================================================
-- ddl_greenplum.sql — та же модель Data Vault для Greenplum (PostgreSQL-совместимый DDL).
-- Исходное задание предполагало Greenplum; здесь настоящие PRIMARY KEY / FOREIGN KEY.
-- ОГРАНИЧЕНИЕ: этот файл не запускался на реальном Greenplum — проверялась только
-- логика модели на ClickHouse. Особенности Greenplum:
--   * PRIMARY KEY/UNIQUE должны включать ключ распределения (DISTRIBUTED BY);
--   * FOREIGN KEY в Greenplum принимаются синтаксисом, но, по документации,
--     не проверяются на уровне СУБД — поэтому оставлены как документация модели.
--   * Хабы и линк распределены по hash key — одинаковые ключи лежат на одном сегменте.
-- =====================================================================
CREATE SCHEMA IF NOT EXISTS dv;

CREATE TABLE dv.hub_ship_mode (
    hk_ship_mode  CHAR(32)     NOT NULL,
    ship_mode     VARCHAR(30)  NOT NULL,
    load_dts      TIMESTAMP    NOT NULL DEFAULT now(),
    record_source VARCHAR(50)  NOT NULL,
    PRIMARY KEY (hk_ship_mode)
) DISTRIBUTED BY (hk_ship_mode);

CREATE TABLE dv.hub_segment (
    hk_segment    CHAR(32)     NOT NULL,
    segment       VARCHAR(30)  NOT NULL,
    load_dts      TIMESTAMP    NOT NULL DEFAULT now(),
    record_source VARCHAR(50)  NOT NULL,
    PRIMARY KEY (hk_segment)
) DISTRIBUTED BY (hk_segment);

CREATE TABLE dv.hub_location (
    hk_location   CHAR(32)     NOT NULL,
    country       VARCHAR(50)  NOT NULL,
    state         VARCHAR(50)  NOT NULL,
    city          VARCHAR(100) NOT NULL,
    postal_code   CHAR(5)      NOT NULL,
    load_dts      TIMESTAMP    NOT NULL DEFAULT now(),
    record_source VARCHAR(50)  NOT NULL,
    PRIMARY KEY (hk_location)
) DISTRIBUTED BY (hk_location);

CREATE TABLE dv.hub_product_group (
    hk_product_group CHAR(32)     NOT NULL,
    category         VARCHAR(50)  NOT NULL,
    sub_category     VARCHAR(50)  NOT NULL,
    load_dts         TIMESTAMP    NOT NULL DEFAULT now(),
    record_source    VARCHAR(50)  NOT NULL,
    PRIMARY KEY (hk_product_group)
) DISTRIBUTED BY (hk_product_group);

CREATE TABLE dv.hub_sale_line (
    hk_sale_line  CHAR(32)     NOT NULL,
    source_row_id INTEGER      NOT NULL,       -- в датасете нет Order ID
    load_dts      TIMESTAMP    NOT NULL DEFAULT now(),
    record_source VARCHAR(50)  NOT NULL,
    PRIMARY KEY (hk_sale_line)
) DISTRIBUTED BY (hk_sale_line);

CREATE TABLE dv.lnk_sale_line (
    hk_lnk_sale_line CHAR(32)  NOT NULL,
    hk_sale_line     CHAR(32)  NOT NULL REFERENCES dv.hub_sale_line (hk_sale_line),
    hk_ship_mode     CHAR(32)  NOT NULL REFERENCES dv.hub_ship_mode (hk_ship_mode),
    hk_segment       CHAR(32)  NOT NULL REFERENCES dv.hub_segment (hk_segment),
    hk_location      CHAR(32)  NOT NULL REFERENCES dv.hub_location (hk_location),
    hk_product_group CHAR(32)  NOT NULL REFERENCES dv.hub_product_group (hk_product_group),
    load_dts         TIMESTAMP NOT NULL DEFAULT now(),
    record_source    VARCHAR(50) NOT NULL,
    PRIMARY KEY (hk_lnk_sale_line)
) DISTRIBUTED BY (hk_lnk_sale_line);

CREATE TABLE dv.sat_location_region (
    hk_location   CHAR(32)    NOT NULL REFERENCES dv.hub_location (hk_location),
    load_dts      TIMESTAMP   NOT NULL,
    hashdiff      CHAR(32)    NOT NULL,
    region        VARCHAR(20) NOT NULL,
    record_source VARCHAR(50) NOT NULL,
    PRIMARY KEY (hk_location, load_dts)
) DISTRIBUTED BY (hk_location);

CREATE TABLE dv.sat_sale_line_measures (
    hk_sale_line  CHAR(32)       NOT NULL REFERENCES dv.hub_sale_line (hk_sale_line),
    load_dts      TIMESTAMP      NOT NULL,
    hashdiff      CHAR(32)       NOT NULL,
    sales         NUMERIC(12, 4) NOT NULL,
    quantity      SMALLINT       NOT NULL CHECK (quantity > 0),
    discount      NUMERIC(4, 2)  NOT NULL CHECK (discount BETWEEN 0 AND 1),
    profit        NUMERIC(12, 4) NOT NULL,
    record_source VARCHAR(50)    NOT NULL,
    PRIMARY KEY (hk_sale_line, load_dts)
) DISTRIBUTED BY (hk_sale_line);
