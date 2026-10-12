# What I run on my inference server

Qwen3.8-Flash-Next on three RTX 3090s. This page always shows the current setup. When it changes, the new one takes the top and the old one gets a chapter in [How we got here](#how-we-got-here).

The two-card story, from llama.cpp at 39 tok/s to Strata at 110, is in [flashnext-2x3090](https://github.com/ruashots/flashnext-2x3090). This repo picks up when the server got a third card and twice the RAM.

## Now: Strata v0.1.43 on 3x RTX 3090, since October 12, 2026

OrcaRouter's uncensored IQ4_XS build of Qwen3.8-Flash-Next, served by [Strata](https://github.com/Niko1221/Strata) on three RTX 3090s. Images on, two requests at once, 262K context.

It decodes at 105 to 140 tok/s and does prompt processing at about 3,600 tok/s on long prompts. A 250K prompt is processed in about 70 seconds.

| Prompt length | Decode (tok/s) | Prompt processing (tok/s) | First token |
| ------------- | -------------: | -----------------------: | ----------: |
| ~140 tokens   |            139 |                        - |       0.6 s |
| ~4.2K tokens  |            127 |                    1,317 |       3.2 s |
| ~66K tokens   |            113 |                    3,319 |      19.8 s |
| ~131K tokens  |            115 |                    3,620 |      36.3 s |

Median of 6 runs (3 code answers, 3 reasoning or questions about the text), 512 tokens max, temperature 0.7, top_p 0.95, a random nonce at the start of every prompt so nothing comes from a cache. Raw rows: [`raw/strata-0143-3gpu-2026-10-12-bench.jsonl`](raw/strata-0143-3gpu-2026-10-12-bench.jsonl), label `C262`.

The full set is in **[BENCHMARKS.md](BENCHMARKS.md)**, and the short version is right below.

The box: 3x RTX 3090 24 GB capped at 225 W, Ryzen 7 9800X3D, 128 GB DDR5, NVMe, Proxmox with the server in a container.

**The full recipe, configs and build steps: [`setups/2026-10-strata-v0.1.43-3gpu/`](setups/2026-10-strata-v0.1.43-3gpu/).**

## What the third card bought

Same model, same scripts, same 262K setup. The two-card numbers are from the [October 7 run](https://github.com/ruashots/flashnext-2x3090/blob/main/BENCHMARKS.md) on v0.1.40.2.

| Prompt (tokens) | Prompt processing, 2 cards | Prompt processing, 3 cards | Decode, 2 cards | Decode, 3 cards |
| ---: | ---: | ---: | ---: | ---: |
| ~140 | - | - | 110 | 139 |
| ~4.2K | 989 | 1,317 | 112 | 127 |
| ~33K | 2,165 | 2,745 | 103 | 121 |
| ~131K | 2,564 | 3,620 | 93 | 115 |
| ~205K | 2,314 | 3,662 | 76 | 118 |
| ~251K | 2,567 | 3,637 | 107 | 104 |

Prompt processing is about 30 to 60% faster, and decode is about 15 to 25% faster on most lengths. Two things changed between those runs, the card count and the engine (v0.1.40.2 to v0.1.43), so I ran a quick same-day test to split them ([`raw/strata-0141-3gpu-quick-2026-10-11.jsonl`](raw/strata-0141-3gpu-quick-2026-10-11.jsonl), code prompts, 3 runs each):

- **Prompt processing is the card.** On v0.1.41, adding the third card took a 32K prompt from 2,191 to 2,815 tok/s, and 2K from 638 to 1,056.
- **Decode, mostly not.** In the same test the third card alone moved decode within noise, except short prompts (106 to 130). So part of the decode gain against October 7 came from somewhere else, and I can't pin it on one thing.
- **v0.1.41 to v0.1.43** on three cards changed nothing past noise.

Why: Strata keeps the experts the model uses most on the cards and runs the rest on the CPU. Two cards held about 60% of the experts, three hold about 91%.

## Where things stand

From the [benchmark run](BENCHMARKS.md) on October 12:

- **Retrieval:** every planted fact found, from 4K up to 1M. That shows it finds things in a long text, not that it reasons over all of it.
- **GSM8K:** 1,270 of the 1,319 test problems, 96.3%, thinking off. Same as two cards (96.4%), as it should be: the model is the same, only where it runs changed.
- **Two short chats at once:** about 77 tok/s each, 136 tok/s together. On two cards it was 58 each and 102 together.
- **Four requests at once:** two 60K prompts, a short question and a screenshot, sent within a second. All four finished, in 44 s.
- **1M needs RAM:** with the container capped at 58 GB, a varied 1M prompt processed at 751 tok/s, because the model kept being read back from disk. At 100 GB it processes at about 1,900 ([details](BENCHMARKS.md#retrieval)).
- **Limits:** each run past 128K ran once, so those numbers are noisy. The cards are capped at 225 W, and the server kept serving my agents during the runs.

**The options**, same box, same model files, a config swap and a restart between them:

| Setup | What it gives | What it costs |
| --- | --- | --- |
| **262K**, every day | Two requests at once, images up to 4096 tokens, 139 tok/s short, 115 at 131K | Prompts top out at 262K |
| **512K** | A 500K prompt processed in about 2.5 min, then 94 tok/s decode | Stretched with yarn, one request at a time, smaller image cap |
| **512K, two at once** | Two requests at once up to 512K | About 10% slower than the one-at-a-time 512K, and two long prompts at once are slow (see [BENCHMARKS.md](BENCHMARKS.md#one-versus-two-requests-at-once)) |
| **1M** | A 1M prompt processed in about 7 min, then 84 tok/s decode | Stretched further, one request at a time, short answers slower (114 tok/s), stream the reply at this length |

The configs are in [`setups/2026-10-strata-v0.1.43-3gpu/`](setups/2026-10-strata-v0.1.43-3gpu/).

**Run the same setup.** You need three 24 GB NVIDIA cards, about 64 GB of RAM (about 100 GB for the 1M setup), about 175 GB of disk, the CUDA 13.0 toolkit at `/usr/local/cuda`, `git`, `build-essential` and `python3-venv`. The model is gated: accept its terms on [Hugging Face](https://huggingface.co/orcarouter/Qwen3.8-Flash-Next-Uncensored-GGUF) first. As root:

```bash
mkdir -p /opt/strata && cd /opt/strata
git clone https://github.com/Niko1221/Strata.git && git clone https://github.com/ruashots/flashnext-3x3090.git
S=/opt/strata/flashnext-3x3090/setups/2026-10-strata-v0.1.43-3gpu
cd Strata && git checkout v0.1.43
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/python $S/build_strata_engine.py .                      # engine + image encoder, 10-20 min

python3 -m venv ../hfvenv && ../hfvenv/bin/pip install -U huggingface_hub && ../hfvenv/bin/hf auth login
../hfvenv/bin/hf download orcarouter/Qwen3.8-Flash-Next-Uncensored-GGUF \
  --include "*IQ4_XS*" --include "mmproj-*F16.gguf" --local-dir /opt/strata/models/orca-iq4xs   # ~98 GB

.venv/bin/python tools/iq_pack.py --compat-bf16 --experts-bin --out packs/orca-iq4xs \
  --gguf /opt/strata/models/orca-iq4xs/Qwen3.8-Flash-Next-Uncensored-IQ4_XS-00001-of-00003.gguf
.venv/bin/python tools/mtp_fetch.py fetch --out mtp                  # the MTP head
.venv/bin/python tools/mtp_pack.py --src mtp --experts q2_0 --out mtp/mtp-q2_0.gguf
.venv/bin/python tools/mtp_rt.py --gguf mtp/mtp-q2_0.gguf --out mtp/rt && cp data/draft_vocab.bin mtp/rt/

cp $S/strata-orca-0143-*.json . && cp $S/strata-server.service /etc/systemd/system/
systemctl daemon-reload && systemctl enable --now strata-server     # starts the 262K setup
```

That starts the 262K setup on `http://127.0.0.1:8080` (OpenAI-compatible at `/v1`) in about a minute and a half. For the others, change `--config` in the service file to `strata-orca-0143-512k.json`, `strata-orca-0143-512k-b2.json` or `strata-orca-0143-1m.json` and restart it. Every step explained is in the [setup folder](setups/2026-10-strata-v0.1.43-3gpu/), and the benchmark commands are in [BENCHMARKS.md](BENCHMARKS.md#run-it-yourself).

## How we got here

### August to October 2026: two cards

llama.cpp at about 39 tok/s, then EXL3 at 69 to 90, DominikBucko's vLLM fork at 57 to 78, then Strata at 93 to 120. The whole story, every setup and every raw number is in [flashnext-2x3090](https://github.com/ruashots/flashnext-2x3090).

### October 2026: 128 GB of RAM and a third 3090

Two upgrades a few days apart. First the RAM, from 64 to 128 GB, four 32 GB sticks from two different kits. Those didn't hold their rated 5200, and 4800 at stock voltage still threw errors in a memory test, so it runs at 4800 with the RAM voltage at 1.25 V, which passed clean. On Strata the RAM alone changed nothing, the busy experts were already on the cards.

Then the third card: an Alienware OEM 3090 on a 60 cm riser, on its own power supply, in the board's third slot. That slot runs at PCIe Gen4 x4 through the chipset, and it measured 6.4 to 6.8 GB/s under load, close to what the slot can do. Strata's automatic split put layers 0-13, 14-29 and 30-47 on the three cards, the Strata update to v0.1.43 came the same week, and that's the setup at the top.

## Credits

Qwen3.8-Flash-Next is by the Qwen team, and the uncensored GGUF is [OrcaRouter's](https://huggingface.co/orcarouter/Qwen3.8-Flash-Next-Uncensored-GGUF).

Strata is by [Niko1221](https://github.com/Niko1221), and it's the reason this box runs the way it does. Strata is free. If it runs well for you too, [a coffee](https://buymeacoffee.com/strataengine) keeps the work on it going.

## What's in the repo

| Path | What it is |
| --- | --- |
| [`setups/`](setups) | One folder per setup: configs, service and the steps to build it. The newest is what runs now |
| [`BENCHMARKS.md`](BENCHMARKS.md) | The full benchmark set for the current setup: speed to 1M, two at once, retrieval, GSM8K, method and limits |
| [`scripts/bench.py`](scripts/bench.py) | Speed: nonce per prompt, warm-up first, decode and prompt processing separately |
| [`scripts/quality.py`](scripts/quality.py), [`scripts/autograde.py`](scripts/autograde.py) | The fixed 20-prompt set and the grader for its 6 objective items |
| [`scripts/probe.py`](scripts/probe.py) | Images, two requests at once, four at once (`burst`), coming back to a conversation |
| [`scripts/canonical_262k.sh`](scripts/canonical_262k.sh), [`canonical_long.sh`](scripts/canonical_long.sh), [`canonical_1m_rest.sh`](scripts/canonical_1m_rest.sh) | The benchmark set in BENCHMARKS.md, with [`gsm8k.py`](scripts/gsm8k.py), [`needle_multikey.py`](scripts/needle_multikey.py), [`needle_stream.py`](scripts/needle_stream.py) and [`canonical_summary.py`](scripts/canonical_summary.py) for the tables |
| [`raw/`](raw) | Every result row and log behind the numbers |
