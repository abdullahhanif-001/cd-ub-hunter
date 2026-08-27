# CD-UB SCORECARD FINAL
DATE_UTC=Thu Aug 27 15:10:36 UTC 2026
HOST=vmi3469243
AUTO_WIPE=0
MOCK_PCT=0
PROFILE=speed-2
PM2_GUARD_OK count=6 restarts_sum=131 baseline_sum=131
## T1
=== gcc -O0 ===
R 12 11 10
=== clang -O3 ===
R 10 11 12
CDUB_DEMO=DIFF_FOUND
CLASS=PROGRAM_UB
MOCK_PCT=0
T1_DEMO=PASS
T1_LIBTIFF_BIN=YES
T1_UNSTABLE_BIN=YES
[1;94m[*] [0mFuzzing test case #1 (2 total, 0 uniq crashes found, perf_score=114, exec_us=1191, hits=2867, map=5)...[0m
[1;94m[*] [0mFuzzing test case #0 (2 total, 0 uniq crashes found, perf_score=459, exec_us=1554, hits=0, map=5)...[0m
[1;94m[*] [0mEntering queue cycle 4.[0m
[1;94m[*] [0mFuzzing test case #1 (2 total, 0 uniq crashes found, perf_score=114, exec_us=1191, hits=4021, map=5)...[0m
[1;94m[*] [0mFuzzing test case #1 (2 total, 0 uniq crashes found, perf_score=114, exec_us=1191, hits=4297, map=5)...[0m
[1;94m[*] [0mFuzzing test case #1 (2 total, 0 uniq crashes found, perf_score=114, exec_us=1191, hits=4569, map=5)...[0m
[1;94m[*] [0mFuzzing test case #1 (2 total, 0 uniq crashes found, perf_score=114, exec_us=1191, hits=4841, map=5)...[0m
[1;94m[*] [0mEntering queue cycle 5.[0m
[1;94m[*] [0mFuzzing test case #1 (2 total, 0 uniq crashes found, perf_score=114, exec_us=1191, hits=5117, map=5)...[0m
[1;94m[*] [0mFuzzing test case #1 (2 total, 0 uniq crashes found, perf_score=114, exec_us=1191, hits=5390, map=5)...[0m
[1;94m[*] [0mFuzzing test case #1 (2 total, 0 uniq crashes found, perf_score=114, exec_us=1191, hits=5671, map=5)...[0m
[1;94m[*] [0mFuzzing test case #1 (2 total, 0 uniq crashes found, perf_score=114, exec_us=1191, hits=5947, map=5)...[0m
[1;94m[*] [0mEntering queue cycle 6.[0m
[1;94m[*] [0mFuzzing test case #1 (2 total, 0 uniq crashes found, perf_score=114, exec_us=1191, hits=6223, map=5)...[0m
[1;94m[*] [0mFuzzing test case #1 (2 total, 0 uniq crashes found, perf_score=114, exec_us=1191, hits=6502, map=5)...[0m
[1;94m[*] [0mFuzzing test case #1 (2 total, 0 uniq crashes found, perf_score=114, exec_us=1191, hits=6776, map=5)...[0m
[1;94m[*] [0mFuzzing test case #1 (2 total, 0 uniq crashes found, perf_score=114, exec_us=1191, hits=7057, map=5)...[0m
[1;94m[*] [0mEntering queue cycle 7.[0m
[1;94m[*] [0mFuzzing test case #1 (2 total, 0 uniq crashes found, perf_score=114, exec_us=1191, hits=7341, map=5)...[0m
[1;94m[*] [0mFuzzing test case #1 (2 total, 0 uniq crashes found, perf_score=114, exec_us=1191, hits=7626, map=5)...[0m
[?25h[1;91m

+++ Testing aborted by user +++
[0m[1;92m[+] [0mWe're done here. Have a nice day!
[0m
T1_FUZZ=RAN
PM2_GUARD_OK count=6 restarts_sum=131 baseline_sum=131
T1_SELF=PASS
## T2
=== T2 cyber defensive ===
PASS: no pm2 mutate in wrappers
deploy/contabo/cyber-defensive-audit.sh:19:# 2) No nginx reload
deploy/contabo/cyber-defensive-audit.sh:24:if grep -RInE 'systemctl (reload|restart) nginx|docker (stop|rm).*mongo' deploy scripts 2>/dev/null; then
deploy/contabo/cyber-defensive-audit.sh:25:  echo "FAIL: nginx/mongo mutate commands"
deploy/contabo/cyber-defensive-audit.sh:28:  echo "PASS: no nginx/mongo mutate commands"
PASS: no nginx/mongo mutate commands
PASS: no /opt escape to other apps
PASS: no obvious secrets
MemoryMax=2684354560
PASS: systemd caps visible
PASS: wipe refused without confirm
PM2_GUARD_OK count=6 restarts_sum=131 baseline_sum=131
T2_CYBER=PASS
PM2_GUARD_OK count=6 restarts_sum=131 baseline_sum=131
## T3 ULTRA
=== gcc -O0 ===
R 12 11 10
=== clang -O3 ===
R 10 11 12
CDUB_DEMO=DIFF_FOUND
CLASS=PROGRAM_UB
MOCK_PCT=0
TRIAGE_OK /opt/cd-ub/reports/live/triage-20260827171138 CLASS=PROGRAM_UB
ULTRA_PASS=PASS
CLASS=PROGRAM_UB
MOCK_PCT=0
PM2_GUARD_OK count=6 restarts_sum=131 baseline_sum=131
MemoryMax=2684354560
Nice=5
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        96G   14G   82G  15% /
KEEP_UNTIL_USER_WIPE=1
VPS_CDUB_PRESENT=1
VERDICT=READY
