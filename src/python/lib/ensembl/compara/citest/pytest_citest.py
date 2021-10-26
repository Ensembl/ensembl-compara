# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
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
"""CITest plugin for pytest."""

from collections import OrderedDict
import json
import os
from typing import Dict, Iterator, Optional

import py
import pytest
from _pytest.config.argparsing import Parser
from _pytest.runner import TestReport

from ensembl.database import DBConnection
from ..filesys import DirCmp
from .testdb import CITestDBItem
from .testfiles import CITestFilesItem


@pytest.hookimpl()
def pytest_addoption(parser: Parser) -> None:
    """Registers argparse-style options for CITest."""
    group = parser.getgroup("continuous integration test (citest)")
    group.addoption('--reference-db', action='store', metavar='URL', dest='reference_db',
                    help="URL to reference database")
    group.addoption('--reference-dir', action='store', metavar='PATH', dest='reference_dir',
                    help="Path to reference root directory")
    group.addoption('--target-db', action='store', metavar='URL', dest='target_db',
                    help="URL to target database")
    group.addoption('--target-dir', action='store', metavar='PATH', dest='target_dir',
                    help="Path to target root directory")


def pytest_collect_file(parent: pytest.Session, path: py.path.local) -> Optional[pytest.File]:
    """Returns the collection of tests to run as indicated in the given JSON file."""
    if path.ext == '.json':
        return JsonFile(path, parent)
    return None


def pytest_sessionstart(session: pytest.Session) -> None:
    """Adds required variables to the session before entering the run test loop."""
    session.report = {}


@pytest.hookimpl(tryfirst=True, hookwrapper=True)
def pytest_runtest_makereport(item: pytest.Item) -> TestReport:
    """Returns the test report updated with custom information."""
    outcome = yield
    report = outcome.get_result()
    if report.when == 'call':
        item.session.report[item] = report


def pytest_sessionfinish(session: pytest.Session) -> None:
    """Generates a custom report before returning the exit status to the system."""
    # Use the configuration JSON file as template for the report
    config_filename = session.config.getoption('file_or_dir')[0]
    with open(config_filename) as f:
        full_report = json.load(f, object_pairs_hook=OrderedDict)
    # Update/add global information
    for arg in ['reference_db', 'reference_dir', 'target_db', 'target_dir']:
        full_report[arg] = session.config.getoption(arg, full_report.get(arg), True)
    # Add the reported information of each test
    failed = 0
    for item, report in session.report.items():
        if isinstance(item, CITestDBItem):
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
        while os.path.isfile(f"{report_filename}.{i}"):
            i += 1
        report_filename = f"{report_filename}.{i}"
    with open(report_filename, "w") as f:
        json.dump(full_report, f, indent=4)
    # Print summary in STDOUT
    total = len(session.report)
    print(f"\n{total - failed} out of {total} tests ok")


class JsonFile(pytest.File):
    """Test collector from CITest JSON files."""
    def collect(self) -> Iterator:
        """Parses the JSON file and loads all the tests.

        Returns:
            Iterator of :class:`testdb.CITestDBItem` or :class:`testfiles.CITestFilesItem` objects (depending
            on the the tests included in the JSON file).

        Raises:
            AttributeError: If ``test`` or ``args`` keys are missing in any test.

        """
        # Load the JSON file
        with self.fspath.open() as f:
            pipeline_tests = json.load(f)
        # Parse each test and load it
        if 'database_tests' in pipeline_tests:
            # Load the reference and target DBs
            ref_url = self._get_arg(pipeline_tests, 'reference_db')
            target_url = self._get_arg(pipeline_tests, 'target_db')
            ref_dbc = DBConnection(ref_url)
            target_dbc = DBConnection(target_url)
            for table, test_list in pipeline_tests['database_tests'].items():
                for test in test_list:
                    # Ensure required keys are present in every test
                    if 'test' not in test:
                        raise AttributeError(f"Missing argument 'test' in database_tests['{table}']")
                    if 'args' not in test:
                        raise AttributeError(
                            f"Missing argument 'args' in database_tests['{table}']['{test['test']}']")
                    yield CITestDBItem(test['test'], self, ref_dbc, target_dbc, table, test['args'])
        if 'files_tests' in pipeline_tests:
            # Load the reference and target directory paths
            ref_path = os.path.expandvars(self._get_arg(pipeline_tests, 'reference_dir'))
            target_path = os.path.expandvars(self._get_arg(pipeline_tests, 'target_dir'))
            dir_cmp = DirCmp(ref_path=ref_path, target_path=target_path)
            for i, test in enumerate(pipeline_tests['files_tests'], 1):
                # Ensure required keys are present in every test
                if 'test' not in test:
                    raise AttributeError(f"Missing argument 'test' in files_tests #{i}")
                if 'args' not in test:
                    raise AttributeError(f"Missing argument 'args' in files_tests #{i}")
                yield CITestFilesItem(test['test'], self, dir_cmp, test['args'])

    def _get_arg(self, pipeline_tests: Dict, name: str) -> str:
        """Returns the requested parameter from the command line (priority) or the JSON configuration file.

        Args:
            pipeline_tests: Pipeline tests and their configuration.
            name: Parameter name.

        Raises:
            ValueError: If the parameter has not been set in neither the command line nor the JSON
                configuration file.

        """
        argument = self.config.getoption(name, pipeline_tests.get(name, ''), True)
        if not argument:
            raise ValueError(f"Required argument '--{name.replace('_', '-')}' or '{name}' key in JSON file")
        return argument
