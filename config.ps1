# restic-backup 設定ファイル
# このファイルでバックアップ先やパスワード、対象パスを一括設定します。

# バックアップ先リポジトリ（NASのUNCパスまたはマウントされたドライブ）
# 例: "\\192.168.1.100\backup\restic-repo" または "Z:\restic-repo"
$script:ResticRepository = "\\NAS_HOSTNAME_OR_IP\backup\restic-repo"

# リポジトリの暗号化パスワードファイルのパス
# このディレクトリ内の password.txt から読み込みます
$script:PasswordFilePath = Join-Path $PSScriptRoot "password.txt"

# バックアップ対象ディレクトリ（通常はユーザープロファイル全体）
$script:BackupSourcePath = "C:\Users\Daisu"

# 除外設定ファイルのパス
$script:ExcludeFilePath  = Join-Path $PSScriptRoot "exclude.txt"

# 世代管理ポリシー（保持するスナップショット数）
$script:KeepDaily   = 7
$script:KeepWeekly  = 4
$script:KeepMonthly = 6

# ログファイルの出力先
$script:LogFilePath = Join-Path $PSScriptRoot "backup.log"
