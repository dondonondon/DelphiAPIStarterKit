-- Clone-only delta for the declared numeric auth-v2 schema from WAVE-01.
-- Preflight existing negative price/stock and constraint inventory before execution.
-- Fresh baseline/sample remain alternative empty imports, never upgrade scripts.
ALTER TABLE product
  ADD CONSTRAINT ck_product_price_nonnegative CHECK (price >= 0),
  ADD CONSTRAINT ck_product_stock_nonnegative CHECK (stock >= 0);
