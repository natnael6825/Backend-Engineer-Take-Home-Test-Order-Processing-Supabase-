Write-Host "Running Supabase migrations against the linked project..." -ForegroundColor Cyan
supabase db push
if ($LASTEXITCODE -ne 0) {
  Write-Error "supabase db push failed"
  exit 1
}

$seed = Read-Host "Run seed data? (y/N)"
if ($seed -match '^(y|yes)$') {
  npm run db:seed
  if ($LASTEXITCODE -ne 0) {
    Write-Error "db:seed failed"
    exit 1
  }
}

Write-Host "Done." -ForegroundColor Green
