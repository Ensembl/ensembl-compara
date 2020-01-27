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

from collections import OrderedDict
import json
import os
import re
from typing import Dict

import pytest
from _pytest.config import Config
from _pytest.config.argparsing import Parser
from _pytest.fixtures import FixtureRequest
from _pytest.main import Session
from _pytest.python import Metafunc
from _pytest.runner import CallInfo, TestReport

from ensembl.compara.citest import TestDB, TestFiles


def pytest_addoption(parser: Parser) -> None:
    """Register argparse-style options for the test run.

    Args:
        parser: Command line option parser.
    """
    parser.addoption("--pipeline", action="store", metavar="NAME", dest="pipeline_name",
                     help="name of the pipeline to be tested (without '_conf' suffix)")
    parser.addoption("--json-file", action="store", metavar="JSON_FILE", dest="json_file",
                     help="CITest configuration JSON file")
    parser.addoption("--ref-url", action="store", metavar="URL", dest="ref_url",
                     help="URL to the reference database")
    parser.addoption("--target-url", action="store", required=True, metavar="URL", dest="target_url",
                     help="URL to the target database")
    parser.addoption("--ref-path", action="store", metavar="URL", dest="ref_path",
                     help="Absolute path to reference's root directory")
    parser.addoption("--target-path", action="store", required=True, metavar="URL", dest="target_path",
                     help="Absolute path to target's root directory")


def pytest_generate_tests(metafunc: Metafunc) -> None:
    """Generate (multiple) parametrized calls to a test function.

    Args:
        metafunc: Container of the test configuration values.
    """
    config_filename = get_config_filename(metafunc.config)
    ref_url = metafunc.config.getoption("ref_url")
    target_url = metafunc.config.getoption("target_url")
    ref_path = metafunc.config.getoption("ref_path")
    target_path = metafunc.config.getoption("target_path")
    test_data = get_test_data(config_filename, ref_url, target_url, ref_path, target_path)
    # Load the parameters for each test
    if "db_test_data" in metafunc.fixturenames:
        metafunc.parametrize("db_test_data", test_data["database_tests"], indirect=True)
    elif "files_test_data" in metafunc.fixturenames:
        metafunc.parametrize("files_test_data", test_data["files_tests"], indirect=True)


@pytest.fixture()
def db_test_data(request: FixtureRequest) -> Dict:
    """Fixture to retrieve the database test data.

    Args:
        request: Special fixture providing information of the requesting test function.

    Returns:
        Dictionary with the database test data. Keys "test_db_handler", "test" and "table" will always be
        present.
    """
    return request.param


@pytest.fixture()
def files_test_data(request: FixtureRequest) -> Dict:
    """Fixture to retrieve the files test data.

    Args:
        request: Special fixture providing information of the requesting test function.

    Returns:
        Dictionary with the files test data. Keys "test_files_handler" and "test" will always be present.
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

    Note:
        No report will be generated if no tests have been run.

    Args:
        session: Pytest Session object.
        existatus: Status which pytest will return to the system.
    """
    report_list = [report for report in session.report.values()]
    total = len(report_list)
    failed = 0
    if total:
        # Use the configuration JSON file as template for the report
        config_filename = get_config_filename(session.config)
        with open(config_filename) as f:
            full_report = json.load(f, object_pairs_hook=OrderedDict)
        # Add the target information
        full_report["target_db"] = session.config.getoption("target_url")
        full_report["target_dir"] = session.config.getoption("target_path")
        # Add the reported information of each test
        for report in report_list:
            test_run = re.sub(r'\[.*\]', '', report.location[-1])
            if test_run.endswith("db"):
                test_list = full_report["database_tests"][report.test_args["table"]]
            else:
                test_list = full_report["files_tests"]
            for test in test_list:
                if (test["test"] == report.test_args["test"]) and (test["args"] == report.test_args["args"]):
                    test["status"] = report.outcome.capitalize()
                    if report.failed:
                        failed += 1
                        test["error"] = OrderedDict([("message", report.longrepr.reprcrash.message)])
                        if report.error_info:
                            test["error"]["details"] = report.error_info
                    break
        # Save full report in a JSON file
        report_filename = os.path.basename(config_filename).rsplit(".", 1)[0] + ".report.json"
        # Make sure not to overwrite previous reports
        if os.path.isfile(report_filename):
            i = 1
            while os.path.isfile("{}.{}".format(report_filename, i)):
                i += 1
            report_filename = "{}.{}".format(report_filename, i)
        with open(report_filename, "w") as f:
            json.dump(full_report, f, indent=4)
    # Print summary
    print("\n{} out of {} tests ok".format(total - failed, total))


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
    if report.when == "call":
        # Update the test report adding our custom report_info
        report.error_info = getattr(item, "error_info", 0)
        if "db_test_data" in item.fixturenames:
            report.test_args = item.funcargs["db_test_data"]
        elif "files_test_data" in item.fixturenames:
            report.test_args = item.funcargs["files_test_data"]
        item.session.report[item] = report


def get_test_data(config_file: str, ref_url: str, target_url: str, ref_path: str, target_path: str) -> Dict:
    """Read and prepare the test data from the JSON file.

    The reference and target database URLs will be added to the test data if any database test is performed.

    Args:
        config_file: CITest configuration JSON file for a specific pipeline/database.
        ref_url: URL to the reference database.
        target_url: URL to the target database.
        ref_path: Absolute path to reference's root directory.
        target_path: Absolute path to target's root directory.

    Returns:
        Dictionary with the test data for both database and files tests.

    Raises:
        AssertionError: If "test" or "args" keys are missing in any test.
    """
    params = {"database_tests": [], "files_tests": []} # type: Dict
    # Load the JSON file with the tests to run and their parameters
    with open(config_file) as f:
        data = json.load(f)
    # Load the configuration for all database tests
    if "database_tests" in data:
        # If no reference database is passed, use the default one defined in the JSON file
        if not ref_url:
            ref_url = data["reference_db"]
        test_db_handler = TestDB.TestDB(ref_url=ref_url, target_url=target_url)
        for table, test_list in data["database_tests"].items():
            for test in test_list:
                # Ensure the two main keys are present in every test
                assert "test" in test, "Missing key 'test' in database_tests['{}'].".format(table)
                assert "args" in test, "Missing key 'args' in database_tests['{}']['{}'].".format(
                    table, test["test"])
                # Add the extra parameters required for each test
                test["test_db_handler"] = test_db_handler
                test["table"] = table
                params["database_tests"].append(test)
    # Load the configuration for all files tests
    if "files_tests" in data:
        # If no reference root directory is passed, use the default one defined in the JSON file
        if not ref_path:
            ref_path = data["reference_dir"]
        test_files_handler = TestFiles.TestFiles(ref_path=ref_path, target_path=target_path)
        for test in data["files_tests"]:
            # Ensure the two main keys are present in every test
            assert "test" in test, "Missing key 'test' in one test of files_tests."
            assert "args" in test, "Missing key 'args' in files_tests['{}'].".format(test["test"])
            # Add the extra parameters required for each test
            test["test_files_handler"] = test_files_handler
            params["files_tests"].append(test)
    return params


def get_config_filename(config: Config) -> str:
    """Get the CITest configuration JSON file path from the configuration values.

    Args:
        config: Access to configuration values (command line options), pluginmanager and plugin hooks.

    Returns:
        Path to the CITest configuration JSON file.

    Raises:
        RuntimeError: If --pipeline and --json-file arguments are missing (one required).
    """
    pipeline_name = config.getoption("pipeline_name")
    if pipeline_name:
        config_file = os.path.join(os.environ['ENSEMBL_CVS_ROOT_DIR'], "ensembl-compara", "conf", "citest",
                                   "pipelines", pipeline_name + ".json")
    else:
        config_file = config.getoption("json_file")
    if not config_file:
        raise RuntimeError("One of the following arguments is required: --pipeline or --json-file")
    return config_file
