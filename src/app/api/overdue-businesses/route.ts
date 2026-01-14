import { NextResponse } from "next/server";

import { supabaseAdmin } from "@/lib/supabaseAdmin";

const isoDateRegex =
  /^\d{4}-\d{2}-\d{2}([tT ]\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})?)?$/;

function parseDate(value: string | null): string | null {
  if (!value) {
    return null;
  }
  if (!isoDateRegex.test(value)) {
    return null;
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }
  return parsed.toISOString();
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const dueBeforeRaw = searchParams.get("dueBefore");
  const dueAfterRaw = searchParams.get("dueAfter");
  const pageRaw = searchParams.get("page");
  const pageSizeRaw = searchParams.get("pageSize");

  const dueBefore = parseDate(dueBeforeRaw);
  const dueAfter = parseDate(dueAfterRaw);

  if ((dueBeforeRaw && !dueBefore) || (dueAfterRaw && !dueAfter)) {
    return NextResponse.json({ error: "Invalid date format" }, { status: 400 });
  }

  const page = pageRaw ? Number(pageRaw) : 1;
  const pageSize = pageSizeRaw ? Number(pageSizeRaw) : 20;

  if (!Number.isInteger(page) || page <= 0) {
    return NextResponse.json({ error: "page must be a positive integer" }, { status: 400 });
  }

  if (!Number.isInteger(pageSize) || pageSize <= 0 || pageSize > 100) {
    return NextResponse.json(
      { error: "pageSize must be a positive integer up to 100" },
      { status: 400 }
    );
  }

  const offset = (page - 1) * pageSize;

  try {
    const { data, error } = await supabaseAdmin.rpc("get_overdue_businesses", {
      p_due_before: dueBefore,
      p_due_after: dueAfter,
      p_limit: pageSize,
      p_offset: offset
    });

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 400 });
    }

    const rows = Array.isArray(data) ? data : [];
    const total = rows.length > 0 ? Number(rows[0].total_count) : 0;

    return NextResponse.json(
      {
        items: rows.map(({ total_count, ...rest }) => rest),
        page,
        pageSize,
        total
      },
      { status: 200 }
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unexpected error";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}