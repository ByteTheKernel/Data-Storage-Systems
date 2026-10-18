-- =====================================================================
-- 06_queries.sql — примеры аналитических запросов к витринам
-- =====================================================================

-- 1. Выручка и прибыль по регионам
SELECT l.region, round(sum(f.sales), 2) AS sales, round(sum(f.profit), 2) AS profit
FROM dv.fact_sales f JOIN dv.dim_location l USING (hk_location)
GROUP BY l.region ORDER BY sales DESC;

-- 2. Категории и подкатегории: маржинальность
SELECT p.category, p.sub_category,
       round(sum(f.sales), 2) AS sales, round(sum(f.profit), 2) AS profit,
       round(sum(f.profit) / sum(f.sales) * 100, 1) AS margin_pct
FROM dv.fact_sales f JOIN dv.dim_product_group p USING (hk_product_group)
GROUP BY p.category, p.sub_category ORDER BY margin_pct;

-- 3. Топ-10 штатов по прибыли
SELECT l.state, round(sum(f.profit), 2) AS profit
FROM dv.fact_sales f JOIN dv.dim_location l USING (hk_location)
GROUP BY l.state ORDER BY profit DESC LIMIT 10;

-- 4. Влияние скидки на прибыль
SELECT f.discount, count() AS lines, round(avg(f.profit), 2) AS avg_profit
FROM dv.fact_sales f GROUP BY f.discount ORDER BY f.discount;

-- 5. Способ доставки x сегмент
SELECT s.ship_mode, g.segment, round(sum(f.sales), 2) AS sales
FROM dv.fact_sales f
JOIN dv.dim_ship_mode s USING (hk_ship_mode)
JOIN dv.dim_segment g USING (hk_segment)
GROUP BY s.ship_mode, g.segment ORDER BY s.ship_mode, g.segment;
