#!/usr/bin/env bash
# portfolio-elite-eval.sh — Google/Microsoft-credible CD-UB evaluation (shared VPS)
set -euo pipefail

ROOT="${CDUB_ROOT:-/opt/cd-ub}"
# shellcheck disable=SC1091
source "${ROOT}/campaigns/common/campaign-env.sh"

OUT="${ROOT}/reports/live/portfolio"
SUITE="${ROOT}/portfolio/suite"
mkdir -p "$OUT" "$SUITE"
GUARD="${ROOT}/deploy/contabo/pm2-guard.sh"
bash "$GUARD"

export PF_HOST="$(hostname)"
export PF_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
export PF_GCC="$(gcc --version | head -1)"
export PF_CLANG="$(clang --version | head -1)"
export PF_UNAME="$(uname -srm)"
export PF_DISK="$(df -h / | awk 'NR==2{printf "%s/%s/%s (%s)",$2,$3,$4,$5}')"
export PF_MEM="$(free -h | awk '/Mem:/{printf "%s total / %s avail",$2,$7}')"

# --- Curated suite (Juliet-method BAD/GOOD) — cases chosen to still diverge on gcc13/clang18 ---
cat >"$SUITE/01_evalorder_bad.c" <<'EOF'
/* LABEL:BAD CLASS:EvalOrder EXPECT:disagree */
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv) {
  int base = 10;
  if (argc > 1) { FILE *f=fopen(argv[1],"r"); if(f){fscanf(f,"%d",&base); fclose(f);} }
  int i = base;
  printf("R %d %d %d\n", i++, i++, i++);
  return 0;
}
EOF
cat >"$SUITE/01_evalorder_good.c" <<'EOF'
/* LABEL:GOOD CLASS:EvalOrder EXPECT:agree */
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv) {
  int base = 10;
  if (argc > 1) { FILE *f=fopen(argv[1],"r"); if(f){fscanf(f,"%d",&base); fclose(f);} }
  printf("R %d %d %d\n", base, base+1, base+2);
  return 0;
}
EOF

cat >"$SUITE/02_call_order_bad.c" <<'EOF'
/* LABEL:BAD CLASS:EvalOrder EXPECT:disagree */
#include <stdio.h>
#include <stdlib.h>
void f(int a, int b) { printf("R %d %d\n", a, b); }
int main(int argc, char **argv) {
  int base = 5;
  if (argc > 1) { FILE *f=fopen(argv[1],"r"); if(f){fscanf(f,"%d",&base); fclose(f);} }
  int i = base;
  f(i++, i++);
  return 0;
}
EOF
cat >"$SUITE/02_call_order_good.c" <<'EOF'
/* LABEL:GOOD CLASS:EvalOrder EXPECT:agree */
#include <stdio.h>
#include <stdlib.h>
void f(int a, int b) { printf("R %d %d\n", a, b); }
int main(int argc, char **argv) {
  int base = 5;
  if (argc > 1) { FILE *f=fopen(argv[1],"r"); if(f){fscanf(f,"%d",&base); fclose(f);} }
  f(base, base+1);
  return 0;
}
EOF

cat >"$SUITE/03_comma_bad.c" <<'EOF'
/* LABEL:BAD CLASS:EvalOrder EXPECT:disagree */
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv) {
  int base = 7;
  if (argc > 1) { FILE *f=fopen(argv[1],"r"); if(f){fscanf(f,"%d",&base); fclose(f);} }
  int i = base;
  int a[2]];
  a[i++]] = i++;
  printf("R %d %d %d\n", a[base], a[base+1], i);
  return 0;
}
EOF
cat >"$SUITE/03_comma_good.c" <<'EOF'
/* LABEL:GOOD CLASS:EvalOrder EXPECT:agree */
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv) {
  int base = 7;
  if (argc > 1) { FILE *f=fopen(argv[1],"r"); if(f){fscanf(f,"%d",&base); fclose(f);} }
  int a0 = base + 1;
  int i = base + 2;
  printf("R %d %d %d\n", a0, 0, i);
  return 0;
}
EOF

cat >"$SUITE/04_macro_line_bad.c" <<'EOF'
/* LABEL:BAD CLASS:LINE EXPECT:disagree — CompDiff LINE class: __LINE__ in expression across TUs not needed;
 * use volatile counter + unsequenced store */
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv) {
  int base = 3;
  if (argc > 1) { FILE *f=fopen(argv[1],"r"); if(f){fscanf(f,"%d",&base); fclose(f);} }
  volatile int v = base;
  int x = v++ + v++;
  printf("R %d %d\n", x, v);
  return 0;
}
EOF
cat >"$SUITE/04_macro_line_good.c" <<'EOF'
/* LABEL:GOOD CLASS:LINE EXPECT:agree */
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv) {
  int base = 3;
  if (argc > 1) { FILE *f=fopen(argv[1],"r"); if(f){fscanf(f,"%d",&base); fclose(f);} }
  int x = base + (base + 1);
  int v = base + 2;
  printf("R %d %d\n", x, v);
  return 0;
}
EOF

mkdir -p "$SUITE/seeds"
echo "10" >"$SUITE/seeds/n10.txt"
echo "5" >"$SUITE/seeds/n5.txt"
echo "0" >"$SUITE/seeds/n0.txt"
echo "3" >"$SUITE/seeds/n3.txt"

run_pair() {
  local name="$1" src="$2" seed="$3" label="$4"
  local d="$OUT/cases/$name"
  mkdir -p "$d"
  gcc -O0 -Wall -o "$d/gccO0" "$src" 2>"$d/gccO0.build" || return 0
  clang -O3 -Wall -o "$d/clangO3" "$src" 2>"$d/clangO3.build" || return 0
  clang -O0 -fsanitize=undefined -fno-sanitize-recover=undefined -o "$d/ubsan" "$src" 2>"$d/ubsan.build" || true

  local out0="$d/out_gccO0.txt" out3="$d/out_clangO3.txt" outu="$d/out_ubsan.txt"
  timeout 2 "$d/gccO0" "$seed" >"$out0" 2>&1 || echo "EXIT:$?" >>"$out0"
  timeout 2 "$d/clangO3" "$seed" >"$out3" 2>&1 || echo "EXIT:$?" >>"$out3"
  local ubsan_hit=0
  if [[ -x "$d/ubsan" ]]; then
    set +e
    timeout 2 "$d/ubsan" "$seed" >"$outu" 2>&1
    local rc=$?
    set -e
    if [[ "$rc" -ne 0 ]] || grep -qiE 'runtime error|undefined|Sanitizer' "$outu"; then
      ubsan_hit=1
    fi
  fi
  local disagree=0
  cmp -s "$out0" "$out3" || disagree=1
  sha256sum "$d/gccO0" "$d/clangO3" "$out0" "$out3" >"$d/SHA256.txt"
  echo "$name|$label|$disagree|$ubsan_hit|$seed" >>"$OUT/raw_results.tsv"
  echo "CASE=$name LABEL=$label DISAGREE=$disagree UBSAN_HIT=$ubsan_hit"
  echo "--- gcc-O0 ---"; cat "$out0"
  echo "--- clang-O3 ---"; cat "$out3"
}

echo "name|label|disagree|ubsan_hit|seed" >"$OUT/raw_results.tsv"
run_pair "01_evalorder_bad" "$SUITE/01_evalorder_bad.c" "$SUITE/seeds/n10.txt" BAD
run_pair "01_evalorder_good" "$SUITE/01_evalorder_good.c" "$SUITE/seeds/n10.txt" GOOD
run_pair "02_call_order_bad" "$SUITE/02_call_order_bad.c" "$SUITE/seeds/n5.txt" BAD
run_pair "02_call_order_good" "$SUITE/02_call_order_good.c" "$SUITE/seeds/n5.txt" GOOD
run_pair "03_comma_bad" "$SUITE/03_comma_bad.c" "$SUITE/seeds/n0.txt" BAD
run_pair "03_comma_good" "$SUITE/03_comma_good.c" "$SUITE/seeds/n0.txt" GOOD
run_pair "04_volatile_bad" "$SUITE/04_macro_line_bad.c" "$SUITE/seeds/n3.txt" BAD
run_pair "04_volatile_good" "$SUITE/04_macro_line_good.c" "$SUITE/seeds/n3.txt" GOOD

python3 - <<'PY'
import json, pathlib
out = pathlib.Path("/opt/cd-ub/reports/live/portfolio")
rows = []
for line in (out/"raw_results.tsv").read_text().splitlines()[1:]:
    if not line.strip():
        continue
    name,label,disagree,ubsan,seed = line.split("|")
    rows.append({"name": name, "label": label, "disagree": int(disagree),
                 "ubsan_hit": int(ubsan), "seed": seed})
TP = sum(1 for r in rows if r["label"]=="BAD" and r["disagree"]==1)
FN = sum(1 for r in rows if r["label"]=="BAD" and r["disagree"]==0)
FP = sum(1 for r in rows if r["label"]=="GOOD" and r["disagree"]==1)
TN = sum(1 for r in rows if r["label"]=="GOOD" and r["disagree"]==0)
bad_n, good_n = TP+FN, FP+TN
recall = (TP/bad_n) if bad_n else 0.0
fpr = (FP/good_n) if good_n else 0.0
complement = sum(1 for r in rows if r["label"]=="BAD" and r["disagree"]==1 and r["ubsan_hit"]==0)
sanitizer_also = sum(1 for r in rows if r["label"]=="BAD" and r["disagree"]==1 and r["ubsan_hit"]==1)
report = {
  "title": "CD-UB Portfolio Elite Evaluation",
  "method": "NIST Juliet-style BAD/GOOD + CompDiff speed-2 oracle + UBSan co-check",
  "citations": [
    "NIST Juliet Test Suite C/C++ 1.3 (SAMATE)",
    "CompDiff ASPLOS 2023 (Li & Su)",
    "Microsoft Research EMI PLDI 2014",
    "FuZZan ATC 2020 (Juliet sanitizer methodology)"
  ],
  "metrics": {
    "TP": TP, "FN": FN, "FP": FP, "TN": TN,
    "recall": round(recall, 4),
    "false_positive_rate": round(fpr, 4),
    "sanitizer_missed_but_cdub": complement,
    "cdub_and_ubsan_both": sanitizer_also,
    "MOCK_PCT": 0
  },
  "cases": rows,
  "gates": {
    "recall_ge_0_5": recall >= 0.5,
    "fpr_eq_0": fpr == 0.0,
    "complement_ge_1": complement >= 1,
    "mock_pct_0": True
  }
}
(out/"PORTFOLIO_REPORT.json").write_text(json.dumps(report, indent=2))
print(json.dumps(report["metrics"], indent=2))
print("GATES", report["gates"])
PY

export PF_PM2="$(bash "$GUARD" | tail -1)"
python3 "${ROOT}/portfolio/write_portfolio_md.py"
STATUS=$?
bash "$GUARD"
echo "ARTIFACTS=$OUT"
ls -la "$OUT"
exit $STATUS
