# PLaMo 3 Translate for macOS

**Apple Silicon Mac向け・PLaMo 3 Translate ローカル翻訳アプリ**

A local multilingual translation application for Apple Silicon Macs, powered by Preferred Networks' PLaMo 3 Translate models, MLX, and Gradio.

## 概要

Preferred Networksが公開する翻訳特化型大規模言語モデル「PLaMo 3 Translate」を、Apple Silicon搭載Mac上でローカルに実行するためのGUIアプリケーションです。

Python、MLX、Gradio、AppleScriptを組み合わせ、Webブラウザ上の翻訳インターフェースをmacOSのDockから簡単に起動できるようにしています。

PLaMo 3 Translateの4種類のモデル（0.8B / 2B / 8B / 31B）に対応しており、アプリ起動時に使用するモデルを選択できます。

本プロジェクトは個人による非公式の実装であり、Preferred Networksの公式アプリケーションではありません。

## 主な機能

- 0.8B、2B、8B、31Bの4モデルに対応（MLX-4bit）
- アプリ起動時にモデルを選択
- 53言語の翻訳に対応
- 日本語→英語、英語→日本語、その他の言語の翻訳モード
- 翻訳元と翻訳先の言語を選択可能
- 参考文脈を指定した翻訳
- 原文と翻訳結果を左右に表示
- 翻訳結果のクリップボードへのコピー
- GradioによるブラウザベースのGUI
- AppleScriptによるDock常駐型アプリ
- Dockからの翻訳画面の再表示
- 翻訳画面からのモデル終了・アプリ終了

## 対応環境

- Apple Silicon搭載Mac
- macOS
- Python 3
- MLX / mlx-lm
- Gradio 6
- AppleScript（macOS標準のスクリプトエディタ）

開発時の動作確認環境：

| 項目 | バージョン |
|---|---|
| Python | 3.15 |
| MLX | 0.32.4 |
| mlx-lm | 0.32.2 |
| Transformers | 5.22.2 |
| Gradio | 6.31.0 |
| モデル形式 | MLX-4bit |

上記は構築時に確認した環境であり、その他のバージョンでの動作を保証するものではありません。

## 対応モデル

Preferred NetworksがHugging Faceで公開している以下のモデルを使用します。

| モデル | MLX-4bit重み容量の目安 |
|---|---:|
| PLaMo 3 Translate 0.8B | 約0.98 GB |
| PLaMo 3 Translate 2B | 約2.42 GB |
| PLaMo 3 Translate 8B | 約6.07 GB |
| PLaMo 3 Translate 31B | 約18.7 GB |

すべてのモデルが53言語に対応しています。ただし、翻訳品質や処理速度はモデルによって異なります。

モデル本体は本リポジトリに含めません。公式のHugging Faceリポジトリから別途取得してください。

公式モデル一覧：

https://huggingface.co/collections/pfnet/plamo-3-translate

## インストール概要

### 1. Python仮想環境の作成とアクティベート

```bash
mkdir -p ~/MyProject/bin ~/MyProject/lib
cd ~/MyProject

python3 -m venv plamo-mlx-env
source plamo-mlx-env/bin/activate

pip install -U pip huggingface_hub
```

### 2. 仮想環境内でのhuggingface_hubのインストール

```bash
pip install -U pip huggingface_hub
```

### 3. 仮想環境内でのモデルのダウンロード

```bash
hf download pfnet/plamo-3-translate-31b-MLX-4bit --local-dir "$HOME/MyProject/lib/plamo-3-translate-31b-MLX-4bit"
hf download pfnet/plamo-3-translate-8b-MLX-4bit --local-dir "$HOME/MyProject/lib/plamo-3-translate-8b-MLX-4bit"
hf download pfnet/plamo-3-translate-2b-MLX-4bit --local-dir "$HOME/MyProject/lib/plamo-3-translate-2b-MLX-4bit"
hf download pfnet/plamo-3-translate-0.8b-MLX-4bit --local-dir "$HOME/MyProject/lib/plamo-3-translate-0.8b-MLX-4bit"
```

### 4. 仮想環境内でのモデルに必要なライブラリのインストール

```bash
pip install -U -r "$HOME/MyProject/lib/plamo-3-translate-31b-MLX-4bit/requirements-mlx.txt"
```

### 5. 仮想環境内でのGradioのインストール

```bash
pip install gradio
```

### 6. アプリケーションの配置

本リポジトリの `bin/` に収録するPython、Shell、AppleScriptファイルを `~/MyProject/bin/` に配置します。

### 7. 翻訳GUIの起動

例えば31Bモデルを使用する場合：

```bash
python bin/translate_gui.py --model-size 31b
```

起動後、Webブラウザから次のURLにアクセスします。

http://127.0.0.1:7860/

### 8. 仮想環境のディアクティベート

```bash
deactivate
```

AppleScriptをmacOSアプリケーションとして書き出すことで、Dockからモデルを選択して起動することもできます。

詳細なインストール手順とAppleScriptアプリの作成方法は、別途公開する構築ガイドを参照してください。

## セキュリティとプライバシー

翻訳処理にはローカルにダウンロードしたモデルを使用します。

Gradioのサーバーは `127.0.0.1` にバインドし、外部公開しない設定です。

モデルの読み込みには `trust_remote_code=True` を使用するため、モデル配布元のコードと利用条件を確認してください。

## ライセンスと謝辞

PLaMo 3 TranslateはPreferred Networksが開発した翻訳モデルです。モデル本体は **PLaMo Community License** に基づいて公開されています。

モデルの利用に際しては、公式のライセンス条件を確認してください。

本リポジトリに掲載する自作スクリプトのライセンスは、モデルのライセンスとは別途定める予定です。

### 関連プロジェクト

- [PLaMo 3 Translate — Preferred Networks](https://huggingface.co/collections/pfnet/plamo-3-translate)
- [MLX — Apple](https://github.com/ml-explore/mlx)
- [mlx-lm](https://github.com/ml-explore/mlx-lm)
- [Gradio](https://www.gradio.app/)

## 開発状況

4種類のモデルについて、ローカルでのモデル読み込み、基本的な翻訳、およびGradioサーバーの起動を確認しています。

公開用スクリプトと詳細な構築ガイドは順次整備します。
