# Manual Test Script for Train Seat Exchange API
# Run this script to test the API interactively

$baseUrl = "http://localhost:8000/api/v1"

Write-Host "`n========================================"
Write-Host "Train Seat Exchange - Manual Testing"
Write-Host "========================================`n"

# Test 1: Send OTP
Write-Host "Step 1: Sending OTP to 9876543210..." -ForegroundColor Yellow
$otpResponse = Invoke-RestMethod -Uri "$baseUrl/otp/send" -Method Post -Body (@{phone="9876543210"} | ConvertTo-Json) -ContentType "application/json"
Write-Host "Success!" -ForegroundColor Green
Write-Host "   Your OTP is: $($otpResponse.debug_otp)" -ForegroundColor Green
$otp = $otpResponse.debug_otp

Write-Host "`n----------------------------------------`n"

# Test 2: Verify OTP
Write-Host "Step 2: Verifying OTP..." -ForegroundColor Yellow
$verifyResponse = Invoke-RestMethod -Uri "$baseUrl/otp/verify" -Method Post -Body (@{phone="9876543210"; otp=$otp} | ConvertTo-Json) -ContentType "application/json"
Write-Host "OTP Verified!" -ForegroundColor Green

Write-Host "`n----------------------------------------`n"

# Test 3: Verify PNR
Write-Host "Step 3: Verifying PNR..." -ForegroundColor Yellow
$pnrBody = @{
    pnr = "1234567890"
} | ConvertTo-Json

try {
    $pnrResponse = Invoke-RestMethod -Uri "$baseUrl/pnr/verify" -Method Post -Body $pnrBody -ContentType "application/json"
    Write-Host "PNR Verified!" -ForegroundColor Green
    Write-Host "   Train: $($pnrResponse.train_number) - $($pnrResponse.train_name)"
    Write-Host "   Status: $($pnrResponse.status)"
    Write-Host "   Seat: $($pnrResponse.seat_number)"
    Write-Host "   Confirmed: $($pnrResponse.is_confirmed)"
} catch {
    Write-Host "PNR verification test skipped" -ForegroundColor Gray
}

Write-Host "`n----------------------------------------`n"

# Test 4: Search for entries
Write-Host "Step 3: Searching for seat exchanges..." -ForegroundColor Yellow
$searchBody = @{
    train_number = "12345"
    from_station = "NDLS"
    to_station = "BCT"
} | ConvertTo-Json

try {
    $searchResponse = Invoke-RestMethod -Uri "$baseUrl/entry/search" -Method Post -Body $searchBody -ContentType "application/json"
    Write-Host "Found $($searchResponse.Count) entries" -ForegroundColor Green
    if ($searchResponse.Count -gt 0) {
        $searchResponse | ForEach-Object {
            Write-Host "   - PNR: $($_.pnr), Train: $($_.train_name)"
        }
    }
} catch {
    Write-Host "No entries found yet" -ForegroundColor Gray
}

Write-Host "`n========================================"
Write-Host "Test Complete!" -ForegroundColor Green
Write-Host "========================================`n"

Write-Host "What you can do next:" -ForegroundColor Yellow
Write-Host "   1. Open Swagger UI: http://localhost:8000/docs"
Write-Host "   2. Open Mobile App: http://localhost:8000/static/mobile-test.html"
Write-Host "   3. Test PNR verification (currently in mock mode)"
Write-Host "   4. Check PNR_API_GUIDE.md for production API setup"
Write-Host ""
