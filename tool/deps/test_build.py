"""tool/deps/build.py の依存の向きの検査（classify / check）のテスト。

lakos は呼ばず、lakos の JSON 出力と同じ形の小さなデータで確かめる。
実行: python3 -m unittest discover -s tool/deps
"""

import contextlib
import importlib.util
import io
import unittest
from pathlib import Path
from unittest import mock

# `import build` だと、pip の build パッケージやリポジトリの build/ とぶつかるので、パスで読み込む
_spec = importlib.util.spec_from_file_location(
    "deps_build", Path(__file__).with_name("build.py")
)
build = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(build)


def graph(*pairs, extra_nodes=(), acyclic=True):
    """(from, to) の組から、lakos の JSON と同じ形のデータを作る。"""
    names = {n for pair in pairs for n in pair} | set(extra_nodes)
    return {
        "nodes": {f"/lib/{n}.dart": {"label": n} for n in names},
        "edges": [
            {"from": f"/lib/{a}.dart", "to": f"/lib/{b}.dart", "directive": "import"}
            for a, b in pairs
        ],
        "metrics": {
            "isAcyclic": acyclic,
            "firstCycle": [] if acyclic else ["/lib/a.dart", "/lib/b.dart"],
            "numNodes": len(names),
        },
    }


def kinds(data):
    _, _, edges, violations, unassigned = build.classify(data)
    return {(a, b): k for a, b, k in edges}, violations, unassigned


class ClassifyTest(unittest.TestCase):
    def test_upper_to_lower_layer_is_fine(self):
        edges, violations, _ = kinds(graph(("home_page", "daily_repository")))
        self.assertEqual(edges, {("home_page", "daily_repository"): "down"})
        self.assertEqual(violations, [])

    def test_skipping_layers_is_fine(self):
        # 入口 -> 純粋ロジック（2 層飛ばし）
        edges, violations, _ = kinds(graph(("main", "judge")))
        self.assertEqual(edges, {("main", "judge"): "down"})
        self.assertEqual(violations, [])

    def test_lower_to_upper_layer_is_a_violation(self):
        edges, violations, _ = kinds(graph(("judge", "home_page")))
        self.assertEqual(violations, [("judge", "home_page")])
        self.assertEqual(edges, {("judge", "home_page"): "violation"})

    def test_adjacent_layer_upward_is_a_violation(self):
        # 保存の層（1）から画面の層（2）
        _, violations, _ = kinds(graph(("daily_repository", "daily_page")))
        self.assertEqual(violations, [("daily_repository", "daily_page")])

    def test_same_layer_is_not_a_violation(self):
        edges, violations, _ = kinds(graph(("daily_banner", "daily_page")))
        self.assertEqual(edges, {("daily_banner", "daily_page"): "same"})
        self.assertEqual(violations, [])

    def test_using_a_shared_part_is_fine_from_any_layer(self):
        pairs = [(a, "language") for a in ("main", "daily_page", "daily_stats", "judge")]
        edges, violations, _ = kinds(graph(*pairs))
        self.assertEqual(violations, [])
        self.assertEqual(edges, {})  # 共通部品への依存は図にも出さない

    def test_shared_part_importing_another_file_is_a_violation(self):
        _, violations, _ = kinds(graph(("share", "judge")))
        self.assertEqual(violations, [("share", "judge")])

    def test_shared_part_importing_another_shared_part_is_fine(self):
        _, violations, _ = kinds(graph(("share", "links")))
        self.assertEqual(violations, [])

    def test_unassigned_file_is_reported_and_not_a_violation(self):
        edges, violations, unassigned = kinds(
            graph(("new_file", "judge"), ("main", "new_file"))
        )
        self.assertEqual(unassigned, ["new_file"])
        self.assertEqual(violations, [])
        self.assertEqual(edges, {})

    def test_test_files_are_ignored(self):
        data = graph(("judge", "judge_isolate"))
        data["nodes"]["/test/judge_test.dart"] = {"label": "judge_test"}
        data["edges"].append(
            {"from": "/test/judge_test.dart", "to": "/lib/judge.dart", "directive": "import"}
        )
        _, violations, unassigned = kinds(data)
        self.assertEqual(violations, [])
        self.assertEqual(unassigned, [])

    def test_every_file_is_in_exactly_one_group(self):
        members = [m for _, _, ms in build.LAYERS for m in ms] + build.SHARED
        self.assertEqual(len(members), len(set(members)))


class CheckTest(unittest.TestCase):
    def run_check(self, data):
        out = io.StringIO()
        with mock.patch.object(build, "stage"), mock.patch.object(
            build, "lakos_json", return_value=data
        ), contextlib.redirect_stdout(out):
            code = build.check(Path("."))
        return code, out.getvalue()

    def test_clean_graph_passes(self):
        code, out = self.run_check(graph(("home_page", "judge"), ("main", "language")))
        self.assertEqual(code, 0)
        self.assertIn("OK", out)

    def test_violation_fails_with_an_error_annotation(self):
        code, out = self.run_check(graph(("judge", "home_page")))
        self.assertEqual(code, 1)
        self.assertIn("::error::依存の向きの違反: judge -> home_page", out)

    def test_cycle_fails(self):
        code, out = self.run_check(graph(("daily_banner", "daily_page"), acyclic=False))
        self.assertEqual(code, 1)
        self.assertIn("::error::循環依存", out)

    def test_unassigned_file_only_warns(self):
        code, out = self.run_check(graph(("main", "new_file")))
        self.assertEqual(code, 0)
        self.assertIn("::warning::層が未割り当て: new_file", out)


if __name__ == "__main__":
    unittest.main()
