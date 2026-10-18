-- =====================================================================
-- 05_marts.sql — Information Mart поверх Raw Vault (звезда в виде VIEW).
-- Демонстрирует, что хранилище пригодно для аналитики.
-- Актуальная версия спутника берётся через argMax(…, load_dts).
-- =====================================================================

CREATE OR REPLACE VIEW dv.dim_location AS
SELECT h.hk_location, h.country, h.state, h.city, h.postal_code, s.region
FROM dv.hub_location AS h FINAL
LEFT JOIN
(
    SELECT hk_location, argMax(region, load_dts) AS region
    FROM dv.sat_location_region FINAL
    GROUP BY hk_location
) AS s USING (hk_location);

CREATE OR REPLACE VIEW dv.dim_ship_mode AS
SELECT hk_ship_mode, ship_mode FROM dv.hub_ship_mode FINAL;

CREATE OR REPLACE VIEW dv.dim_segment AS
SELECT hk_segment, segment FROM dv.hub_segment FINAL;

CREATE OR REPLACE VIEW dv.dim_product_group AS
SELECT hk_product_group, category, sub_category FROM dv.hub_product_group FINAL;

CREATE OR REPLACE VIEW dv.fact_sales AS
SELECT
    hs.source_row_id,
    l.hk_ship_mode, l.hk_segment, l.hk_location, l.hk_product_group,
    m.sales, m.quantity, m.discount, m.profit
FROM dv.lnk_sale_line AS l FINAL
INNER JOIN dv.hub_sale_line AS hs FINAL USING (hk_sale_line)
INNER JOIN
(
    SELECT hk_sale_line,
           argMax(sales, load_dts)    AS sales,
           argMax(quantity, load_dts) AS quantity,
           argMax(discount, load_dts) AS discount,
           argMax(profit, load_dts)   AS profit
    FROM dv.sat_sale_line_measures FINAL
    GROUP BY hk_sale_line
) AS m USING (hk_sale_line);
