# ==============================================================================
# restic スナップショットマウントスクリプト (mount.ps1)
# ==============================================================================
# restic のスナップショットを、エクスプローラで参照できるフォルダとしてマウントします。
#
# ※ Windows では `restic mount` の代わりに `restic-mount` コマンドを使います。
#   restic-mount は https://github.com/aklomp/restic-mount 等で提供される別ツールです。
#   未インストールの場合は先にインストールしてください。
#
# 使い方:
#   .\mount.ps1                          # 全スナップショットを R: にマウント（ツリー表示）
#   .\mount.ps1 -MountPoint D:\backup    # マウント先を指定
#   .\mount.ps1 -Snapshot <snapshot-id>  # 特定のスナップショットのみマウント
#
# マウント中はこのウィンドウがブロックされます。解除するには Ctrl+C を押してください。
# ==============================================================================
[CmdletBinding()]
param(
    # マウント先ドライブ（デフォルト: R:）
    [string]$MountPoint = "R:",

    # マウントするスナップショット（デフォルト: 全スナップショットをツリー表示）
    [string]$Snapshot = ""
)

$ErrorActionPreference = "Stop"

# 1. 設定ファイルの読み込み
$configPath = Join-Path $PSScriptRoot "config.ps1"
if (-not (Test-Path $configPath)) {
    throw "設定ファイルが見つかりません: $configPath"
}
. $configPath

# 2. パスワードファイルの確認
if (-not (Test-Path $script:PasswordFilePath)) {
    throw "パスワードファイルが見つかりません: $script:PasswordFilePath"
}

# 3. restic-mount の存在確認
$resticMount = Get-Command "restic-mount" -ErrorAction SilentlyContinue
if (-not $resticMount) {
    throw "restic-mount コマンドが見つかりません。先にインストールしてください（例: https://github.com/aklomp/restic-mount ）。"
}

# 4. マウント先フォルダの作成（ドライブ文字（例: R:）の場合はスキップ）
$isDriveLetter = $MountPoint -match '^[A-Za-z]:\\?$'
if (-not $isDriveLetter -and -not (Test-Path $MountPoint)) {
    New-Item -ItemType Directory -Path $MountPoint -Force | Out-Null
    Write-Host "マウント先フォルダを作成しました: $MountPoint" -ForegroundColor Cyan
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "スナップショットをマウントします"
Write-Host "リポジトリ: $script:ResticRepository"
Write-Host "スナップショット: $Snapshot"
Write-Host "マウント先: $MountPoint"
Write-Host "==========================================" -ForegroundColor Cyan

try {
    # 環境変数の設定
    $env:RESTIC_REPOSITORY = $script:ResticRepository
    $env:RESTIC_PASSWORD_FILE = $script:PasswordFilePath

    # S3 互換（B2）認証環境変数（s3: リポジトリの場合のみ）
    if ($script:ResticRepository -like "s3:*") {
        $env:AWS_ACCESS_KEY_ID = $script:S3AccessKeyId
        $env:AWS_SECRET_ACCESS_KEY = $script:S3SecretAccessKey
    }

    # restic-mount の実行（マウント中はブロックされる）
    # スナップショットを指定する場合は --snapshot オプションを使う
    $mountArgs = @($MountPoint)
    if ($Snapshot) {
        $mountArgs += "--snapshot"
        $mountArgs += $Snapshot
    }

    Write-Host "restic-mount を実行中...（解除するには Ctrl+C）" -ForegroundColor Yellow
    & restic-mount @mountArgs
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        throw "restic-mount が終了コード $exitCode で終了しました。"
    }
}
catch {
    Write-Host "エラーが発生しました: $_" -ForegroundColor Red
    exit 1
}
finally {
    # セキュリティのため環境変数を消去
    $env:RESTIC_REPOSITORY = $null
    $env:RESTIC_PASSWORD_FILE = $null
    $env:AWS_ACCESS_KEY_ID = $null
    $env:AWS_SECRET_ACCESS_KEY = $null
    Write-Host "マウント処理を終了しました。" -ForegroundColor Cyan
}
