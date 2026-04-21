# One-Click Production Deployment Script
# Run this after setting up your hosting platform

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Train Seat Exchange - Production Setup" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

$gitInstalled = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitInstalled) {
    Write-Host "ERROR: Git not installed" -ForegroundColor Red
    exit 1
}

# Initialize git if needed
if (-not (Test-Path ".git")) {
    Write-Host "Initializing git repository..." -ForegroundColor Yellow
    git init
    git add .
    git commit -m "Initial commit - Production ready"
}

# Check for uncommitted changes
$gitStatus = git status --porcelain
if ($gitStatus) {
    Write-Host "WARNING: You have uncommitted changes" -ForegroundColor Yellow
    Write-Host "Committing changes..." -ForegroundColor Yellow
    git add .
    git commit -m "Pre-deployment commit"
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Deployment Checklist" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Interactive checklist
$checks = @(
    "Have you created a PostgreSQL database?",
    "Have you got MSG91 production credentials?",
    "Have you got Razorpay LIVE keys?",
    "Have you got RapidAPI key?",
    "Have you set up environment variables on hosting platform?",
    "Have you configured monitoring (Sentry/UptimeRobot)?",
    "Have you tested the app locally?",
    "Do you have a backup plan?"
)

$allChecked = $true
foreach ($check in $checks) {
    $response = Read-Host "$check (y/n)"
    if ($response -ne 'y') {
        $allChecked = $false
    }
}

if (-not $allChecked) {
    Write-Host "`nPlease complete all checklist items before deploying." -ForegroundColor Red
    Write-Host "Check TECHNICAL_CHECKLIST.md for details." -ForegroundColor Yellow
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Deployment Platform" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Choose your deployment platform:"
Write-Host "1. Render.com (Recommended)"
Write-Host "2. Railway.app"
Write-Host "3. Heroku"
Write-Host "4. Manual deployment"

$platform = Read-Host "Enter choice (1-4)"

switch ($platform) {
    "1" {
        Write-Host "`nDeploying to Render.com..." -ForegroundColor Green
        Write-Host "Steps:"
        Write-Host "1. Push code to GitHub:"
        Write-Host "   - Create repo at github.com"
        Write-Host "   - Run: git remote add origin https://github.com/YOUR_USERNAME/train-seat-exchange.git"
        Write-Host "   - Run: git push -u origin main"
        Write-Host ""
        Write-Host "2. Go to render.com and sign up"
        Write-Host "3. Click 'New' -> 'Web Service'"
        Write-Host "4. Connect your GitHub repository"
        Write-Host "5. Use these settings:"
        Write-Host "   - Root Directory: backend"
        Write-Host "   - Build Command: pip install -r requirements.txt && pip install -r requirements-postgres.txt"
        Write-Host "   - Start Command: uvicorn main:app --host 0.0.0.0 --port `$PORT --workers 2"
        Write-Host "6. Add environment variables from .env.production.example"
        Write-Host "7. Click 'Create Web Service'"
        Write-Host ""
        Write-Host "Database setup:"
        Write-Host "1. In Render dashboard, click 'New' -> 'PostgreSQL'"
        Write-Host "2. Copy the Internal Database URL"
        Write-Host "3. Add it as DATABASE_URL in web service environment"
        Write-Host ""
    }
    "2" {
        Write-Host "`nDeploying to Railway..." -ForegroundColor Green
        Write-Host "Steps:"
        Write-Host "1. Install Railway CLI: npm i -g @railway/cli"
        Write-Host "2. Run: railway login"
        Write-Host "3. Run: railway init"
        Write-Host "4. Run: railway up"
        Write-Host "5. Add environment variables: railway variables set KEY=value"
        Write-Host ""
    }
    "3" {
        Write-Host "`nDeploying to Heroku..." -ForegroundColor Green
        Write-Host "Steps:"
        Write-Host "1. Install Heroku CLI: winget install Heroku.HerokuCLI"
        Write-Host "2. Run: heroku login"
        Write-Host "3. Run: heroku create train-seat-exchange"
        Write-Host "4. Run: heroku addons:create heroku-postgresql:mini"
        Write-Host "5. Run: git push heroku main"
        Write-Host ""
    }
    default {
        Write-Host "`nManual deployment selected" -ForegroundColor Yellow
        Write-Host "Follow TECHNICAL_CHECKLIST.md for detailed instructions"
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Post-Deployment Steps" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "After deployment, verify:"
Write-Host "1. Visit https://your-app-url.com/health"
Write-Host "2. Check https://your-app-url.com/docs"
Write-Host "3. Test OTP flow"
Write-Host "4. Test PNR verification"
Write-Host "5. Make a test payment (small amount)"
Write-Host "6. Monitor logs for errors"
Write-Host "7. Set up monitoring alerts"
Write-Host ""

Write-Host "Documentation:" -ForegroundColor Yellow
Write-Host "- Technical checklist: TECHNICAL_CHECKLIST.md"
Write-Host "- Deployment guide: DEPLOYMENT.md"
Write-Host "- PNR API setup: PNR_API_GUIDE.md"
Write-Host "- General info: README.md"
Write-Host ""

Write-Host "Good luck with your launch! " -ForegroundColor Green
Write-Host ""
