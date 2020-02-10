# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""CITest plugin for pytest.

Pytest plugin that defines a set hooks and classes to parse and run tests for the Continuous Integration Test
(CITest) suite.

"""

from collections import OrderedDict
import json
import os
from typing import Iterator, Optional

import py
import pytest
from _pytest.config.argparsing import Parser
from _pytest.runner import TestReport

from ensembl.compara.db.DBConnection import DBConnection
from ensembl.compara.citest import TestDB, TestFiles


@pytest.hookimpl()
def pytest_addoption(parser: Parser) -> None:
    """Register argparse-style options for CITest."""
    group = parser.getgroup("continuous integration test (citest)")
    group.addoption('--ref-db', action='store', metavar='URL', dest='ref_db',
                    help="URL to the reference database")
    group.addoption('--ref-dir', action='store', metavar='PATH', dest='ref_dir',
                    help="Path to reference's root directory")
    group.addoption('--target-db', action='store', metavar='URL', dest='target_db',
                    help="URL to the target database")
    group.addoption('--target-dir', action='store', metavar='PATH', dest='target_dir',
                    help="Path to target's root directory")


def pytest_collect_file(parent: pytest.Session, path: py.path.local) -> Optional[pytest.File]:
    """Returns the collection of tests to run as indicated in the given JSON file."""
    if path.ext == '.json':
        return JsonFile(path, parent)
    return None


def pytest_sessionstart(session: pytest.Session) -> None:
    """Add required variables to the session before entering the run test loop."""
    session.report = {}


@pytest.hookimpl(tryfirst=True, hookwrapper=True)
def pytest_runtest_makereport(item: pytest.Item) -> TestReport:
    """Returns the test report updated with custom information."""
    outcome = yield
    report = outcome.get_result()
    if report.when == 'call':
        item.session.report[item] = report


def pytest_sessionfinish(session: pytest.Session) -> None:
    """Generate a custom report before returning the exit status to the system."""
    # Use the configuration JSON file as template for the report
    config_filename = session.config.getoption('file_or_dir')[0]
    with open(config_filename) as f:
        full_report = json.load(f, object_pairs_hook=OrderedDict)
    # Update/add global information
    full_report['reference_db'] = session.config.getoption('ref_db', full_report.get('reference_db'), True)
    full_report['reference_dir'] = session.config.getoption('ref_dir', full_report.get('reference_dir'), True)
    full_report['target_db'] = session.config.getoption('target_db', full_report.get('target_db'), True)
    full_report['target_dir'] = session.config.getoption('target_dir', full_report.get('target_dir'), True)
    # Add the reported information of each test
    failed = 0
    for item, report in session.report.items():
        if isinstance(item, TestDB.TestDBItem):
            test_list = full_report['database_tests'][item.table]
        else:
            test_list = full_report['files_tests']
        for test in test_list:
            # Find the test entry corresponding to this item
            if (test['test'] == item.name) and (test['args'] == item.args):
                test['status'] = report.outcome.capitalize()
                if report.failed:
                    failed += 1
                    test['error'] = OrderedDict([('message', report.longreprtext)])
                    if item.error_info:
                        test['error']['details'] = item.error_info
                break
    # Save full report in a JSON file with the same name as the citest JSON file
    report_filename = os.path.basename(config_filename).rsplit(".", 1)[0] + ".report.json"
    # Make sure not to overwrite previous reports
    if os.path.isfile(report_filename):
        i = 1
        while os.path.isfile("{}.{}".format(report_filename, i)):
            i += 1
        report_filename = "{}.{}".format(report_filename, i)
    with open(report_filename, "w") as f:
        json.dump(full_report, f, indent=4)
    # Print summary in STDOUT
    total = len(session.report)
    print("\n{} out of {} tests ok".format(total - failed, total))


class JsonFile(pytest.File):
    """Test collector from CITest JSON files."""
    def collect(self) -> Iterator:
        """Parses the JSON file and loads all the tests.

        Returns:
            Iterator of ``TestDB.TestDBItem`` or ``TestFiles.TestFilesItem`` objects (depending on the tests
            included in the JSON file).

        Raises:
            AssertionError: If the reference or target information is missing for the database or files tests;
                or if ``test`` or ``args`` keys are missing in any test.

        """
        # Load the JSON file
        with self.fspath.open() as f:
            pipeline_tests = json.load(f)
        # Parse each test and load it
        if 'database_tests' in pipeline_tests:
            # Load the reference and target DBs
            ref_url = self.config.getoption('ref_db', pipeline_tests.get('reference_db', ''), True)
            assert ref_url, "Required argument '--ref-db' or 'reference_db' key in JSON file"
            target_url = self.config.getoption('target_db', pipeline_tests.get('target_db', ''), True)
            assert target_url, "Required argument '--target-db' or 'target_db' key in JSON file"
            ref_db = DBConnection(ref_url)
            target_db = DBConnection(target_url)
            for table, test_list in pipeline_tests['database_tests'].items():
                for test in test_list:
                    # Ensure required keys are present in every test
                    assert 'test' in test, "Missing argument 'test' in database_tests['{}'].".format(table)
                    assert 'args' in test, "Missing argument 'args' in database_tests['{}']['{}'].".format(
                        table, test['test'])
                    yield TestDB.TestDBItem(test['test'], self, ref_db, target_db, table, test['args'])
        if 'files_tests' in pipeline_tests:
            # Load the reference and target directory paths
            ref_path = self.config.getoption('ref_dir', pipeline_tests.get('reference_dir', ''), True)
            assert ref_path, "Required argument '--ref-dir' or 'reference_dir' key in JSON file"
            target_path = self.config.getoption('target_dir', pipeline_tests.get('target_dir', ''), True)
            assert target_path, "Required argument '--target-dir' or 'target_dir' key in JSON file"
            dir_cmp = TestFiles.DirCmp(ref_path=ref_path, target_path=target_path)
            for i, test in enumerate(pipeline_tests['files_tests'], 1):
                # Ensure required keys are present in every test
                assert 'test' in test, "Missing argument 'test' in files_tests #{}.".format(i)
                assert 'args' in test, "Missing argument 'args' in files_tests #{}.".format(i)
                yield TestFiles.TestFilesItem(test['test'], self, dir_cmp, test['args'])
