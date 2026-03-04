# PowerShell script to test NeRF fix
# Run with: .\test_nerf_fix.ps1

$env:YSU_NERF_HASHGRID = "models/nerf_hashgrid.bin"
$env:YSU_NERF_OCC = "models/nerf_occ.bin"
$env:YSU_W = "800"
$env:YSU_H = "600"
$env:YSU_SPP = "1"
$env:YSU_USE_BVH = "1"
$env:YSU_NERF_STEPS = "64"

Write-Host ""
Write-Host "===================================" -ForegroundColor Cyan
Write-Host "   NeRF Fix Verification" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Testing mode 19 (buffer validation)..." -ForegroundColor Yellow
$env:YSU_RENDER_MODE = "19"
Start-Process -FilePath ".\gpu_demo.exe"
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "Testing mode 17 (MLP output)..." -ForegroundColor Yellow
$env:YSU_RENDER_MODE = "17"
Start-Process -FilePath ".\gpu_demo.exe"
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "Testing mode 2 (hybrid mesh+NeRF)..." -ForegroundColor Yellow
$env:YSU_RENDER_MODE = "2"
$env:YSU_NERF_BLEND = "0.35"
Start-Process -FilePath ".\gpu_demo.exe"

Write-Host ""
Write-Host "All tests launched. Check the windows!" -ForegroundColor Green
Write-Host ""
Write-Host "Expected results:" -ForegroundColor White
Write-Host "  Mode 19: Dark brownish-gray" -ForegroundColor Gray
Write-Host "  Mode 17: Trained NeRF colors (should be recognizable object)" -ForegroundColor Green
Write-Host "  Mode 2: Mesh with NeRF overlay" -ForegroundColor Cyan
Write-Host ""
Write-Host "If you still see BLUE STREAKS in mode 17, the fix didn't apply." -ForegroundColor Red
Write-Host "In that case, we need to force a full rebuild." -ForegroundColor Red
Write-Host ""
