#!/usr/bin/env bash
# ミューテーションテストを実行する。引数なしで全ファイル、引数があればそのファイルだけ。
#   mutation_test/run.sh              # judge trivia number_style daily_puzzle daily_stats
#   mutation_test/run.sh trivia       # 1 ファイルだけ
# レポートは mutation-test-report/<name>/ に出る（.gitignore 済み）。
set -u
cd "$(dirname "$0")/.."
targets=("$@")
[ ${#targets[@]} -eq 0 ] && targets=(trivia number_style daily_puzzle daily_stats judge)
status=0
for t in "${targets[@]}"; do
  echo "== $t"
  dart run mutation_test --rules mutation_test/rules.xml \
    -o "mutation-test-report/$t" "mutation_test/$t.xml" || status=1
done
exit $status
