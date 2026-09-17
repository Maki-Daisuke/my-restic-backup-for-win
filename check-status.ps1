# ==============================================================================
# restic スナップショット確認・点検スクリプト (check-status.ps1)
# ==============================================================================
# これまで保存されたスナップショット一覧の確認や、データの破損チェックを行います。

$configPath = Join-Path $PSScriptRoot "config.ps1"
if (-not (Test-Path $configPath)) {
    throw "設定ファイルが見つかりません: $configPath"
}
. $configPath

$env:RESTIC_REPOSITORY    = $script:ResticRepository
$env:RESTIC_PASSWORD_FILE = $script:PasswordFilePath

# S3 互換（B2）認証環境変数（s3: リポジトリの場合のみ）
if ($script:ResticRepository -like "s3:*") {
    $env:AWS_ACCESS_KEY_ID     = $script:S3AccessKeyId
    $env:AWS_SECRET_ACCESS_KEY = $script:S3SecretAccessKey
}

try {
    Write-Host "=== スナップショット一覧 ===" -ForegroundColor Cyan
    & restic snapshots

    Write-Host "`n=== リポジトリ容量の概要 ===" -ForegroundColor Cyan
    & restic stats

    Write-Host "`n=== リポジトリの整合性チェック (簡易) ===" -ForegroundColor Cyan
    & restic check
} finally {
    $env:RESTIC_REPOSITORY    = $null
    $env:RESTIC_PASSWORD_FILE = $null
    $env:AWS_ACCESS_KEY_ID     = $null
    $env:AWS_SECRET_ACCESS_KEY = $null
}
