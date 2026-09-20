# ==============================================================================
# restic 定期バックアップ実行スクリプト (backup.ps1)
# ==============================================================================
[CmdletBinding()]
param(
    # スナップショットに付与するタグ（例: "manual", "before-update"）
    # 指定しない場合は config.ps1 の $script:BackupTag が使われます
    [string]$Tag
)

$ErrorActionPreference = "Stop"

# 1. 管理者権限の確認（VSSスナップショット `--use-fs-snapshot` に必要）
$currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$isAdministrator = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdministrator) {
    Write-Warning "管理者権限で実行されていません。VSSスナップショット(--use-fs-snapshot)を利用するには管理者権限が必要です。"
}

# 2. 設定ファイルの読み込み
$configPath = Join-Path $PSScriptRoot "config.ps1"
if (-not (Test-Path $configPath)) {
    throw "設定ファイルが見つかりません: $configPath"
}
. $configPath

# 3. パスワードファイルの確認
if (-not (Test-Path $script:PasswordFilePath)) {
    throw "パスワードファイルが見つかりません: $script:PasswordFilePath"
}

# 4. S3 互換（B2）認証情報の確認（リポジトリが s3: で始まる場合）
if ($script:ResticRepository -like "s3:*") {
    if (-not $script:S3AccessKeyId -or $script:S3AccessKeyId -eq "YOUR_B2_S3_ACCESS_KEY_ID") {
        throw "S3 Access Key ID が設定されていません。config.ps1 の \$script:S3AccessKeyId を確認してください。"
    }
    if (-not $script:S3SecretAccessKey -or $script:S3SecretAccessKey -eq "YOUR_B2_S3_SECRET_ACCESS_KEY") {
        throw "S3 Secret Access Key が設定されていません。config.ps1 の \$script:S3SecretAccessKey を確認してください。"
    }
}

# 4. ログ関数の定義
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] $Message"
    Write-Output $logLine
    if ($script:LogFilePath) {
        Add-Content -Path $script:LogFilePath -Value $logLine -Encoding utf8
    }
}

Write-Log "=========================================="
Write-Log "restic バックアップ処理を開始します"
Write-Log "対象: $script:BackupSourcePath"
Write-Log "リポジトリ: $script:ResticRepository"

try {
    # 環境変数の設定
    $env:RESTIC_REPOSITORY    = $script:ResticRepository
    $env:RESTIC_PASSWORD_FILE = $script:PasswordFilePath

    # S3 互換（B2）認証環境変数（s3: リポジトリの場合のみ）
    if ($script:ResticRepository -like "s3:*") {
        $env:AWS_ACCESS_KEY_ID     = $script:S3AccessKeyId
        $env:AWS_SECRET_ACCESS_KEY = $script:S3SecretAccessKey
    }

    # バックアップ引数の構築
    $backupArgs = @(
        "backup",
        "--verbose",
        "--iexclude-file=$script:ExcludeFilePath"
    )

    # タグの指定（コマンドライン引数 > config.ps1 の順で優先）
    $effectiveTag = $Tag
    if (-not $effectiveTag -and $script:BackupTag) {
        $effectiveTag = $script:BackupTag
    }
    if ($effectiveTag) {
        $backupArgs += "--tag"
        $backupArgs += $effectiveTag
        Write-Log "スナップショットタグ: $effectiveTag"
    }

    # 管理者権限がある場合はVSSスナップショットを有効化
    if ($isAdministrator) {
        $backupArgs += "--use-fs-snapshot"
        Write-Log "VSSボリュームシャドウコピー有効: 使用中のファイルも安全に保護します"
    }

    $backupArgs += $script:BackupSourcePath

    # 5. バックアップの実行
    Write-Log "restic backup コマンドを実行中..."
    & restic @backupArgs 2>&1 | ForEach-Object { Write-Log $_ }
    if ($LASTEXITCODE -ne 0) {
        throw "restic backup が終了コード $LASTEXITCODE で失敗しました。"
    }
    Write-Log "バックアップが正常に完了しました。"

    # 6. 古いスナップショットの自動整理（世代管理）
    Write-Log "世代管理ポリシーに従って古いスナップショットを整理中..."
    $forgetArgs = @(
        "forget",
        "--keep-daily", "$script:KeepDaily",
        "--keep-weekly", "$script:KeepWeekly",
        "--keep-monthly", "$script:KeepMonthly",
        "--prune"
    )
    & restic @forgetArgs 2>&1 | ForEach-Object { Write-Log $_ }
    Write-Log "世代管理の整理が完了しました。"

} catch {
    Write-Log "エラーが発生しました: $_"
    exit 1
} finally {
    # セキュリティのため環境変数を消去
    $env:RESTIC_REPOSITORY    = $null
    $env:RESTIC_PASSWORD_FILE = $null
    $env:AWS_ACCESS_KEY_ID     = $null
    $env:AWS_SECRET_ACCESS_KEY = $null
    Write-Log "バックアップ処理を終了しました。"
    Write-Log "=========================================="
}
