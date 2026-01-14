insert into businesses (id, name) values
  ('7d8f8c6b-5d2f-4e0a-9c1a-1d4f2c7a3b11', 'Acme Supply Co'),
  ('2a5c7d1e-8f4b-4a2c-9b3d-7e1f2a3b4c5d', 'Globex Traders');

-- Placeholder user IDs (replace with real auth user IDs if needed)
insert into business_members (business_id, user_id, role) values
  ('7d8f8c6b-5d2f-4e0a-9c1a-1d4f2c7a3b11', 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 'owner'),
  ('2a5c7d1e-8f4b-4a2c-9b3d-7e1f2a3b4c5d', 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e', 'owner');

insert into products (id, business_id, sku, name, stock, price_cents) values
  ('3e5a9b2c-1d4f-4b7a-8c9d-1e2f3a4b5c6d', '7d8f8c6b-5d2f-4e0a-9c1a-1d4f2c7a3b11', 'SKU-RED-01', 'Red Widget', 100, 1500),
  ('6f7a8b9c-0d1e-4f2a-8b3c-4d5e6f7a8b9c', '7d8f8c6b-5d2f-4e0a-9c1a-1d4f2c7a3b11', 'SKU-BLU-02', 'Blue Widget', 50, 2500),
  ('7a8b9c0d-1e2f-4a3b-8c4d-5e6f7a8b9c0d', '2a5c7d1e-8f4b-4a2c-9b3d-7e1f2a3b4c5d', 'SKU-GRN-01', 'Green Widget', 80, 1800);

insert into business_credit_accounts (business_id, credit_limit_cents, balance_cents) values
  ('7d8f8c6b-5d2f-4e0a-9c1a-1d4f2c7a3b11', 500000, 0),
  ('2a5c7d1e-8f4b-4a2c-9b3d-7e1f2a3b4c5d', 300000, 0);