-- =====================================================================
-- 03_load.sql — загрузка Raw Vault из stage.
-- Скрипт идемпотентен: повторный запуск не создаёт дубликатов
-- (вставляются только hash key, которых ещё нет в целевой таблице).
-- Порядок: хабы -> линк -> спутники.
-- =====================================================================

INSERT INTO dv.hub_ship_mode
SELECT DISTINCT hk_ship_mode, ship_mode, now(), record_source
FROM dv.v_stg_hashed
WHERE hk_ship_mode NOT IN (SELECT hk_ship_mode FROM dv.hub_ship_mode);

INSERT INTO dv.hub_segment
SELECT DISTINCT hk_segment, segment, now(), record_source
FROM dv.v_stg_hashed
WHERE hk_segment NOT IN (SELECT hk_segment FROM dv.hub_segment);

INSERT INTO dv.hub_location
SELECT hk_location, any(country), any(state), any(city), any(postal_code), now(), any(record_source)
FROM dv.v_stg_hashed
WHERE hk_location NOT IN (SELECT hk_location FROM dv.hub_location)
GROUP BY hk_location;

INSERT INTO dv.hub_product_group
SELECT hk_product_group, any(category), any(sub_category), now(), any(record_source)
FROM dv.v_stg_hashed
WHERE hk_product_group NOT IN (SELECT hk_product_group FROM dv.hub_product_group)
GROUP BY hk_product_group;

INSERT INTO dv.hub_sale_line
SELECT hk_sale_line, source_row_id, now(), record_source
FROM dv.v_stg_hashed
WHERE hk_sale_line NOT IN (SELECT hk_sale_line FROM dv.hub_sale_line);

-- Link
INSERT INTO dv.lnk_sale_line
SELECT
    lower(hex(MD5(concat(hk_sale_line, hk_ship_mode, hk_segment, hk_location, hk_product_group)))),
    hk_sale_line, hk_ship_mode, hk_segment, hk_location, hk_product_group,
    now(), record_source
FROM dv.v_stg_hashed
WHERE lower(hex(MD5(concat(hk_sale_line, hk_ship_mode, hk_segment, hk_location, hk_product_group))))
      NOT IN (SELECT hk_lnk_sale_line FROM dv.lnk_sale_line);

-- Satellites: добавляем новую версию, только если hashdiff изменился
INSERT INTO dv.sat_location_region
SELECT hk_location, now(), any(hashdiff_location), any(region), any(record_source)
FROM dv.v_stg_hashed
WHERE (hk_location, hashdiff_location) NOT IN (SELECT hk_location, hashdiff FROM dv.sat_location_region)
GROUP BY hk_location;

INSERT INTO dv.sat_sale_line_measures
SELECT hk_sale_line, now(), hashdiff_measures, sales, quantity, discount, profit, record_source
FROM dv.v_stg_hashed
WHERE (hk_sale_line, hashdiff_measures) NOT IN (SELECT hk_sale_line, hashdiff FROM dv.sat_sale_line_measures);
