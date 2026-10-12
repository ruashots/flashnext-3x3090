# Benchmarks: Strata v0.1.43 on 3x RTX 3090

The same benchmark set I ran on two cards ([October 7](https://github.com/ruashots/flashnext-2x3090/blob/main/BENCHMARKS.md)), run again on October 12, 2026 after the third card went in: speed from a few hundred tokens up to 1M, one versus two requests at once, needle retrieval up to 1M, GSM8K and my 20-prompt set.

Everything was run on the same box and the same model files, four ways:

| Name | Config | What it is |
| --- | --- | --- |
| **262K** | [`strata-orca-0143-262k-img4096.json`](setups/2026-10-strata-v0.1.43-3gpu/strata-orca-0143-262k-img4096.json) | What I run every day. 262,144 context, two requests at once, images on |
| **512K** | [`strata-orca-0143-512k.json`](setups/2026-10-strata-v0.1.43-3gpu/strata-orca-0143-512k.json) | The model stretched x2 with yarn, one request at a time |
| **512K, two at once** | [`strata-orca-0143-512k-b2.json`](setups/2026-10-strata-v0.1.43-3gpu/strata-orca-0143-512k-b2.json) | The same, with two requests at once. New: on two cards I only ran 512K one at a time |
| **1M** | [`strata-orca-0143-1m.json`](setups/2026-10-strata-v0.1.43-3gpu/strata-orca-0143-1m.json) | The model stretched x4 with yarn, one request at a time |

Before the tables, what these numbers can and can't tell you:

- **Finding planted facts proves retrieval holds to 1M, not reasoning over 1M.** The needle tests ask the model to pull one fact back out of a long text. Passing them doesn't mean it can think across a whole million tokens.
- **The single runs past 128K are noisy.** Each length past 128K ran once, so one slow or fast run moves the number a lot.
- **The cards run at a 225 W power cap**, not at the stock limit.
- **The 512K and 1M setups stretch the model with yarn to get past 262K.** They're for when the length is needed, not for every day.
- **The server kept serving my agents during the runs.** Their requests landed in the middle of some measurements, so expect some noise in every row.

## Speed

One request at a time. Prompt processing and decode in tokens per second, as the client sees them. Up to 128K it's the median of 6 runs (3 code, 3 reasoning), past that a single run. The last column is the two-card run on October 7, same lengths, same scripts.

| Setup | Prompt (tokens) | Prompt processing (tok/s) | Decode (tok/s) | 2 cards: prompt processing / decode |
| --- | ---: | ---: | ---: | ---: |
| 262K | 140 | - | 139 | - / 110 |
| 262K | 4,222 | 1,317 | 127 | 989 / 112 |
| 262K | 16,522 | 2,173 | 127 | 1,842 / 112 |
| 262K | 32,922 | 2,745 | 121 | 2,165 / 103 |
| 262K | 65,722 | 3,319 | 113 | 2,487 / 100 |
| 262K | 131,323 | 3,620 | 115 | 2,564 / 93 |
| 262K | 205,119 | 3,662 | 118 | 2,314 / 76 |
| 262K | 251,246 | 3,637 | 104 | 2,567 / 107 |
| 512K | 142 | - | 136 | - / 108 |
| 512K | 4,220 | 1,230 | 123 | 773 / 109 |
| 512K | 307,618 | 3,553 | 101 | 2,510 / 84 |
| 512K | 410,119 | 3,431 | 102 | 2,469 / 107 |
| 512K | 512,617 | 3,309 | 94 | 2,380 / 100 |
| 512K, two at once | 141 | - | 121 | |
| 512K, two at once | 4,221 | 1,075 | 107 | |
| 512K, two at once | 512,619 | 3,042 | 88 | |
| 1M | 140 | - | 114 | - / 92 |
| 1M | 4,223 | 1,110 | 111 | 631 / 111 |
| 1M | 615,117 | 2,739 | 101 | 2,120 / 65 |
| 1M | 922,621 | 2,462 | 79 | 1,972 / 82 |
| 1M | 1,025,119 | 2,371 | 84 | 1,923 / 82 |

Processing a full 1M prompt takes about 7 minutes, against 9 on two cards. Processing 250K takes about 70 seconds, against a minute and a half.

## One versus two requests at once

Two requests sent at the same moment, 600 tokens each. Median of 3 runs, the 32K and 200K lines are one run each.

| Setup | Prompt each (tokens) | First token, request 1 / 2 | Decode, each | Both together | 2 cards, both together |
| --- | ---: | ---: | ---: | ---: | ---: |
| 262K | ~130 | 0.6 s / 1.3 s | 77 tok/s | 136 tok/s | 102 tok/s |
| 262K | ~4.2K | 3.3 s / 6.6 s | 67 tok/s | 84 tok/s | 74 tok/s |
| 262K | ~33K | 24.3 s / 12.0 s | 53 tok/s | 37 tok/s | 33 tok/s |
| 512K, two at once | ~130 | 2.2 s / 2.1 s | 51 tok/s | 90 tok/s | |
| 512K, two at once | ~4.2K | 4.0 s / 7.7 s | 55 tok/s | 71 tok/s | |
| 512K, two at once | ~33K | 29.5 s / 16.3 s | 44 tok/s | 31 tok/s | |
| 512K, two at once | ~205K | 120 s / 60 s | 33 tok/s | 9 tok/s | |

Two short chats together decode about as fast as one alone (136 against 139 tok/s), the gain is that neither waits for the other. On two cards it was 102 against 110. With long prompts it still gets worse, because Strata processes new prompts one after the other, and while it does, the other request barely decodes.

The 512K two-at-once setup works, two 205K prompts at once both finished, in 131 s. It costs about 10% on single requests against the one-at-a-time 512K (121 against 136 tok/s short, 88 against 94 at 512K), and two short chats together get 90 tok/s instead of 136 on the 262K setup. Worth it only if two long requests at once is the point.

**Four at once** (`scripts/probe.py burst`, the 262K setup): two 60K prompts, a short question and a screenshot, sent within a second. All four finished in 44 s and the screenshot was read right. This is the pattern that could hang forever on v0.1.41, fixed in the releases after it.

## Retrieval

**Needle:** Strata's own `tools/needle_bench.py`. One code word hidden in a long text made from Strata's docs and sources, at a set depth, and the model is asked for it.

| Setup | Length | 10% | 25% | 50% | 75% | 90% |
| --- | ---: | :-: | :-: | :-: | :-: | :-: |
| 262K | 4K to 256K, 7 lengths | found | found | found | found | found |
| 512K | 300K, 400K, 500K | found | | found | | found |
| 1M | 1M | found | | found | | found |
| 1M | 600K, 800K | | | found | | |

**Multi-key needle:** four key-and-number facts hidden in the same text, and the model is asked for one of them, so it has to pick the right one out of four look-alikes ([`scripts/needle_multikey.py`](scripts/needle_multikey.py)).

| Setup | Length | 10% | 50% | 90% |
| --- | ---: | :-: | :-: | :-: |
| 262K | 32K, 128K, 256K | found | found | found |
| 512K | 400K, 500K | | found | |
| 1M | 1M | | found | |

61 of 61 found, the same 61 as on two cards, and in none of the multi-key tests did it answer with one of the other three numbers. A 1M needle test takes about 7 minutes, against 9 on two cards.

**One thing the third card needed: more RAM for the container at 1M.** With the container capped at 58 GB, as it was on two cards, the first 1M needle prompt processed at 751 tok/s instead of about 1,900, because the OS had to read 237 GB of expert weights back from disk for it. The needle text is varied, so it uses many more experts than the plain filler of the speed test, and at 1M the expert file no longer fit in the file cache next to everything else. On two cards the same 58 GB cap was enough, and I did not measure what takes the extra room on three. With the cap raised to 100 GB the same prompt processed at 1,906 tok/s. The 1M rows above ran at 100 GB, the speed rows at 58 GB, and the slow row is kept in [`raw/strata-0143-3gpu-2026-10-12-needle-1m-at-58gb-cap.jsonl`](raw/strata-0143-3gpu-2026-10-12-needle-1m-at-58gb-cap.jsonl).

## Quality

| Test | 262K | 512K | 1M |
| --- | ---: | ---: | ---: |
| GSM8K, the full 1,319-problem test set | **1,270 / 1,319 = 96.3%** | first 250 only: 242 / 250 = 96.8% | first 250 only: 241 / 250 = 96.4% |
| My 20-prompt set, the 6 objectively graded prompts | 5 / 6 | 5 / 6 | 5 / 6 |

GSM8K is 0-shot, greedy, thinking off, scored on the exact final number ([`scripts/gsm8k.py`](scripts/gsm8k.py)). On two cards it was 1,271 of 1,319 (96.4%), so the same within one problem, as it should be: the model didn't change, only where it runs. The 512K and 1M runs only did the first 250 problems, so their scores aren't comparable to the full set. They show that stretching the model didn't break the short answers.

## Temperatures

GPU temperature, power and fan were logged every 10 s for the whole run on the host: [`raw/temps-strata-0143-3gpu-2026-10-12.csv`](raw/temps-strata-0143-3gpu-2026-10-12.csv) and, for the 1M part after the memory change, [`raw/temps-strata-0143-3gpu-2026-10-12-1m.csv`](raw/temps-strata-0143-3gpu-2026-10-12-1m.csv). Case closed, all three cards at their 225 W cap: the hottest reading was 69°C on the FTW, 65°C on the Gigabyte and 68°C on the Alienware, with fans at most at 63%. The only slowdown flags the cards raised were the power cap and idle, never heat.

## Method

- **Client side:** the scripts in [`scripts/`](scripts), talking to the server over its OpenAI-compatible API from another machine on the LAN. Times are measured by the client, so they include the network and the server's own overhead.
- **Speed:** [`scripts/bench.py`](scripts/bench.py). Every prompt starts with a random nonce so nothing comes from a cache. Two warm-up generations first. 512 tokens max, temperature 0.7, top_p 0.95. "Decode" is the rate after the first token.
- **Two at once:** `scripts/probe.py concurrent`. **Four at once:** `scripts/probe.py burst`.
- **Needles:** the haystack is built from a plain clone of Strata at `v0.1.40.2`, the same text as the two-card run, so the rows compare. Seeds are fixed, so the code words and numbers are the same every run. At 1M the needles went through [`scripts/needle_stream.py`](scripts/needle_stream.py), the same test with a streamed reply.
- **Versions:** Strata v0.1.43 (`7695859a`) built from source with CUDA 13.0 for sm_86, NVIDIA driver 595.71.05, OrcaRouter's uncensored IQ4_XS GGUF. The pack and the draft head are the ones from the two-card setup, carried over. Host and container details and all four configs as they ran are in [`raw/strata-0143-3gpu-2026-10-12-env.txt`](raw/strata-0143-3gpu-2026-10-12-env.txt).
- **The box:** 3x RTX 3090 24 GB (EVGA FTW3, Gigabyte Turbo, Alienware OEM), no NVLink, 225 W cap each. The third card sits on a riser in a PCIe Gen4 x4 slot behind the chipset. Ryzen 7 9800X3D, 128 GB DDR5 at 4800 (the server's container was capped at 58 GB, then 100 GB from the 1M needle rows on), NVMe, Proxmox.

## Run it yourself

With the server up on the 262K config, and `STRATA` pointing at a plain clone of Strata checked out at `v0.1.40.2` (only used to build the needle text):

```bash
URL=http://127.0.0.1:8080 STRATA=/path/to/Strata scripts/canonical_262k.sh
```

Then restart the server on the 512K config and run `scripts/canonical_long.sh 512k`, and on the 1M config run `scripts/canonical_long.sh 1m` and then `scripts/canonical_1m_rest.sh`, with the same `URL` and `STRATA`. Each script appends to `raw/$RUN-*.jsonl` (set `RUN=` to name your run, `OUT=` to write somewhere else). `python3 scripts/canonical_summary.py $RUN` rebuilds the tables.

Every command in the order it ran is in [`raw/strata-0143-3gpu-2026-10-12-commands.txt`](raw/strata-0143-3gpu-2026-10-12-commands.txt).
