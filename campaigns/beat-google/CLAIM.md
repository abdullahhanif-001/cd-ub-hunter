# Beat Google claim card
# Mission: OSS-Fuzz project jq + ASan/UBSan(/MSan) PASS on corpus C;
#          CD-UB speed-2 finds disagreement D on same input.
TARGET=jq
OSS_FUZZ=yes
ORACLE_GOOGLE=ASan,UBSan,MSan
ORACLE_CDUB=CompDiff speed-2 (gcc -O0 vs clang -O3)
BEAT_DEF=sanitizers silent AND cdub disagree AND triage not NOISE AND MOCK_PCT=0
