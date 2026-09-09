# ==============================================================================
# restic 初回リポジトリ初期化スクリプト (init-repo.ps1)
# ==============================================================================
# NASに新しくバックアップ用リポジトリを作成するときに「最初の一度だけ」実行します。

$configPath = Join-Path $PSScriptRoot "config.ps1"
if (-not (Test-Path $configPath)) {
    throw "設定ファイルが見つかりません: $configPath"
}
. $configPath

if (-not (Test-Path $script:PasswordFilePath)) {
    throw "パスワードファイルが見つかりません: $script:PasswordFilePath"
}

# パスワードがテンプレートのままか確認
$currentPassword = (Get-Content $script:PasswordFilePath -Raw).Trim()
if ($currentPassword -eq "YOUR_SECURE_PASSWORD_HERE" -or [string]::IsNullOrWhiteSpace($currentPassword)) {
    Write-Error "password.txt がまだ変更されていません！ password.txt を開いて、安全なパスワードを設定してください。"
    exit 1
}

$env:RESTIC_REPOSITORY    = $script:ResticRepository
$env:RESTIC_PASSWORD_FILE = $script:PasswordFilePath

try {
    Write-Host "リポジトリを初期化します: $script:ResticRepository" -ForegroundColor Cyan
    & restic init
    if ($LASTEXITCODE -eq 0) {
        Write-Host "リポジトリの初期化に成功しました！" -ForegroundColor Green
    } else {
        Write-Error "初期化に失敗しました。NASのパスやアクセス権限を確認してください。"
    }
} finally {
    $env:RESTIC_REPOSITORY    = $null
    $env:RESTIC_PASSWORD_FILE = $null
}
