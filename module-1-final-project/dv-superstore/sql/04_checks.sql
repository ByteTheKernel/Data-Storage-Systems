-- =====================================================================
-- 04_checks.sql — проверки качества загрузки (все строки должны быть check_ok = 1)
-- Заменяют отсутствующие в ClickHouse FOREIGN KEY / UNIQUE.
-- =====================================================================

-- 1. Количество строк по слоям
SELECT 'stg_superstore' AS tbl, count() AS cnt FROM dv.stg_superstore
UNION ALL SELECT 'hub_ship_mode',        count() FROM dv.hub_ship_mode FINAL
UNION ALL SELECT 'hub_segment',          count() FROM dv.hub_segment FINAL
UNION ALL SELECT 'hub_location',         count() FROM dv.hub_location FINAL
UNION ALL SELECT 'hub_product_group',    count() FROM dv.hub_product_group FINAL
UNION ALL SELECT 'hub_sale_line',        count() FROM dv.hub_sale_line FINAL
UNION ALL SELECT 'lnk_sale_line',        count() FROM dv.lnk_sale_line FINAL
UNION ALL SELECT 'sat_location_region',  count() FROM dv.sat_location_region FINAL
UNION ALL SELECT 'sat_sale_line_measures', count() FROM dv.sat_sale_line_measures FINAL;

-- 2. Контрольные проверки
SELECT 'link rows = stage rows' AS check_name,
       (SELECT count() FROM dv.lnk_sale_line FINAL) = (SELECT count() FROM dv.stg_superstore) AS check_ok
UNION ALL
SELECT 'hub_sale_line rows = stage rows',
       (SELECT count() FROM dv.hub_sale_line FINAL) = (SELECT count() FROM dv.stg_superstore)
UNION ALL
SELECT 'sum(sales) stage = vault',
       (SELECT sum(sales) FROM dv.stg_superstore) = (SELECT sum(sales) FROM dv.sat_sale_line_measures FINAL)
UNION ALL
SELECT 'sum(profit) stage = vault',
       (SELECT sum(profit) FROM dv.stg_superstore) = (SELECT sum(profit) FROM dv.sat_sale_line_measures FINAL)
UNION ALL
-- «Мягкие» FK: в линке не должно быть ключей, которых нет в хабах
SELECT 'no orphan hk_ship_mode in link',
       (SELECT count() FROM dv.lnk_sale_line FINAL WHERE hk_ship_mode NOT IN (SELECT hk_ship_mode FROM dv.hub_ship_mode)) = 0
UNION ALL
SELECT 'no orphan hk_segment in link',
       (SELECT count() FROM dv.lnk_sale_line FINAL WHERE hk_segment NOT IN (SELECT hk_segment FROM dv.hub_segment)) = 0
UNION ALL
SELECT 'no orphan hk_location in link',
       (SELECT count() FROM dv.lnk_sale_line FINAL WHERE hk_location NOT IN (SELECT hk_location FROM dv.hub_location)) = 0
UNION ALL
SELECT 'no orphan hk_product_group in link',
       (SELECT count() FROM dv.lnk_sale_line FINAL WHERE hk_product_group NOT IN (SELECT hk_product_group FROM dv.hub_product_group)) = 0
UNION ALL
SELECT 'no orphan hk_sale_line in link',
       (SELECT count() FROM dv.lnk_sale_line FINAL WHERE hk_sale_line NOT IN (SELECT hk_sale_line FROM dv.hub_sale_line)) = 0
UNION ALL
-- Уникальность hash key в хабах
SELECT 'hub_location hk unique',
       (SELECT count() FROM dv.hub_location FINAL) = (SELECT uniqExact(hk_location) FROM dv.hub_location FINAL)
UNION ALL
SELECT 'hub_sale_line hk unique',
       (SELECT count() FROM dv.hub_sale_line FINAL) = (SELECT uniqExact(hk_sale_line) FROM dv.hub_sale_line FINAL);
