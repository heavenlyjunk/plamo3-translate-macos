"""PLaMo 3 Translate: 4 selectable MLX models, Gradio 6 GUI.
Install at ~/MyProject/bin/translate_gui.py
"""

import argparse
import os
from pathlib import Path
import signal
import threading

import gradio as gr
from mlx_lm import generate, load
from mlx_lm.sample_utils import make_sampler

PROJECT_DIR = Path.home() / "MyProject"
SERVER_HOST = "127.0.0.1"
SERVER_PORT = 7860
MODEL_CHOICES = ("0.8b", "2b", "8b", "31b")

LANGUAGES = [
    ("日本語", "ja"), ("英語", "en"),
    ("中国語（簡体字）", "zh-hans"), ("中国語（繁体字）", "zh-hant"),
    ("韓国語", "ko"), ("アラビア語", "ar"),
    ("アゼルバイジャン語", "az"), ("ベラルーシ語", "be"),
    ("ブルガリア語", "bg"), ("ベンガル語", "bn"),
    ("カタルーニャ語", "ca"), ("セブアノ語", "ceb"),
    ("ドイツ語", "de"), ("スペイン語", "es"),
    ("エストニア語", "et"), ("バスク語", "eu"),
    ("ペルシャ語", "fa"), ("フランス語", "fr"),
    ("グジャラート語", "gu"), ("ヘブライ語", "he"),
    ("ヒンディー語", "hi"), ("クロアチア語", "hr"),
    ("ハンガリー語", "hu"), ("アルメニア語", "hy"),
    ("インドネシア語", "id"), ("イタリア語", "it"),
    ("ジャワ語", "jv"), ("ジョージア語", "ka"),
    ("カザフ語", "kk"), ("クメール語", "km"),
    ("リトアニア語", "lt"), ("ラトビア語", "lv"),
    ("マラヤーラム語", "ml"), ("マラーティー語", "mr"),
    ("マレー語", "ms"), ("ミャンマー語", "my"),
    ("ネパール語", "ne"), ("オランダ語", "nl"),
    ("パンジャーブ語", "pa"), ("ポーランド語", "pl"),
    ("ロシア語", "ru"), ("シンハラ語", "si"),
    ("スロバキア語", "sk"), ("スロベニア語", "sl"),
    ("セルビア語", "sr"), ("スワヒリ語", "sw"),
    ("タミル語", "ta"), ("テルグ語", "te"),
    ("タイ語", "th"), ("タガログ語", "tl"),
    ("ウルドゥー語", "ur"), ("ウズベク語", "uz"),
    ("ベトナム語", "vi"),
]
assert len(LANGUAGES) == 53


def main():
    parser = argparse.ArgumentParser(description="PLaMo Translate GUI")
    parser.add_argument("--model-size", required=True, choices=MODEL_CHOICES)
    args = parser.parse_args()
    model_dir = PROJECT_DIR / "lib" / f"plamo-3-translate-{args.model_size}-MLX-4bit"
    if not (model_dir / "config.json").is_file():
        parser.error(f"モデルが見つかりません: {model_dir}")

    display_size = args.model_size.upper()
    print(f"Loading PLaMo 3 Translate {display_size}: {model_dir}", flush=True)
    model, tokenizer = load(
        str(model_dir),
        trust_remote_code=True,
        tokenizer_config={"trust_remote_code": True},
    )
    print("Model loaded successfully.", flush=True)

    def translate(text, mode, source_language, target_language, context):
        if not text or not text.strip():
            return ""

        if mode == "ja-en":
            source_lang, target_lang = "ja", "en"
        elif mode == "en-ja":
            source_lang, target_lang = "en", "ja"
        elif mode == "multi":
            source_lang, target_lang = source_language, target_language
        else:
            raise gr.Error("翻訳モードを選択してください。")
        if source_lang == target_lang:
            raise gr.Error("翻訳元と翻訳先には異なる言語を選択してください。")

        options = {
            "source_lang": source_lang,
            "target_lang": target_lang,
            "add_generation_prompt": True,
            "tokenize": False,
        }
        if context and context.strip():
            options["context"] = context.strip()

        try:
            prompt = tokenizer.apply_chat_template(
                [{"role": "user", "content": text}], **options
            )
            result = generate(
                model, tokenizer, prompt,
                max_tokens=2048,
                sampler=make_sampler(temp=0),
            )
        except Exception as exc:
            raise gr.Error(f"翻訳エラー: {exc}") from exc

        for stop_token in ("<|plamo:tag|>", "<|plamo:bos|>"):
            result = result.split(stop_token, 1)[0]
        return result.strip()

    def shutdown_app():
        def terminate():
            os.kill(os.getpid(), signal.SIGTERM)
        timer = threading.Timer(3.0, terminate)
        timer.daemon = True
        timer.start()
        return "モデルを停止しています。停止後はこのタブを閉じてください。"

    with gr.Blocks(title=f"PLaMo 3 Translate {display_size}") as demo:
        gr.Markdown(
            f"# PLaMo 3 Translate {display_size}\n"
            "ローカル MLX 翻訳アプリ（53言語対応）"
        )
        translation_mode = gr.Radio(
            choices=[
                ("日本語 → 英語", "ja-en"),
                ("英語 → 日本語", "en-ja"),
                ("その他の言語（53言語対応）", "multi"),
            ],
            value="ja-en",
            label="翻訳モード",
        )

        with gr.Column(visible=False) as multilingual_settings:
            with gr.Row():
                source_language = gr.Dropdown(
                    choices=LANGUAGES, value="ja", label="翻訳元", filterable=True
                )
                target_language = gr.Dropdown(
                    choices=LANGUAGES, value="id", label="翻訳先", filterable=True
                )
            gr.Markdown("※翻訳品質は言語ペアやモデルサイズによって異なります。")

        context = gr.Textbox(
            label="参考文脈（任意）",
            placeholder="例：地球科学分野の学術論文",
            lines=2,
        )
        with gr.Row():
            source = gr.Textbox(
                label="原文", lines=12,
                placeholder="翻訳する文章を入力してください",
            )
            translated = gr.Textbox(
                label="翻訳結果", lines=12, interactive=False, buttons=["copy"]
            )

        def update_translation_mode(selected_mode):
            return gr.update(visible=(selected_mode == "multi")), ""

        translation_mode.input(
            fn=update_translation_mode,
            inputs=translation_mode,
            outputs=[multilingual_settings, translated],
            queue=False,
            show_progress="hidden",
        )

        translate_btn = gr.Button("翻訳する", variant="primary")
        translate_btn.click(
            fn=translate,
            inputs=[source, translation_mode, source_language, target_language, context],
            outputs=translated,
        )

        gr.Markdown("---")
        stop_btn = gr.Button("終了（モデルを停止）", variant="stop")
        status = gr.Markdown()
        stop_btn.click(fn=shutdown_app, inputs=[], outputs=status, queue=False)

    demo.queue(default_concurrency_limit=1).launch(
        server_name=SERVER_HOST,
        server_port=SERVER_PORT,
        inbrowser=False,
        share=False,
        show_error=True,
        theme=gr.themes.Ocean(),
    )


if __name__ == "__main__":
    main()
