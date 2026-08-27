# Beat Google claim card — libtiff
# Mission: OSS-Fuzz libtiff v4.3.0 + ASan/UBSan(/MSan) PASS on corpus C;
#          CD-UB speed-2 finds output-file disagreement D on same input.
TARGET=libtiff
BINARY=tiffcp
OSS_FUZZ=yes
VERSION=v4.3.0
ORACLE_GOOGLE=ASan,UBSan,MSan
ORACLE_CDUB=CompDiff speed-2 (gcc -O0 vs clang -O3)
HARNESS=tiffcp -M -i @@ out.file
BEAT_DEF=sanitizers silent AND cdub file disagree AND triage not NOISE AND MOCK_PCT=0
