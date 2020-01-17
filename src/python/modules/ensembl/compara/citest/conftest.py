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
"""Local hook and fixture implementations for the Continuous Integration Test (CITest) suite."""

import json
from typing import Dict

import pytest
from _pytest.config.argparsing import Parser
from _pytest.fixtures import FixtureRequest
from _pytest.main import Session
from _pytest.python import Metafunc
from _pytest.runner import CallInfo, TestReport

from ensembl.compara.citest import TestDB


def pytest_addoption(parser: Parser) -> None:
    """Register argparse-style options for the test run.

    Args:
        parser: Command line option parser.
    """
    parser.addoption("--json-file", action="store", required=True, metavar="JSON_FILE", dest="json_file",
                     help="CITest configuration JSON file")
    parser.addoption("--ref-url", action="store", metavar="URL", dest="ref_url",
                     help="URL to the reference database")
    parser.addoption("--target-url", action="store", required=True, metavar="URL", dest="target_url",
                     help="URL to the target database")


def pytest_generate_tests(metafunc: Metafunc) -> None:
    """Generate (multiple) parametrized calls to a test function.

    Args:
        metafunc: Container of the test configuration values.
    """
    json_file = metafunc.config.getoption("json_file")
    ref_url = metafunc.config.getoption("ref_url")
    target_url = metafunc.config.getoption("target_url")
    test_data = get_test_data(json_file, ref_url, target_url)
    # Load the parameters for each test
    metafunc.parametrize('db_test_data', test_data["database"], indirect=True)
    # TODO: parametrize all files tests (once class is available)


@pytest.fixture()
def db_test_data(request: FixtureRequest) -> Dict:
    """Fixture to retrieve the database test data.

    Args:
        request: Special fixture providing information of the requesting test function.

    Returns:
        Dictionary with the database test data. Keys "db_test_handler", "test" and "table" will always be
        present.
    """
    return request.param


def pytest_sessionstart(session: Session) -> None:
    """Add required variables to the session before entering the run test loop.

    Args:
        session: Pytest Session object.
    """
    session.report = {}


def pytest_sessionfinish(session: Session, exitstatus: int) -> None:
    """Generate a custom report before returning the exit status to the system.

    Args:
        session: Pytest Session object.
        existatus: Status which pytest will return to the system.
    """
    print("\nrun status code:", exitstatus)
    passed_amount = sum(1 for report in session.report.values() if report.passed)
    failed_amount = sum(1 for report in session.report.values() if report.failed)
    print("there are {} passed and {} failed tests".format(passed_amount, failed_amount))
    # for report in session.report.values():
    #     print(report.report_info)


@pytest.hookimpl(tryfirst=True, hookwrapper=True)
def pytest_runtest_makereport(item: pytest.Item, call: CallInfo) -> TestReport:
    """Extend the test report with custom information.

    Args:
        item: Pytest Item.
        call: Result/Exception info a function invocation.

    Returns:
        Updated test report.
    """
    outcome = yield
    report = outcome.get_result()
    if report.when == 'call':
        # Update the test report adding our custom report_info
        report.report_info = getattr(item, 'report_info', 0)
        item.session.report[item] = report


def get_test_data(json_file: str, ref_url: str, target_url: str) -> Dict:
    """Load the test data from the JSON file.

    The reference and target database URLs will be added to the test data if any database test is performed.

    Args:
        json_file: CITest configuration JSON file for a specific pipeline/database.
        ref_url: URL to the reference database.
        target_url: URL to the target database.

    Returns:
        Dictionary with the test data for both database and files tests.
    """
    # Load the JSON file with the tests to run and their parameters
    with open(json_file) as f:
        data = json.load(f)
    params = {"database": [], "files": []} # type: Dict
    # Load the configuration for all database tests
    if data["database"]:
        # If no reference database is passed, use the default one defined in the JSON file
        if not ref_url:
            ref_url = data["reference_db"]
        db_test_handler = TestDB.TestDB(ref_url=ref_url, target_url=target_url)
        for table in data["database"]:
            for test in data["database"][table]:
                # Add extra parameters required for the test
                test["db_test_handler"] = db_test_handler
                test["table"] = table
                params["database"].append(test)
    # TODO: load all files tests (once class is available)
    return params
