import { NextResponse } from "next/server";

import { supabaseAdmin } from "@/lib/supabaseAdmin";

const uuidRegex =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function isUuid(value: unknown): value is string {
  return typeof value === "string" && uuidRegex.test(value);
}

export async function PATCH(request: Request, context: { params: { productId: string } }) {
  const { productId } = context.params;

  if (!isUuid(productId)) {
    return NextResponse.json({ error: "productId must be a UUID" }, { status: 400 });
  }

  let body: unknown;

  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  if (!body || typeof body !== "object") {
    return NextResponse.json({ error: "Invalid request body" }, { status: 400 });
  }

  const { businessId, sku, name, stock, priceCents } = body as {
    businessId?: unknown;
    sku?: unknown;
    name?: unknown;
    stock?: unknown;
    priceCents?: unknown;
  };

  if (!isUuid(businessId)) {
    return NextResponse.json({ error: "businessId must be a UUID" }, { status: 400 });
  }

  const updates: Record<string, unknown> = {};

  if (sku !== undefined) {
    if (typeof sku !== "string" || sku.trim().length === 0) {
      return NextResponse.json({ error: "sku must be a non-empty string" }, { status: 400 });
    }
    updates.sku = sku.trim();
  }

  if (name !== undefined) {
    if (typeof name !== "string" || name.trim().length === 0) {
      return NextResponse.json({ error: "name must be a non-empty string" }, { status: 400 });
    }
    updates.name = name.trim();
  }

  if (stock !== undefined) {
    if (typeof stock !== "number" || !Number.isInteger(stock) || stock < 0) {
      return NextResponse.json({ error: "stock must be a non-negative integer" }, { status: 400 });
    }
    updates.stock = stock;
  }

  if (priceCents !== undefined) {
    if (typeof priceCents !== "number" || !Number.isInteger(priceCents) || priceCents < 0) {
      return NextResponse.json(
        { error: "priceCents must be a non-negative integer" },
        { status: 400 }
      );
    }
    updates.price_cents = priceCents;
  }

  if (Object.keys(updates).length === 0) {
    return NextResponse.json({ error: "No fields to update" }, { status: 400 });
  }

  try {
    const { data, error } = await supabaseAdmin
      .from("products")
      .update(updates)
      .eq("id", productId)
      .eq("business_id", businessId)
      .select("id")
      .single();

    if (error || !data) {
      return NextResponse.json({ error: error?.message ?? "Failed to update product" }, { status: 400 });
    }

    return NextResponse.json({ productId: data.id }, { status: 200 });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unexpected error";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
