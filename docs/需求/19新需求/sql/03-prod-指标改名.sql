

USE scm_source_prod;
CREATE TABLE sc_price_trend_bak_20260824 LIKE sc_price_trend;

INSERT INTO sc_price_trend_bak_20260824
SELECT * FROM sc_price_trend
WHERE indicator_name IN ('螺纹月成交价格', '中厚板月成交价格');

UPDATE sc_price_trend SET indicator_name = '螺纹唐山出厂价'
WHERE indicator_name = '螺纹月成交价格';

UPDATE sc_price_trend SET indicator_name = '中厚板唐山出厂价'
WHERE indicator_name = '中厚板月成交价格';
