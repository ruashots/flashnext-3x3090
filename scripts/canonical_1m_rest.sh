#!/bin/bash
# The 1M setup's needle and short-task checks, streamed (see needle_stream.py for why).
RUN=${RUN:-strata-0143-3gpu-2026-10-12}; S=$(cd "$(dirname "$0")" && pwd); R=${OUT:-$S/../raw}; T=$(mktemp -d); M=${MODEL:-Qwen3.8-Flash-Next-OrcaRouter}; U=${URL:-http://127.0.0.1:8080}
STRATA=${STRATA:?set STRATA to a plain clone of Strata at v0.1.40.2}; N=$R/$RUN-needle.jsonl
echo "== needle"; python3 $S/needle_stream.py --strata $STRATA --url $U --lengths 1000k --depths 10,50,90 --label C1M --out $N | cut -c1-200
python3 $S/needle_stream.py --strata $STRATA --url $U --lengths 600k,800k --depths 50 --label C1M --out $N | cut -c1-200
echo "== multikey"; python3 $S/needle_multikey.py --strata $STRATA --url $U --lengths 1000k --depths 50 --label C1M --stream --out $N | cut -c1-250
echo "== quality"; python3 $S/quality.py --url $U/v1 --model $M --label C1M --out $R/$RUN-quality.jsonl | tail -1
echo "== gsm8k first 250"; python3 $S/gsm8k.py --url $U/v1 --model $M --label C1M --out $R/$RUN-gsm8k.jsonl --limit 250 | tail -1
echo REST-DONE
