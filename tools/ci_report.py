#!/usr/bin/env python3
"""Turns the build / self-test logs into GitHub annotations and a short step summary.

Run from the repository root by the "Summarize" workflow step:

    python3 tools/ci_report.py <job-status>

Annotations are chunked so a failing build can be read back through the public
check-run annotations API without having to download logs.
"""
import os
import re
import sys

ROOT_RE = re.compile(r"/Users/runner/work/[^/]+/[^/]+/")
DIAG_RE = re.compile(r"^(?:/|[A-Za-z]:).*?:\d+:\d+: (error|warning|note): ")
ERROR_RE = re.compile(r"(?:^|[\s:])error: ")
CHUNK = 3200
MAX_CHUNKS = 8


def read(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return ""


def esc_data(text):
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def esc_prop(text):
    return esc_data(text).replace(":", "%3A").replace(",", "%2C")


def annotate(level, title, message):
    print("::%s title=%s::%s" % (level, esc_prop(title), esc_data(message)))


def chunked(entries, limit=CHUNK):
    chunks, current, size = [], [], 0
    for entry in entries:
        if size + len(entry) + 1 > limit and current:
            chunks.append("\n".join(current))
            current, size = [], 0
        current.append(entry)
        size += len(entry) + 1
    if current:
        chunks.append("\n".join(current))
    return chunks


def compiler_errors(log):
    """Each error with the source line, caret and any notes that follow it."""
    lines = log.splitlines()
    entries, seen = [], set()
    i = 0
    while i < len(lines):
        line = lines[i]
        if ERROR_RE.search(line) and not line.lstrip().startswith("**"):
            block = [ROOT_RE.sub("", line)[:400]]
            j = i + 1
            while j < len(lines) and len(block) < 7:
                nxt = lines[j]
                if DIAG_RE.match(nxt):
                    if "note: " in nxt.split(":", 4)[-1][:8] or ": note: " in nxt:
                        block.append(ROOT_RE.sub("", nxt)[:300])
                        j += 1
                        continue
                    break
                if not nxt.strip() or nxt.startswith(("Command ", "SwiftCompile", "CompileSwift", "** ")):
                    break
                block.append(nxt[:200])
                j += 1
            text = "\n".join(block)
            if text not in seen:
                seen.add(text)
                entries.append(text)
            i = j
        else:
            i += 1
    return entries


def main():
    status = sys.argv[1] if len(sys.argv) > 1 else "unknown"
    build_log = read("build.log")
    selftest_log = read("selftest/run.log")
    selftest_build = read("selftest/compile.log")

    summary = ["## WidgetForge build: %s" % status, ""]

    errors = compiler_errors(build_log)
    if errors:
        chunks = chunked(errors)
        for index, chunk in enumerate(chunks[:MAX_CHUNKS], 1):
            annotate("error", "Swift errors %d of %d (%d found)" % (index, min(len(chunks), MAX_CHUNKS), len(errors)), chunk)
        summary += ["Compiler / build errors:", "", "```"] + [e for e in errors[:40]] + ["```", ""]
    elif status != "success":
        tail = "\n".join(build_log.splitlines()[-40:]) or "(no build log)"
        annotate("error", "Build stopped without a Swift error", tail[-CHUNK:])
        summary += ["The build stopped before producing an IPA. End of the log:", "", "```", tail, "```", ""]

    warnings = sorted({ROOT_RE.sub("", l) for l in build_log.splitlines() if ": warning: " in l and DIAG_RE.match(l)})
    if warnings:
        annotate("warning", "Swift warnings (%d)" % len(warnings), "\n".join(warnings)[:CHUNK])

    if selftest_build.strip() and "error:" in selftest_build:
        errs = [ROOT_RE.sub("", l) for l in selftest_build.splitlines() if "error:" in l]
        annotate("warning", "Self-test did not compile", "\n".join(errs)[:CHUNK])
        summary += ["Self-test did not compile:", "", "```"] + errs[:20] + ["```", ""]

    if selftest_log.strip():
        failures = [l for l in selftest_log.splitlines() if l.startswith("FAIL")]
        tail = [l for l in selftest_log.splitlines() if l.startswith(("PASS-COUNT", "FAIL-COUNT", "SUMMARY", "INFO"))]
        if failures:
            for index, chunk in enumerate(chunked(failures)[:3], 1):
                annotate("warning", "Self-test failures part %d" % index, chunk)
            summary += ["Self-test failures:", "", "```"] + failures[:40] + ["```", ""]
        annotate("notice", "Self-test", "\n".join(tail)[:CHUNK] or "ran")
        summary += ["Self-test: " + (" | ".join(tail) or "ran"), ""]

    if status == "success":
        summary += ["Download **WidgetForge-ipa** from the Artifacts section at the bottom of this page.", ""]

    target = os.environ.get("GITHUB_STEP_SUMMARY")
    if target:
        with open(target, "a", encoding="utf-8") as fh:
            fh.write("\n".join(summary) + "\n")

    with open("errors.txt", "w", encoding="utf-8") as fh:
        fh.write("\n\n".join(errors) + "\n")


if __name__ == "__main__":
    main()
