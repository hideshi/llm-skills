---
name: hardware-compatibility-checker
description: Evaluates VRAM, RAM, compute capabilities, quantization types (GGUF, AWQ, EXL2), and runtime inference engines (vLLM, Ollama, llama.cpp) for candidate models.
---

# Hardware Compatibility Checker

このスキルは、候補モデルが指定されたハードウェア環境（VRAM容量、GPU世代、CPU/RAM）で実際に動作するかを計算・検証し、最適な推論ランタイムと量子化形式を判定します。

## 主な計算項目・検証基準

1. **モデル重みのメモリ所要量 ($M_{weights}$)**
   - 計算式:
     $$M_{weights} \approx \text{パラメータ数 (B)} \times \frac{\text{bits}}{8} \times 1.2 \quad (\text{GB})$$
     *(※ 約20%のCUDA/ランタイムオーバーヘッドを含む)*
   - 量子化ビット数の目安:
     - FP16 / BF16: 16 bits (約 2.0 GB / 1B)
     - Q8_0 / AWQ-8bit: 8 bits (約 1.1 GB / 1B)
     - Q4_K_M / AWQ-4bit / EXL2-4bpw: 4.5 bits (約 0.65 GB / 1B)
     - IQ3_M / 3-bit: 3.5 bits (約 0.5 GB / 1B)

2. **KVキャッシュのメモリ所要量 ($M_{kv}$)**
   - 特にコンテキスト長が 16k, 32k, 128k と長くなる場合に重要。
   - GQA (Grouped-Query Attention) の採用有無によってKVキャッシュ消費は劇的に変わる（Llama 3, Qwen 2.5等はGQA採用で大幅に省メモリ）。
   - 計算目安 (FP16 KVキャッシュの場合):
     $$M_{kv} \approx 2 \times \text{layers} \times \text{kv\_heads} \times \text{head\_dim} \times \text{context\_len} \times 2 \text{ bytes}$$

3. **総合所要メモリ判定**
   $$M_{total} = M_{weights} + M_{kv} + \text{Context Activation}$$
   - **判定ステータス**:
     - `GPU Full Offload (推奨)`: $M_{total} \le \text{利用可能VRAM} \times 0.9$
     - `Partial Offload (低速化・注意)`: 重みの一部またはKVキャッシュをRAMへオフロード（llama.cpp等で可能）
     - `OOM (実行不可)`: メモリ上限超過

4. **推論ランタイム & 最適フォーマット推奨**
   - **Ollama**: 手軽さ・CLI/API統合重視（フォーマット: GGUF）
   - **vLLM / SGLang**: 複数人アクセス・高スループットAPIサーバー（フォーマット: AWQ, GPTQ, FP8, BF16）
   - **llama.cpp**: CPU環境、GPU+CPU混在環境、最少量子化（フォーマット: GGUF）
   - **Aphrodite / ExLlamaV2**: 単一GPUでの超高速ローカル推論（フォーマット: EXL2）
