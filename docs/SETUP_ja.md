# PLaMo 3 Translate for macOS — 環境構築・アプリ実装ガイド

**4モデル対応（0.8B / 2B / 8B / 31B）｜日本語セットアップガイド**

対象：Apple Silicon搭載Mac / Python仮想環境 / MLX-4bit / Gradio 6 / AppleScript常駐アプリ  
作業ディレクトリ：`~/MyProject`　｜　ローカルURL：`http://127.0.0.1:7860/`　｜　アプリ名：`PLaMo Translate.app`

> **動作確認について：** Python 3.15と以下に記載するライブラリの組み合わせで、4モデルの読み込み、単体英訳、およびGradioサーバーの起動を確認しています。AppleScriptアプリの書き出しやアプリ動作はmacOS環境により挙動が異なることがあるため、各節にある手順に従って個別に確認してください。**すべてのmacOS環境や言語ペアでの動作・翻訳品質を保証するものではありません**。

本プロジェクトは個人による非公式な実装であり、Preferred Networksの公式アプリケーションではありません。概要は[README](../README.md)、実装ソースは[`bin/`](../bin/)を参照してください。

## 1. 構築するシステムとディレクトリ構成

- [PLaMo 3 Translate](https://huggingface.co/pfnet/plamo-3-translate-31b-MLX-4bit)の **0.8B・2B・8B・31B** をMLX-4bit形式でダウンロードします。
- Python仮想環境を1つ作成し、**選択した1モデルのみ**を起動時にロードします。
- Gradioの翻訳GUIで「日本語 → 英語」「英語 → 日本語」「その他の言語」を排他的に選択します。「その他の言語」モードでは53の言語選択肢から翻訳元・翻訳先を指定できます。
- AppleScript製の常駐アプリからモデルを選択して起動し、ブラウザで翻訳インターフェースを表示する構成です。
- すべてのモデルが同じポート `7860` を使用するため、別モデルを使う場合はいったん現在のモデルを停止します。

構築先の例：

```text
~/MyProject/
├── plamo-mlx-env/                        # Python仮想環境
├── lib/                                  # モデル本体（GitHubでは配布しない）
│   ├── plamo-3-translate-31b-MLX-4bit/
│   ├── plamo-3-translate-8b-MLX-4bit/
│   ├── plamo-3-translate-2b-MLX-4bit/
│   └── plamo-3-translate-0.8b-MLX-4bit/
└── bin/
    ├── translate_gui.py
    ├── start_plamo.sh
    └── plamo_stayopen_launcher.applescript
```

`~/MyProject` はホームディレクトリ下の作業場所を表す一般的な表記です。スクリプトはこの構成を前提にしているため、別の場所に配置する場合は各スクリプト内のパスも変更する必要があります。

**GitHub上のリポジトリとMacの作業ディレクトリは別物です。** GitHubには主に`README.md`、`.gitignore`、`bin/`、`docs/`を置き、重みファイルや仮想環境は登録しません。

## 2. 作業前の確認

macOSのターミナルを開き、Apple Silicon上で動作していることとPythonのバージョンを確認します。

```bash
uname -m
python3 --version
```

`uname -m` は通常 `arm64` です。**動作確認時にはPython 3.15を使用しています。** 別のバージョンでは、利用可能なMLX等のパッケージや動作が異なる場合があります。以降は、`python3` で使われるPythonが目的のバージョンであることを前提とします。

既存の翻訳サーバーや他のWebアプリとの競合を避けるため、ポート7860が空いているか確認します。

```bash
lsof -nP -iTCP:7860 -sTCP:LISTEN
```

何も表示されなければ通常は未使用です。他のアプリが使用中の場合、**プロセスを特定せずに一括終了しないでください**。既存の `~/MyProject` に必要なデータがある場合も、削除せずバックアップしてください。

モデルの保存には**合計約28GBの重みファイル**のほか、ダウンロード用キャッシュ・Pythonライブラリ・実行時の空きメモリが必要です。重みの容量は必要なユニファイドメモリ容量を示すものではありません。

## 3. Python仮想環境の作成と有効化

```bash
mkdir -p ~/MyProject/bin ~/MyProject/lib
cd ~/MyProject

python3 -m venv plamo-mlx-env
source plamo-mlx-env/bin/activate
```

プロンプトに `(plamo-mlx-env)` が付けば通常は有効になっています。これ以降の `python`、`python -m pip` はこの仮想環境内で実行します。

```bash
python --version
python -m pip install -U pip
```

## 4. Hugging Face Hubのインストール

モデル配布元からファイルを取得するためのツールをインストールします。

```bash
python -m pip install huggingface_hub
hf --help
```

ここでは[README](../README.md)と同様に、`pip` の更新と `huggingface_hub` の導入を分けています。パッケージのバージョンはインストール時期によって変わる場合があります。

Hugging Faceへのログインは、公開モデルのダウンロードに必ずしも必要ではありません。未認証時に利用制限についての警告が表示されても、ダウンロード自体が完了する場合があります。**アクセストークンを文書・ソースコード・公開するファイルに書き込まないでください。**

## 5. PLaMo 3 Translateの4モデルをダウンロード

Preferred Networksの公式Hugging Faceリポジトリから、**MLX-4bit**版を取得します。以下のコマンドは各モデルを個別に取得します。必要に応じて実行順序を変更しても構いません。

### 5.1 31B

```bash
hf download pfnet/plamo-3-translate-31b-MLX-4bit --local-dir "$HOME/MyProject/lib/plamo-3-translate-31b-MLX-4bit"
```

モデルデータの容量の目安は約18.7GBです。

### 5.2 8B

```bash
hf download pfnet/plamo-3-translate-8b-MLX-4bit --local-dir "$HOME/MyProject/lib/plamo-3-translate-8b-MLX-4bit"
```

モデルデータの容量の目安は約6.07GBです。

### 5.3 2B

```bash
hf download pfnet/plamo-3-translate-2b-MLX-4bit --local-dir "$HOME/MyProject/lib/plamo-3-translate-2b-MLX-4bit"
```

モデルデータの容量の目安は約2.42GBです。

### 5.4 0.8B

```bash
hf download pfnet/plamo-3-translate-0.8b-MLX-4bit --local-dir "$HOME/MyProject/lib/plamo-3-translate-0.8b-MLX-4bit"
```

モデルデータの容量の目安は約981MBです。容量はモデルのリビジョン等により変わる可能性があります。

### 5.5 ダウンロード結果の確認

```bash
for size in 31b 8b 2b 0.8b; do
  if test -f "$HOME/MyProject/lib/plamo-3-translate-${size}-MLX-4bit/config.json"; then
    echo "OK: $size"
  else
    echo "MISSING: $size"
  fi
done
```

4件すべてが `OK` なら、最低限の配置を確認できます。ただし、**`config.json` の存在だけでは全重みファイルの整合性を保証しません**。次のモデルロード・翻訳テストで確認します。

ダウンロード中に `.gitignore.lock` の取得待ちや、未認証アクセスに関する警告が表示される場合があります。それだけで失敗とは限りません。最終的にダウンロードが完了したか確認し、失敗した場合は通信状況・空き容量を確認して同じ `hf download` コマンドを再実行してください。

## 6. MLX関連ライブラリのインストール

31Bモデルの配布フォルダ内にある `requirements-mlx.txt` に従ってインストールします。4モデルは共通の仮想環境を使用します。

```bash
python -m pip install -r "$HOME/MyProject/lib/plamo-3-translate-31b-MLX-4bit/requirements-mlx.txt"
```

このガイドでは[README](../README.md)と同じく、**31Bモデルの依存関係定義ファイルを使って共通環境を一度構築する方法**を示します。モデルのリビジョンや依存関係が変更された場合は、各モデルに含まれる `requirements-mlx.txt` を確認してください。

動作確認に使用した主なバージョン（参考）：

| パッケージ | バージョン |
|---|---|
| Python | 3.15 |
| `mlx` / `mlx-metal` | 0.32.4 |
| `mlx-lm` | 0.32.2 |
| `transformers` | 5.22.2 |
| `numba` | 0.68.1 |
| `numpy` | 2.5.4 |
| `huggingface_hub` | 2.4.0 |

これらは動作確認時のバージョンです。上記コマンドはバージョンを固定していないため、将来同じバージョンが導入されるとは限りません。

## 7. Gradio 6系のインストール

翻訳インターフェース用のGradioをインストールします。[README](../README.md)と同じく、**6系に限定**します。

```bash
python -m pip install 'gradio>=6,<7'
python -c 'import gradio, mlx_lm; print("Gradio:", gradio.__version__)'
```

動作確認時のバージョンは **Gradio 6.31.0** です。上記の指定ではGradio 7系を除外しますが、6系内部でも仕様変更が起こる場合があります。確認済みのバージョンに固定する場合は、`python -m pip install 'gradio==6.31.0'` を使用してください。

## 8. アプリケーションの取得と配置

GitHubの[リポジトリ](https://github.com/heavenlyjunk/plamo3-translate-macos)から実装ファイルを取得します。公開後はリポジトリの **Code → Download ZIP** を選択し、ZIPを展開してください。Gitを使える方は `git clone` でも取得できます。

`bin/` にある、次の3ファイルを `~/MyProject/bin/` にコピーします。

| リポジトリ内のファイル | 役割 |
|---|---|
| [`bin/translate_gui.py`](../bin/translate_gui.py) | Gradio画面、翻訳・終了処理 |
| [`bin/start_plamo.sh`](../bin/start_plamo.sh) | 起動、二重起動防止、ポート・ログ管理 |
| [`bin/plamo_stayopen_launcher.applescript`](../bin/plamo_stayopen_launcher.applescript) | 起動時のモデル選択とDock常駐 |

たとえば、Download ZIPで取得したフォルダを `~/Downloads/plamo3-translate-macos-main/` に展開した場合は、次のようにコピーできます。

```bash
cp "$HOME/Downloads/plamo3-translate-macos-main/bin/"* "$HOME/MyProject/bin/"
chmod 755 "$HOME/MyProject/bin/start_plamo.sh"
```

ダウンロード・展開先が異なる場合は、コピー元のパスを読み替えてください。**このリポジトリの `bin/` にあるファイルを正本（最新の実装ソース）として扱います**。過去の配布ZIPや別バージョンのスクリプトを混在させないでください。

配置後、PythonおよびShellの構文を検査します。

```bash
python -m py_compile ~/MyProject/bin/translate_gui.py
/bin/bash -n ~/MyProject/bin/start_plamo.sh
```

これらは構文検査であり、モデルの読み込みやmacOS上でのAppleScriptコンパイルまで保証するものではありません。

## 9. 4モデルの単体英訳テスト（任意）

本リポジトリで公開する実装スクリプトは前節の**3ファイル**です。単体テスト用の `test.py` は `bin/` に含まれていないため、必要に応じて本書末尾の「付録A：単体テスト用 `test.py`」に掲載したコードを `~/MyProject/test.py` として保存してください。

```bash
cd ~/MyProject
python test.py --model-size 31b
python test.py --model-size 8b
python test.py --model-size 2b
python test.py --model-size 0.8b
```

各コマンドが終了してから次を実行してください。テストの原文は「会議は来週の月曜日に変更されました。」です。

**動作確認時に得られた翻訳例：**

| モデル | 英訳結果 |
|---|---|
| 31B | `The meeting has been rescheduled for next Monday.` |
| 8B | `The meeting has been moved to next Monday.` |
| 2B | `The meeting has been rescheduled for next Monday.` |
| 0.8B | `The meeting has been moved to next Monday.` |

動作確認では4モデルすべてから英文が返されました。生成される訳文は実行環境やモデルの更新によって異なる場合があります。起動時に `[transformers] You are using a model of type 'plamo3' ...` という警告が表示されることがありますが、翻訳が正常に返るなら、この警告のみをもって失敗と判断する必要はありません。**このテストで全53言語・全翻訳ペアの品質が検証されるわけではありません。**

確認後、テスト用に新規作成した `~/MyProject/test.py` が不要なら削除して構いません。ただし、他のファイルを誤って削除しないようにしてください。

## 10. Gradio翻訳GUIの起動確認

たとえば31Bモデルを指定して起動します。

```bash
cd ~/MyProject
python bin/translate_gui.py --model-size 31b
```

読み込みが完了すると、次のようなメッセージが表示されます。

```text
Loading PLaMo 3 Translate 31B: .../MyProject/lib/plamo-3-translate-31b-MLX-4bit
Model loaded successfully.
* Running on local URL:  http://127.0.0.1:7860
```

ブラウザで `http://127.0.0.1:7860/` を開きます。日本語・英語の翻訳、その他の言語モード、参考文脈欄、訳文のコピー、終了ボタンの動作を順に確認してください。Gradioサーバーの起動と、各GUI機能が正常に動作することは別の確認項目です。

モデルサイズを変える場合は、**前のPythonプロセスを停止してから**次を実行します。

```bash
python bin/translate_gui.py --model-size 8b
# 停止後：
python bin/translate_gui.py --model-size 2b
# 停止後：
python bin/translate_gui.py --model-size 0.8b
```

使用できる `--model-size` は `0.8b`、`2b`、`8b`、`31b` です。翻訳画面の「終了（モデルを停止）」ボタン、またはターミナルで `Ctrl+C` により停止します。**ブラウザタブを閉じるだけではサーバーは停止しません。**

## 11. バックグラウンド起動スクリプトの確認

ターミナルから起動用Shellをテストします。最初に上記の手動起動サーバーを停止してください。

```bash
/bin/bash "$HOME/MyProject/bin/start_plamo.sh" 0.8b
```

このスクリプトは、モデル名の検証、設定ファイルの確認、PID管理、7860番ポートの競合チェック、ログ出力、起動後のブラウザ表示を行います。起動済みであれば同一モデルを重複ロードしない設計です。異なるモデルが稼働中の場合には、停止を促します。

ログは以下に保存されます。

```bash
tail -n 100 "$HOME/Library/Application Support/PLaMoTranslate/server.log"
```

**モデルの起動後にGUIの終了ボタンで停止し、プロセスが終了するか確認してください。**

## 12. AppleScript常駐アプリの作成と確認

Mac標準の**スクリプトエディタ（Script Editor）**を使います。

1. `~/MyProject/bin/plamo_stayopen_launcher.applescript` をスクリプトエディタで開き、コンパイルして構文エラーがないことを確認します。
2. 「ファイル」→「書き出す」で、形式を **「アプリケーション」** にします。
3. **「ハンドラの実行後に終了しない」（Stay open after run handler）**にチェックを入れます。
4. `PLaMo Translate.app` という名前で保存します。初回はデスクトップなどの確認しやすい場所が適しています。
5. アプリを起動し、**0.8B / 2B / 8B / 31B** のモデル選択ダイアログが表示されることを確認します。
6. 選択したモデルのロード完了後、ブラウザで `http://127.0.0.1:7860/` が開くことを確認します。
7. `PLaMo Translate.app`を`/Applications/`などに移動し、Dockに登録します。
8. Dockから再度アプリをクリックし、モデルが二重ロードされず既存画面を表示できることを確認します。
9. 翻訳画面の「終了（モデルを停止）」から終了した場合、AppleScriptアプリも終了するか確認します。
10. Dockのアプリの「終了」操作でモデルのPythonプロセスも終了するか確認します。
11. 再起動時にモデル選択ダイアログが再表示されることを確認します。

AppleScriptからの起動ログは次の場所です。

```bash
tail -n 100 "$HOME/Library/Application Support/PLaMoTranslate/dock_launcher.log"
```

Dockアイコンの起動中ドットを保持するには、アプリを書き出す際の「ハンドラの実行後に終了しない」が重要です。**モデルロードが終わるまでDockアイコンがバウンスし続けることは保証されません。** AppleScriptのコンパイルとDock連動は、各自のMacで確認してください。

## 13. 日常運用とトラブルシューティング

アプリからモデルを切り替える際には、現在のモデルをGUIの終了ボタンで停止し、アプリを再起動してモデルを選択します。タブを閉じるだけではモデルは停止しません。

| 症状 | 確認事項 |
|---|---|
| `config.json` が見つからない | ダウンロード先 `~/MyProject/lib/`、モデルディレクトリ名、取得の完了状況 |
| 起動時に `plamo3` の警告が出る | 警告単独では失敗と断定できません。モデルのロードと翻訳結果も確認します |
| 7860番ポートが使用中 | `lsof -nP -iTCP:7860 -sTCP:LISTEN` で使用元を調べます |
| AppleScriptからブラウザが開かない | `server.log` と `dock_launcher.log` を確認します |
| Dockで常駐しない | アプリ書き出し時に「ハンドラの実行後に終了しない」を有効にしたか確認します |
| モデルを選び直せない | 稼働中モデルを終了してからアプリを起動し直します |
| 起動に時間がかかる／停止する | ストレージ、ユニファイドメモリ、Pythonエラーをログで確認します |

`127.0.0.1` にバインドして `share=False` としているため、GradioのWeb画面は通常、同じMacからのみ利用する設定です。翻訳はダウンロード済みのローカルモデルで処理しますが、モデルやPythonパッケージの取得にはインターネット接続が必要です。`trust_remote_code=True` はモデル配布元のコードの実行を許可するため、信頼できる配布元かを確認してください。

## 14. 再現性の記録・ライセンス・参考資料

動作する環境が構築できたら、バージョンを記録します。

```bash
cd ~/MyProject
source plamo-mlx-env/bin/activate
python --version
python -m pip freeze > requirements-lock.txt
python -m pip check
deactivate
```

`requirements-lock.txt` はローカル環境の記録です。GitHubに載せる場合は、ローカルパス・私的なパッケージ配布元などが含まれていないことを確認してください。厳密な再現にはモデルの**ダウンロード時のリビジョン**も記録する必要があります。Pythonや依存ライブラリのアップデート後には、再度動作確認してください。

PLaMo 3 Translateモデルは**PLaMo Community License**で提供されています。本リポジトリにはモデル重みを同梱せず、利用者が公式配布元から取得します。自作のPython・Shell・AppleScriptのライセンスについては、モデルのライセンスと区別して確認してください。大学・研究・企業などでの利用に際しては、最新の公式ライセンス条件を参照してください。

参考リンク：

- [Preferred Networks：PLaMo 3 Translate 31B MLX-4bit](https://huggingface.co/pfnet/plamo-3-translate-31b-MLX-4bit)
- [8B MLX-4bit](https://huggingface.co/pfnet/plamo-3-translate-8b-MLX-4bit)
- [2B MLX-4bit](https://huggingface.co/pfnet/plamo-3-translate-2b-MLX-4bit)
- [0.8B MLX-4bit](https://huggingface.co/pfnet/plamo-3-translate-0.8b-MLX-4bit)
- [MLX](https://github.com/ml-explore/mlx) / [mlx-lm](https://github.com/ml-explore/mlx-lm)
- [Gradio公式ドキュメント](https://www.gradio.app/docs)
- [Hugging Face Hub CLI](https://huggingface.co/docs/huggingface_hub/guides/cli)

---

## 付録A：単体テスト用 `test.py`

以下はモデル単体の翻訳確認に使用できるコード例です。`~/MyProject/test.py` にUTF-8で保存します。**これは任意のテスト用コードで、現在のGitHubリポジトリの `bin/` に含める3つの公開スクリプトとは別です。**

```python
"""Minimal smoke test of one locally downloaded PLaMo Translate MLX model."""
import argparse
from pathlib import Path
from mlx_lm import generate, load
from mlx_lm.sample_utils import make_sampler

parser = argparse.ArgumentParser()
parser.add_argument("--model-size", default="0.8b", choices=("0.8b", "2b", "8b", "31b"))
args = parser.parse_args()
model_dir = Path.home() / "MyProject" / "lib" / f"plamo-3-translate-{args.model_size}-MLX-4bit"
if not (model_dir / "config.json").is_file():
    parser.error(f"モデルのconfig.jsonが見つかりません: {model_dir}")
print(f"Loading {args.model_size}...", flush=True)
model, tokenizer = load(str(model_dir), trust_remote_code=True, tokenizer_config={"trust_remote_code": True})
prompt = tokenizer.apply_chat_template(
    [{"role": "user", "content": "会議は来週の月曜日に変更されました。"}],
    source_lang="ja", target_lang="en", add_generation_prompt=True, tokenize=False,
)
print(generate(model, tokenizer, prompt, max_tokens=512, sampler=make_sampler(temp=0)))
```
