#!/usr/bin/env bash
# ミューテーションテストを実行する。引数なしで全ファイル、引数があればそのファイルだけ。
#   mutation_test/run.sh              # trivia number_style daily_puzzle date_key daily_stats judge spoken
#   mutation_test/run.sh trivia       # 1 ファイルだけ
# レポートは mutation-test-report/<name>/ に出る（.gitignore 済み）。
#
# 合否はツールの閾値ではなく「生き残った変異の数」で決める。
# ツールは無限ループでタイムアウトした変異（= テストが止めたので検出済み）も未検出に
# 数えるため、検出率では判定できない。生き残り = 未検出 - タイムアウト。
# 生き残りが下の基準値を超えたら失敗する（テストが弱くなった／除外の正規表現が
# 外れて等価変異が生き残った、のどちらでも気づける）。
set -u
cd "$(dirname "$0")/.."

# 許容する生き残り数。どれも結果が変わらない等価変異（理由は各 XML のコメントと PR #69）。
#   trivia: n > 2（2 にはトリビアがあり到達しない）
#   judge : aBig == n（結果が変わらない）
max_survivors() {
  case "$1" in
    trivia | judge) echo 1 ;;
    *) echo 0 ;;
  esac
}

targets=("$@")
[ ${#targets[@]} -eq 0 ] && targets=(trivia number_style daily_puzzle date_key daily_stats judge spoken)
log=$(mktemp)
trap 'rm -f "$log"' EXIT
status=0
for t in "${targets[@]}"; do
  echo "== $t"
  dart run mutation_test --rules mutation_test/rules.xml \
    -o "mutation-test-report/$t" "mutation_test/$t.xml" 2>&1 | tr '\r' '\n' | tee "$log" |
    grep -E "^(Total tests|Undetected|Timeouts|Elapsed)" || true
  total=$(sed -n 's/^Total tests: \([0-9]*\).*/\1/p' "$log" | tail -1)
  undetected=$(sed -n 's/^Undetected Mutations: \([0-9]*\).*/\1/p' "$log" | tail -1)
  timeouts=$(sed -n 's/^Timeouts: \([0-9]*\).*/\1/p' "$log" | tail -1)
  if [ -z "$total" ] || [ -z "$undetected" ] || [ -z "$timeouts" ]; then
    echo "FAIL $t: could not read the mutation_test summary"
    status=1
    continue
  fi
  survivors=$((undetected - timeouts))
  max=$(max_survivors "$t")
  if [ "$survivors" -gt "$max" ]; then
    echo "FAIL $t: $survivors survivors (allowed $max) of $total mutations; see mutation-test-report/$t"
    status=1
  else
    echo "OK   $t: $survivors survivors (allowed $max) of $total mutations, $timeouts timed out"
  fi
done
exit $status
