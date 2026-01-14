import { NextResponse } from "next/server";

import { supabaseAdmin } from "@/lib/supabaseAdmin";

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

  const { name, creditLimitCents } = body as {
    name?: unknown;
    creditLimitCents?: unknown;
  };

  if (typeof name !== "string" || name.trim().length === 0) {
    return NextResponse.json({ error: "name is required" }, { status: 400 });
  }

  if (
    typeof creditLimitCents !== "number" ||
    !Number.isInteger(creditLimitCents) ||
    creditLimitCents < 0
  ) {
    return NextResponse.json(
      { error: "creditLimitCents must be a non-negative integer" },
      { status: 400 }
    );
  }

  try {
    const { data: business, error: businessError } = await supabaseAdmin
      .from("businesses")
      .insert({ name: name.trim() })
      .select("id")
      .single();

    if (businessError || !business) {
      return NextResponse.json(
        { error: businessError?.message ?? "Failed to create business" },
        { status: 400 }
      );
    }

    const { error: creditError } = await supabaseAdmin
      .from("business_credit_accounts")
      .insert({
        business_id: business.id,
        credit_limit_cents: creditLimitCents,
        balance_cents: 0
      });

    if (creditError) {
      await supabaseAdmin.from("businesses").delete().eq("id", business.id);
      return NextResponse.json({ error: creditError.message }, { status: 400 });
    }

    return NextResponse.json({ businessId: business.id }, { status: 200 });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unexpected error";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}