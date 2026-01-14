import { NextResponse } from "next/server";

import { supabaseAdmin } from "@/lib/supabaseAdmin";

const uuidRegex =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function isUuid(value: unknown): value is string {
  return typeof value === "string" && uuidRegex.test(value);
}

export async function POST(request: Request) {
  let body: unknown;

  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  if (!body || typeof body !== "object") {
    return NextResponse.json({ error: "Invalid request body" }, { status: 400 });
  }

  const { businessId, idempotencyKey, items } = body as {
    businessId?: unknown;
    idempotencyKey?: unknown;
    items?: unknown;
  };

  if (!isUuid(businessId)) {
    return NextResponse.json({ error: "businessId must be a UUID" }, { status: 400 });
  }

  if (!isUuid(idempotencyKey)) {
    return NextResponse.json(
      { error: "idempotencyKey must be a UUID" },
      { status: 400 }
    );
  }

  if (!Array.isArray(items) || items.length === 0) {
    return NextResponse.json({ error: "items must be a non-empty array" }, { status: 400 });
  }

  const normalizedItems = items.map((item) => {
    const productId = (item as { product_id?: unknown }).product_id;
    const qty = (item as { qty?: unknown }).qty;

    if (!isUuid(productId)) {
      throw new Error("Each item.product_id must be a UUID");
    }

    if (typeof qty !== "number" || !Number.isInteger(qty) || qty <= 0) {
      throw new Error("Each item.qty must be a positive integer");
    }

    return { product_id: productId, qty };
  });

  try {
    const { data, error } = await supabaseAdmin.rpc("process_purchase", {
      p_business_id: businessId,
      p_idempotency_key: idempotencyKey,
      p_items: normalizedItems
    });

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 400 });
    }

    return NextResponse.json({ orderId: data }, { status: 200 });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unexpected error";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
