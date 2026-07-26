# AIRA OS — Build Script for Android APK
# Run this in PowerShell from the aira_app directory:
#   .\build.ps1
#
# This loads keys from .env.local and passes them as --dart-define at build time.
# Keys are embedded in the app binary, NOT in the source code.

$env_file = ".env.local"

if (-not (Test-Path $env_file)) {
    Write-Error "ERROR: .env.local not found. Create it first with your API keys."
    exit 1
}

# Load .env.local
$env_vars = @{}
Get-Content $env_file | ForEach-Object {
    if ($_ -match "^\s*([^#][^=]+)=(.+)$") {
        $env_vars[$Matches[1].Trim()] = $Matches[2].Trim()
    }
}

$SUPABASE_URL = $env_vars["SUPABASE_URL"]
$SUPABASE_ANON_KEY = $env_vars["SUPABASE_ANON_KEY"]
$GROQ_API_KEY = $env_vars["GROQ_API_KEY"]
$BACKEND_URL = $env_vars["BACKEND_URL"]

Write-Host "Building AIRA OS APK..." -ForegroundColor Cyan

flutter build apk --release `
    --dart-define="SUPABASE_URL=$SUPABASE_URL" `
    --dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" `
    --dart-define="GROQ_API_KEY=$GROQ_API_KEY" `
    --dart-define="BACKEND_URL=$BACKEND_URL"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ APK built successfully!" -ForegroundColor Green
    Write-Host "📦 Location: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Yellow
} else {
    Write-Host "❌ Build failed. Check the errors above." -ForegroundColor Red
}
