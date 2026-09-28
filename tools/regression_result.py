#!/usr/bin/env python3
"""Fail-closed acceptance for the bounded boot observer, never for elapsed time."""
import argparse
from pathlib import Path
import re
import unittest

PASS = re.compile(r'^boot PASS: reached CODE 3\+\$03e4$', re.MULTILINE)
FAIL = re.compile(r'\bFAIL\b|loud stop|loader stop:|Program received signal|Error in sourced command file', re.IGNORECASE)


def failure(log, status):
    if status:
        return f'runner exited {status}'
    if FAIL.search(log):
        return 'failure or loud stop in observer log'
    if len(PASS.findall(log)) != 1:
        return 'missing or duplicate main-entry PASS record'
    return None


class ResultTests(unittest.TestCase):
    def test_acceptance(self):
        passed = 'boot PASS: reached CODE 3+$03e4\n'
        cases = [
            (passed, 0, True),
            ('', 0, False),
            ('boot PASS: reached CODE 3+$03e4 trailing text\n', 0, False),
            ('echo ' + passed, 0, False),
            (passed * 2, 0, False),
            (passed, 124, False),  # A PASS before a timeout still fails.
            (passed, 1, False),
            (passed + 'boot FAIL loud stop: SEGMENT LOADER / CREL RELOCATION\n', 0, False),
            (passed + 'Program received signal SIGTRAP\n', 0, False),
            (passed + 'Error in sourced command file\n', 0, False),
        ]
        for log, status, expected in cases:
            with self.subTest(log=log, status=status):
                self.assertEqual(failure(log, status) is None, expected)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', nargs='?', type=Path)
    parser.add_argument('--status', type=int, default=0)
    parser.add_argument('--selftest', action='store_true')
    args = parser.parse_args()
    if args.selftest:
        suite = unittest.defaultTestLoader.loadTestsFromTestCase(ResultTests)
        return not unittest.TextTestRunner().run(suite).wasSuccessful()
    if args.log is None:
        parser.error('log is required')
    try:
        reason = failure(args.log.read_text(), args.status)
    except OSError as exc:
        reason = str(exc)
    print(f'FAIL: boot: {reason}' if reason else 'PASS: boot')
    return int(reason is not None)


if __name__ == '__main__':
    raise SystemExit(main())
