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

# S3 互換（B2）認証環境変数（s3: リポジトリの場合のみ）
if ($script:ResticRepository -like "s3:*") {
    if (-not $script:S3AccessKeyId -or $script:S3AccessKeyId -eq "YOUR_B2_S3_ACCESS_KEY_ID") {
        throw "S3 Access Key ID が設定されていません。config.ps1 の \$script:S3AccessKeyId を確認してください。"
    }
    if (-not $script:S3SecretAccessKey -or $script:S3SecretAccessKey -eq "YOUR_B2_S3_SECRET_ACCESS_KEY") {
        throw "S3 Secret Access Key が設定されていません。config.ps1 の \$script:S3SecretAccessKey を確認してください。"
    }
    $env:AWS_ACCESS_KEY_ID     = $script:S3AccessKeyId
    $env:AWS_SECRET_ACCESS_KEY = $script:S3SecretAccessKey
}

try {
    Write-Host "リポジトリを初期化します: $script:ResticRepository" -ForegroundColor Cyan
    & restic init
    if ($LASTEXITCODE -eq 0) {
        Write-Host "リポジトリの初期化に成功しました！" -ForegroundColor Green
    } else {
        Write-Error "初期化に失敗しました。リポジトリのパスや認証情報、アクセス権限を確認してください。"
    }
} finally {
    $env:RESTIC_REPOSITORY    = $null
    $env:RESTIC_PASSWORD_FILE = $null
    $env:AWS_ACCESS_KEY_ID     = $null
    $env:AWS_SECRET_ACCESS_KEY = $null
}
