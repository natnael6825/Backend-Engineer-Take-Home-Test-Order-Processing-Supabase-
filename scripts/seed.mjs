import "dotenv/config";
import { createClient } from "@supabase/supabase-js";

const supabaseUrl = process.env.SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !serviceRoleKey) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false }
});

const businesses = [
  { id: "7d8f8c6b-5d2f-4e0a-9c1a-1d4f2c7a3b11", name: "Acme Supply Co" },
  { id: "2a5c7d1e-8f4b-4a2c-9b3d-7e1f2a3b4c5d", name: "Globex Traders" }
];

const businessMembers = [
  {
    business_id: "7d8f8c6b-5d2f-4e0a-9c1a-1d4f2c7a3b11",
    user_id: "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d",
    role: "owner"
  },
  {
    business_id: "2a5c7d1e-8f4b-4a2c-9b3d-7e1f2a3b4c5d",
    user_id: "b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e",
    role: "owner"
  }
];

const products = [
  {
    id: "3e5a9b2c-1d4f-4b7a-8c9d-1e2f3a4b5c6d",
    business_id: "7d8f8c6b-5d2f-4e0a-9c1a-1d4f2c7a3b11",
    sku: "SKU-RED-01",
    name: "Red Widget",
    stock: 100,
    price_cents: 1500
  },
  {
    id: "6f7a8b9c-0d1e-4f2a-8b3c-4d5e6f7a8b9c",
    business_id: "7d8f8c6b-5d2f-4e0a-9c1a-1d4f2c7a3b11",
    sku: "SKU-BLU-02",
    name: "Blue Widget",
    stock: 50,
    price_cents: 2500
  },
  {
    id: "7a8b9c0d-1e2f-4a3b-8c4d-5e6f7a8b9c0d",
    business_id: "2a5c7d1e-8f4b-4a2c-9b3d-7e1f2a3b4c5d",
    sku: "SKU-GRN-01",
    name: "Green Widget",
    stock: 80,
    price_cents: 1800
  }
];

const creditAccounts = [
  {
    business_id: "7d8f8c6b-5d2f-4e0a-9c1a-1d4f2c7a3b11",
    credit_limit_cents: 500000,
    balance_cents: 0
  },
  {
    business_id: "2a5c7d1e-8f4b-4a2c-9b3d-7e1f2a3b4c5d",
    credit_limit_cents: 300000,
    balance_cents: 0
  }
];

async function run() {
  const steps = [
    supabase.from("businesses").upsert(businesses, { onConflict: "id" }),
    supabase
      .from("business_members")
      .upsert(businessMembers, { onConflict: "business_id,user_id" }),
    supabase.from("products").upsert(products, { onConflict: "id" }),
    supabase
      .from("business_credit_accounts")
      .upsert(creditAccounts, { onConflict: "business_id" })
  ];

  for (const step of steps) {
    const { error } = await step;
    if (error) {
      throw new Error(error.message);
    }
  }
}

run()
  .then(() => {
    console.log("Seed data applied.");
  })
  .catch((err) => {
    console.error("Seed failed:", err.message);
    process.exit(1);
  });