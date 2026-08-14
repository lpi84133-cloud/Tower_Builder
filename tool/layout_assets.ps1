# One-shot asset reorganisation: flattens the delivered art drop into the
# folder layout that pubspec.yaml declares. Safe to re-run (skips missing).
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$assets = Join-Path $root 'assets'

$dirs = @('art\site', 'art\shell', 'audio', 'branding')
foreach ($d in $dirs) {
  $p = Join-Path $assets $d
  if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
}

$map = @{
  'sky_asset.webp'                            = 'art\site\sky_dome.webp'
  'start_bg.webp'                             = 'art\site\skyline_strip.webp'
  'main_block_asset.webp'                     = 'art\site\foundation_pad.webp'
  'hook_asset.webp'                           = 'art\site\crane_hook.webp'
  'cloud_asset_01.webp'                       = 'art\site\cloud_a.webp'
  'cloud_asset_02.webp'                       = 'art\site\cloud_b.webp'
  'block_asset.webp'                          = 'art\site\module_01.webp'
  'block_asset_02.webp'                       = 'art\site\module_02.webp'
  'block_asset_03.webp'                       = 'art\site\module_03.webp'
  'block_asset_04.webp'                       = 'art\site\module_04.webp'
  'button_asset.webp'                         = 'art\shell\plate_primary.webp'
  'button_blank.webp'                         = 'art\shell\plate_blank.webp'
  'game_name.webp'                            = 'art\shell\wordmark.webp'
  'add_assets\Game_Name.webp'                 = 'art\shell\wordmark_alt.webp'
  'add_assets\Vertical_Loading_Screen.webp'   = 'art\shell\boot_portrait.webp'
  'add_assets\Horizontal_Loading_Screen.webp' = 'art\shell\boot_landscape.webp'
  'add_assets\Vertical_Notifications_Screen.webp'   = 'art\shell\notice_portrait.webp'
  'add_assets\Horizontal_Notifications_Screen.webp' = 'art\shell\notice_landscape.webp'
  'add_assets\Vertical_Nowifi_Screen.webp'    = 'art\shell\offline_portrait.webp'
  'add_assets\Horizontal_Nowifi_Screen.webp'  = 'art\shell\offline_landscape.webp'
  'add_assets\icon.webp'                      = 'branding\app_mark.webp'
}

foreach ($src in $map.Keys) {
  $from = Join-Path $assets $src
  $to = Join-Path $assets $map[$src]
  if (Test-Path $from) {
    Move-Item -Path $from -Destination $to -Force
    Write-Host "moved $src -> $($map[$src])"
  }
  elseif (Test-Path $to) { Write-Host "skip (already placed) $($map[$src])" }
  else { Write-Warning "missing $src" }
}

$leftover = Join-Path $assets 'add_assets'
if ((Test-Path $leftover) -and -not (Get-ChildItem $leftover -Force)) {
  Remove-Item $leftover -Force
}
Write-Host 'asset layout done'
