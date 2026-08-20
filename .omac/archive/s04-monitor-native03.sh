#!/bin/bash
# S04 Native-03 监控快照: 根 issue runs + 状态 (证据写仓库外 tmp-collect)
cd /d/agentlearn/learnezvibe || exit 99
TS=$(date +%Y%m%d-%H%M%S)
NATIVE=01a01f0e-44d0-729a-9fad-14c9d0fa6e1c
OUT=/d/agentlearn/learnezvibe-b3-archive-20260820/tmp-collect/Native-03

timeout 90 multica issue get "$NATIVE" --output json > "$OUT/issue-${TS}.json" 2>/dev/null
timeout 90 multica issue runs "$NATIVE" --output json > "$OUT/runs-${TS}.json" 2>/dev/null

echo "=== $TS ==="
python - <<'EOF'
import json, glob, os
base = 'D:/agentlearn/learnezvibe-b3-archive-20260820/tmp-collect/Native-03'
def latest(prefix):
    files = sorted(glob.glob(os.path.join(base, prefix + '*.json')))
    return files[-1] if files else None
p = latest('issue-')
if p:
    d = json.load(open(p, encoding='utf-8'))
    print('root status:', d.get('status'), '| last_activity:', str(d.get('last_activity_at'))[:19])
p = latest('runs-')
if p:
    try:
        d = json.load(open(p, encoding='utf-8'))
        runs = d if isinstance(d, list) else d.get('runs', d.get('tasks', []))
        print(f'runs: {len(runs)}')
        for r in runs:
            u = r.get('usage') or []
            i = sum(x.get('input_tokens',0) for x in u); o = sum(x.get('output_tokens',0) for x in u)
            cr = sum(x.get('cache_read_tokens',0) for x in u); cw = sum(x.get('cache_write_tokens',0) for x in u)
            print(f'  {r.get("id","")[:8]} {str(r.get("status")):10s} msgs={r.get("message_count")} in={i} out={o} cr={cr} cw={cw} started={str(r.get("started_at"))[:19]} done={str(r.get("completed_at"))[:19]}')
    except Exception as e:
        print('runs parse err:', e)
EOF
