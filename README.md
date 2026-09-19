# restic 定期バックアップ環境ガイド

このディレクトリには、Windows環境からNASやBackblaze B2（S3互換API）へ安全かつ高速に定期バックアップを行うためのスクリプト一式がまとめられています。

---

## 構成ファイル一覧

| ファイル名         | 役割                                                                |
| :----------------- | :------------------------------------------------------------------ |
| `config.ps1.example` | バックアップ設定ファイルのサンプル                             |
| `config.ps1`         | 実運用の設定（Gitの追跡対象外）                                 |
| `password.txt.example` | リポジトリの暗号化パスワードファイルのサンプル                 |
| `password.txt`         | 実運用で使うパスワード（Gitの追跡対象外）                       |
| `exclude.txt`      | キャッシュや一時ファイルなど、除外するパスのリスト                  |
| `init-repo.ps1`    | 初回のみ実行するリポジトリ作成スクリプト                            |
| `backup.ps1`       | バックアップを実行し、古い世代を自動整理するメインスクリプト        |
| `check-status.ps1` | 保存されたバックアップ一覧や容量、健全性を確認するスクリプト        |
| `mount.ps1`        | スナップショットをマウントしてエクスプローラで参照するスクリプト    |
| `backup.log`       | バックアップ実行時の詳細ログ（自動生成されます）                    |

---

## 初回セットアップ手順

### ステップ 1: 設定を変更する

1. `password.txt.example` を `password.txt` にコピーします。
2. 作成した `password.txt` をメモ帳等で開き、実運用で使う安全なパスワードを入力して保存します。`password.txt` は `.gitignore` に登録されているため、Gitにはコミットしません。
3. `config.ps1.example` を `config.ps1` にコピーします。
4. 作成した `config.ps1` を開き、バックアップ先に合わせて設定します。
   - **NAS の場合**: `$script:ResticRepository` を共有パス（例: `\\192.168.1.100\backup\restic-repo`）に書き換えます。
   - **Backblaze B2 の場合**: `$script:ResticRepository` を S3 互換エンドポイント（例: `s3:s3.us-west-004.backblazeb2.com/restic-backup`）に、`$script:S3AccessKeyId` と `$script:S3SecretAccessKey` を B2 の S3 互換アクセスキーに書き換えます（後述の「Backblaze B2 を使う場合」を参照）。
   - 必要に応じて `$script:BackupSourcePath` なども環境に合わせて書き換えます。
   - `config.ps1` は `.gitignore` に登録されているため、Gitにはコミットしません。

### ステップ 2: リポジトリを初期化する

PowerShellを起動し、以下のスクリプトを一度だけ実行します：

```powershell
.\init-repo.ps1
```

「リポジトリの初期化に成功しました！」と表示されれば準備完了です。

### ステップ 3: 手動で一度バックアップを試す

PowerShellを**管理者として実行**し、バックアップを実行します：

```powershell
.\backup.ps1
```

※ 管理者として実行することで、Windowsの「ボリュームシャドウコピー（VSS）」が有効になり、OBSやブラウザ、Discordが起動したままでもロックされずに安全にバックアップされます。

### スナップショットにタグを付ける

バックアップ実行時にタグを付与すると、後から目的別にスナップショットを絞り込みやすくなります。

```powershell
# コマンドラインでタグを指定
.\backup.ps1 -Tag "before-update"

# タグなし（config.ps1 の $script:BackupTag が使われます）
.\backup.ps1
```

`config.ps1` に `$script:BackupTag = "scheduled"` のように設定しておくと、タスクスケジューラからの定期実行でも自動的にタグが付与されます。

タグ付きスナップショットの検索例:

```powershell
restic -r "\\NAS_PATH\backup" -p "password.txt" snapshots --tag "before-update"
```

---

## Backblaze B2 を使う場合（S3互換API）

> **重要**: restic 公式ドキュメントでは、Backblaze B2 へのバックアップは **S3 互換 API** の利用を推奨しています。B2 ネイティブ（`b2:`）はエラー処理の問題があるため、S3 互換エンドポイントを使うのが確実です。

### 1. B2 で S3 互換アクセスキーを作成する

1. [Backblaze B2 管理画面](https://www.backblaze.com/b2) にログインします。
2. **Buckets** でバケットを作成（例: `restic-backup`）。
3. そのバケットの **S3 Compatible Keys** からキーを作成します。
   - 参考: [S3 Compatible App Keys](https://www.backblaze.com/docs/cloud-storage-s3-compatible-app-keys)
4. 表示される **S3 Access Key ID** と **S3 Secret Access Key** をメモします。
5. バケットのリージョン（例: `us-west-004`）も確認しておきます。

### 2. config.ps1 を設定する

```powershell
# S3 互換エンドポイント（リージョンとバケット名を自分のものに置き換える）
$script:ResticRepository = "s3:https://s3.us-west-004.backblazeb2.com/restic-backup"

# B2 の S3 互換アクセスキー
$script:S3AccessKeyId     = "YOUR_B2_S3_ACCESS_KEY_ID"
$script:S3SecretAccessKey = "YOUR_B2_S3_SECRET_ACCESS_KEY"
```

### 3. B2 のライフサイクル設定（推奨）

S3 互換 API を使う場合、restic は不要になったファイルを「隠す」だけで、B2 側では古いバージョンが保持され続けます。容量を無駄にしないため、B2 管理画面でバケットのライフサイクルルールに **「Keep only the last version of the file（ファイルの最終バージョンのみ保持）」** を設定してください。

参考: [Backblaze Lifecycle Rules](https://www.backblaze.com/docs/cloud-storage-lifecycle-rules)

### 4. 初期化とバックアップ

```powershell
# 初回のみリポジトリを初期化
.\init-repo.ps1

# バックアップ実行
.\backup.ps1
```

---

## タスク スケジューラによる自動定期実行

深夜やPC起動時に自動でバックアップを走らせる設定手順です：

1. スタートメニューから **「タスク スケジューラ」** を開きます。
2. 右ペインの **「タスクの作成」** をクリックします。
3. **全般タブ**:
   - 名前: `Restic Backup`
   - **「最上位の特権で実行する」に必ずチェックを入れる**（VSS機能を使うため）
   - 「ユーザーがログオンしているかどうかにかかわらず実行する」または「ユーザーがログオンしているときのみ実行する」を選択
4. **トリガー タブ**:
   - 「新規」をクリックし、「毎日」好きな時間（例: 深夜 3:00）または「ログオン時」を指定
5. **操作 タブ**:
   - 「新規」をクリック
   - プログラム/スクリプト: `powershell.exe` / `pwsh.exe`
   - 引数の追加: `-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "<PATH TO>\restic-backup\backup.ps1"`
   - 開始（オプション）: `<PATH TO>\restic-backup`
6. 「OK」を押して保存します。

> `<PATH TO>` は、`restic-backup` ディレクトリが存在するパスに置き換えてください。

---
## バックアップの確認と復元（リストア）

### バックアップ状況の確認

```powershell
.\check-status.ps1
```

これまでのスナップショット（バックアップ履歴）や容量が表示されます。

### データの復元（例: 最新の状態に戻す）

```powershell
# 最新のスナップショットを C:\Restore に復元する場合
restic -r "\\NAS_PATH\backup" -p "password.txt" restore latest --target "C:\Restore"
```

特定のフォルダ（例: `AppData\Roaming\obs-studio` だけ）を復元することも可能です。

### 「どのファイルがあるか探しながら復元したい」場合

`restic mount` は Windows ではサポートされていないため、代わりに **`restic-mount`**（別ツール）を使ってスナップショットをマウントします。

> `restic-mount` は未インストールの場合は先にインストールしてください（ https://github.com/Maki-Daisuke/restic-mount-win ）。

#### スクリプトでマウントする（おすすめ）

```powershell
# 全スナップショットを R: にマウント（ツリー表示）
.\mount.ps1

# マウント先を指定
.\mount.ps1 -MountPoint "D:\backup"

# 特定のスナップショットのみマウント
.\mount.ps1 -Snapshot <snapshot-id>
```

マウント中はスクリプトがブロックされます。エクスプローラで `R:` を開いて、スナップショットのツリーから必要なファイルを探しながらコピーしてください。解除するには `Ctrl+C` を押します。

#### 直接 restic-mount を使う場合

```powershell
# 環境変数を設定
$env:RESTIC_REPOSITORY    = "\\NAS_PATH\backup"
$env:RESTIC_PASSWORD_FILE = "password.txt"

# マウント（Ctrl+C で解除）
restic-mount R:
```

#### マウントなしで直接復元する場合

目的のファイルが明確なら、マウントせずに直接復元するほうが簡単です。

```powershell
# 最新のスナップショットを C:\Restore に復元する場合
restic -r "\\NAS_PATH\backup" -p "password.txt" restore latest --target "C:\Restore"
```

---
