# restic 定期バックアップ環境ガイド

このディレクトリには、Windows環境からNASへ安全かつ高速に定期バックアップを行うためのスクリプト一式がまとめられています。

---

## 構成ファイル一覧

| ファイル名         | 役割                                                                |
| :----------------- | :------------------------------------------------------------------ |
| `config.ps1`       | バックアップ先（NASのパス）や保持期間などの基本設定                 |
| `password.txt.example` | リポジトリの暗号化パスワードファイルのサンプル                 |
| `password.txt`         | 実運用で使うパスワード（Gitの追跡対象外）                       |
| `exclude.txt`      | キャッシュや一時ファイルなど、除外するパスのリスト                  |
| `init-repo.ps1`    | 初回のみ実行するリポジトリ作成スクリプト                            |
| `backup.ps1`       | バックアップを実行し、古い世代を自動整理するメインスクリプト        |
| `check-status.ps1` | 保存されたバックアップ一覧や容量、健全性を確認するスクリプト        |
| `backup.log`       | バックアップ実行時の詳細ログ（自動生成されます）                    |

---

## 初回セットアップ手順

### ステップ 1: 設定を変更する

1. `password.txt.example` を `password.txt` にコピーします。
2. 作成した `password.txt` をメモ帳等で開き、実運用で使う安全なパスワードを入力して保存します。`password.txt` は `.gitignore` に登録されているため、Gitにはコミットしません。
3. `config.ps1` を開き、`$script:ResticRepository` を実際のNASの共有パス（例: `\\192.168.1.100\backup\restic-repo`）に書き換えます。

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

restic の `mount` は Windows ではサポートされていません。公式ドキュメントでも、`mount` は主に Unix/Linux 系の FUSE ベースの利用を想定していて、Windows では使えない前提です。

そのため、Windows では以下のような方法を使うのが安全で確実です。

1. スナップショット一覧を確認する

```powershell
restic -r "\\NAS_PATH\backup" -p "password.txt" snapshots
```

2. 目的のファイルやフォルダが明確なら、直接復元する

```powershell
# 最新のスナップショットを C:\Restore に復元する場合
restic -r "\\NAS_PATH\backup" -p "password.txt" restore latest --target "C:\Restore"
```

3. 復元後にエクスプローラでファイルを見て、必要なものだけ別の保存先にコピーする

```powershell
copy "C:\Restore\Users\<ユーザー名>\Desktop\file.txt" "D:\Recovered\file.txt"
```

> Windows では「バックアップをマウントしてエクスプローラで探す」方法より、まず `restore` で復元してから見つけるほうが安定します。

---
