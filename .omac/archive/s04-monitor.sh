#!/bin/bash
# S04 第二组监控快照 v2: Native 根 issue runs + OMAC 节点 runs (从 manifest 读 work_item_id)
cd /d/agentlearn/learnezvibe || exit 99
TS=$(date +%H%M%S)
NATIVE=01a01edc-cc80-7de4-b669-fb2f9f9cd489
OMAC=01a01edc-e339-70b6-a02f-68766549945f
MANIFEST=.omac/s04-omac-02.yaml

timeout 90 multica issue runs "$NATIVE" --output json > Evidence/B3/samples/Native-02/runs.json 2>/dev/null
cp .omac/s04-omac-02.log Evidence/B3/samples/OMAC-02/driver.log 2>/dev/null

# OMAC: 从 manifest 读每个节点的 work_item_id, 逐个拉 runs
python - <<'EOF' > /tmp/omac-node-ids.txt
import re
s = open('.omac/s04-omac-02.yaml', encoding='utf-8').read()
for m in re.finditer(r'- id: (\w+)\n(?:.*?\n)*?  work_item_id: ([0-9a-f-]+|null)\n  status: (\w+)', s):
    print(m.group(1), m.group(3), m.group(2))
EOF
while read -r node status wid; do
  if [ "$wid" != "null" ] && [ -n "$wid" ]; then
    timeout 90 multica issue runs "$wid" --output json > "Evidence/B3/samples/OMAC-02/${node}-runs.json" 2>/dev/null
  fi
done < /tmp/omac-node-ids.txt

echo "=== $TS ==="
python - <<'EOF'
import json
def load(p):
    try:
        d = json.load(open(p, encoding='utf-8'))
        return d if isinstance(d, list) else d.get('runs', d.get('tasks', []))
    except Exception:
        return []
def dump(name, p):
    runs = load(p)
    print(f'--- {name}: {len(runs)} runs ---')
    for r in runs:
        u = r.get('usage') or []
        i = sum(x.get('input_tokens',0) for x in u); o = sum(x.get('output_tokens',0) for x in u)
        cr = sum(x.get('cache_read_tokens',0) for x in u); cw = sum(x.get('cache_write_tokens',0) for x in u)
        print(f'  {r.get("id","")[:8]} {r.get("status"):10s} msgs={r.get("message_count")} in={i} out={o} cr={cr} cw={cw} started={str(r.get("started_at"))[:19]} done={str(r.get("completed_at"))[:19]}')
dump('Native-02', 'Evidence/B3/samples/Native-02/runs.json')
for node in ['collect', 'write', 'review']:
    dump(f'OMAC-02 {node}', f'Evidence/B3/samples/OMAC-02/{node}-runs.json')
EOF
echo "--- OMAC driver tail ---"
tail -4 .omac/s04-omac-02.log
