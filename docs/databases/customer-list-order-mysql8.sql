CREATE INDEX idx_customer_list_order
  ON customer (deleted_at, created_at DESC, customer_name ASC);
ANALYZE TABLE customer;
