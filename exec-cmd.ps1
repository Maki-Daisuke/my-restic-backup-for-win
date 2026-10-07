# ==============================================================================
# restic 用コマンド実行ラッパー (exec-cmd.ps1)
# ==============================================================================
# 例:
#   ./exec-cmd.ps1 restic snapshots
#   ./exec-cmd.ps1 restic unlock
#   ./exec-cmd.ps1 restic check
#
# config.ps1 で定義されたリポジトリ設定と、B2 S3 互換認証情報を環境変数へ
# 設定したうえで、指定したコマンドを実行します。
# 実行後は必ず環境変数をクリアします。

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Command,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CommandArgs
)

$ErrorActionPreference = "Stop"

$configPath = Join-Path $PSScriptRoot "config.ps1"
if (-not (Test-Path $configPath)) {
    throw "設定ファイルが見つかりません: $configPath"
}

. $configPath

if (-not $script:ResticRepository) {
    throw "ResticRepository が設定されていません。config.ps1 を確認してください。"
}

if (-not (Test-Path $script:PasswordFilePath)) {
    throw "パスワードファイルが見つかりません: $script:PasswordFilePath"
}

$originalRepository = $env:RESTIC_REPOSITORY
$originalPasswordFile = $env:RESTIC_PASSWORD_FILE
$originalAccessKey = $env:AWS_ACCESS_KEY_ID
$originalSecretKey = $env:AWS_SECRET_ACCESS_KEY

try {
    $env:RESTIC_REPOSITORY = $script:ResticRepository
    $env:RESTIC_PASSWORD_FILE = $script:PasswordFilePath

    if ($script:ResticRepository -like "s3:*") {
        $env:AWS_ACCESS_KEY_ID = $script:S3AccessKeyId
        $env:AWS_SECRET_ACCESS_KEY = $script:S3SecretAccessKey
    }

    $resolvedCommand = Get-Command $Command -ErrorAction Stop
    Write-Host "==> 実行中: $($resolvedCommand.Name) $($CommandArgs -join ' ')" -ForegroundColor Cyan
    & $resolvedCommand.Source @CommandArgs
    exit $LASTEXITCODE
} finally {
    if ($null -eq $originalRepository) {
        $env:RESTIC_REPOSITORY = $null
    } else {
        $env:RESTIC_REPOSITORY = $originalRepository
    }

    if ($null -eq $originalPasswordFile) {
        $env:RESTIC_PASSWORD_FILE = $null
    } else {
        $env:RESTIC_PASSWORD_FILE = $originalPasswordFile
    }

    if ($null -eq $originalAccessKey) {
        $env:AWS_ACCESS_KEY_ID = $null
    } else {
        $env:AWS_ACCESS_KEY_ID = $originalAccessKey
    }

    if ($null -eq $originalSecretKey) {
        $env:AWS_SECRET_ACCESS_KEY = $null
    } else {
        $env:AWS_SECRET_ACCESS_KEY = $originalSecretKey
    }
}
