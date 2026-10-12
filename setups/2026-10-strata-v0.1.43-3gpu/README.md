# Setup: Strata v0.1.43 on 3x RTX 3090, October 2026

Qwen3.8-Flash-Next, OrcaRouter's uncensored IQ4_XS, on Strata v0.1.43 across three RTX 3090s. Images on with a 4096-token cap, two requests at once, 262K context, conversation parking on. The numbers are in the [main README](../../README.md) and the full set is in [BENCHMARKS.md](../../BENCHMARKS.md).

It is the [two-card v0.1.40.2 setup](https://github.com/ruashots/flashnext-2x3090/tree/main/setups/2026-10-strata-v0.1.40.2) on the newer engine, with two changes: the GPU list has the third card, and the layer split is left to Strata instead of set by hand.

## The box

| | |
| --- | --- |
| GPUs | 3x RTX 3090 24 GB (EVGA FTW3, Gigabyte Turbo, Alienware OEM), no NVLink, power capped at 225 W each |
| PCIe | The first two in the CPU slots, the third on a 60 cm riser in the chipset slot at Gen4 x4 (6.4 to 6.8 GB/s measured) |
| Power | The third card runs off a second power supply, started together with the first through an Add2PSU board |
| CPU | Ryzen 7 9800X3D |
| RAM | 128 GB DDR5 (4x 32 GB, two different kits) at 4800 with 1.25 V, the container gets 100 GB of it |
| Disk | NVMe |
| OS | Proxmox, the server runs in an Ubuntu 24.04 LXC container |
| Driver / CUDA | 595.71.05 / 13.0 |
| Engine | Strata v0.1.43 (`7695859a`), built from source for sm_86 |
| Model | [`orcarouter/Qwen3.8-Flash-Next-Uncensored-GGUF`](https://huggingface.co/orcarouter/Qwen3.8-Flash-Next-Uncensored-GGUF), IQ4_XS, plus its F16 `mmproj` for images |

The whole server config is [`strata-orca-0143-262k-img4096.json`](strata-orca-0143-262k-img4096.json). What the less obvious bits do:

- `"gpu": [0, 1, 2]` with `"layer_split": "auto"`: Strata measures each card and picks the split itself. On the 262K setup it put layers 0-13, 14-29 and 30-47 on the three cards. With three cards about 91% of the experts sit on the cards, against about 60% on two, and that's where the faster prompt processing comes from.
- `--trim-stage-weights`: each card only loads its own layers' weights, so more experts fit in VRAM.
- `--batch 2 --batch-groups 2`: two requests at once, pipelined through the cards.
- `--mmap-experts`: Strata maps the 61 GiB expert file instead of reading it all into locked RAM, so the OS file cache holds what the cards don't, and can give that memory back.
- `--kv-resident 20480`: the context's cache lives in RAM and only the part the attention reads stays on the cards, which leaves more VRAM for experts.
- `--conversation-cache-mib 8192 --conversation-cache-slots 8`: conversation parking, up to 8 conversations kept so coming back to one doesn't read it again.
- `"vision": {"max_tokens": 4096}`: how many tokens a picture can turn into. At 4096 a full-screen 2560x1440 screenshot with small text reads right, at 1024 and 2048 it didn't.
- `"sampling"`: clients that send no sampler get temperature 1.0, top_p 0.95, top_k 20, what the model card asks for. Without it Strata answers greedy, and a hard prompt could get stuck thinking in a loop.

On the 262K and 512K setups the extra RAM doesn't show, the busy experts are on the cards. At 1M it does: with the container capped at 58 GB, a varied 1M prompt processed at 751 tok/s because the model kept being read back from disk, and at 100 GB it processes at about 1,900 ([details](../../BENCHMARKS.md#retrieval)).

## Run the same thing

You need three 24 GB NVIDIA cards, about 64 GB of RAM (about 100 GB for the 1M setup), about 175 GB of free disk, an NVIDIA driver and the CUDA 13.0 toolkit at `/usr/local/cuda`, plus `git`, `build-essential` and `python3-venv`.

The model repo is gated. Before you start, accept its terms on [its Hugging Face page](https://huggingface.co/orcarouter/Qwen3.8-Flash-Next-Uncensored-GGUF) and have a Hugging Face token ready.

The paths below are the ones the configs and the service use. Mine runs as root inside its own container.

**1. Get Strata v0.1.43 and this repo**

```bash
mkdir -p /opt/strata && cd /opt/strata
git clone https://github.com/Niko1221/Strata.git
git clone https://github.com/ruashots/flashnext-3x3090.git
cd Strata && git checkout v0.1.43
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
```

**2. Compile the engine and the image encoder (10 to 20 minutes, once)**

```bash
.venv/bin/python ../flashnext-3x3090/setups/2026-10-strata-v0.1.43-3gpu/build_strata_engine.py .
```

Strata's own `./setup.sh` compiles it too, but it also wants to download a model from its menu, and this build is not in that menu. The script calls the same build function setup uses, for the cards it finds.

**3. Download the model (about 98 GB)**

```bash
python3 -m venv /opt/strata/hfvenv && /opt/strata/hfvenv/bin/pip install -U huggingface_hub
/opt/strata/hfvenv/bin/hf auth login
/opt/strata/hfvenv/bin/hf download orcarouter/Qwen3.8-Flash-Next-Uncensored-GGUF \
  --include "*IQ4_XS*" --include "mmproj-*F16.gguf" \
  --local-dir /opt/strata/models/orca-iq4xs
```

**4. Pack it for Strata**

```bash
.venv/bin/python tools/iq_pack.py \
  --gguf /opt/strata/models/orca-iq4xs/Qwen3.8-Flash-Next-Uncensored-IQ4_XS-00001-of-00003.gguf \
  --out packs/orca-iq4xs --compat-bf16 --experts-bin
```

`--compat-bf16` converts the few small weights Strata reads as BF16. `--experts-bin` writes the expert file that `--mmap-experts` needs. Strata's [OrcaRouter notes](https://github.com/Niko1221/Strata/blob/main/docs/ORCA.md) only validate IQ3_XXS. IQ4_XS is what I run and measured, it isn't something Strata lists as tested. My pack and the draft head in step 5 were made with v0.1.39's tools and carried over as they were.

**5. The draft head for speculative decoding**

```bash
.venv/bin/python tools/mtp_fetch.py fetch --out mtp
.venv/bin/python tools/mtp_pack.py --src mtp --experts q2_0 --out mtp/mtp-q2_0.gguf
.venv/bin/python tools/mtp_rt.py --gguf mtp/mtp-q2_0.gguf --out mtp/rt
cp data/draft_vocab.bin mtp/rt/draft_vocab.bin
```

**6. Configs and service**

```bash
cp ../flashnext-3x3090/setups/2026-10-strata-v0.1.43-3gpu/strata-orca-0143-*.json .
cp ../flashnext-3x3090/setups/2026-10-strata-v0.1.43-3gpu/strata-server.service /etc/systemd/system/
systemctl daemon-reload && systemctl enable --now strata-server
```

It takes about a minute and a half to load. Then `http://127.0.0.1:8080` has Strata's chat and monitor, and any OpenAI-compatible client works with `http://127.0.0.1:8080/v1`. To run it by hand instead, run `ulimit -l unlimited` first, then `.venv/bin/python -m serve.server --engine strata --config strata-orca-0143-262k-img4096.json`.

The published configs and service listen on 127.0.0.1. Mine listens on my LAN. If you open yours up, add `--api-key <secret>` to the service command.

## The long-context configs

All three stretch the model past its 262K with yarn and keep the image cap at 1024. They're for when the length is needed, not what runs day to day.

- [`strata-orca-0143-512k.json`](strata-orca-0143-512k.json): yarn x2, one request at a time.
- [`strata-orca-0143-512k-b2.json`](strata-orca-0143-512k-b2.json): the same with `--batch 2 --batch-groups 2`, two requests at once. It fits on three cards. It costs about 10% on single requests against the one-at-a-time version.
- [`strata-orca-0143-1m.json`](strata-orca-0143-1m.json): yarn x4, one request at a time. Stream the reply at this length.
