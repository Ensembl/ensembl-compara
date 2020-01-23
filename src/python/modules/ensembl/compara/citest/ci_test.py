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
"""Module docstring"""
# TODO: write module docstring

from typing import Dict

import pytest
from _pytest.fixtures import FixtureRequest


def test_pipeline_db(request: FixtureRequest, db_test_data: Dict) -> None:
    """Test the database side of the pipeline.

    Args:
        request: Special fixture providing information of the requesting test function.
        db_test_data: Database test data (fixture).
    """
    test_db_handler = db_test_data["test_db_handler"]
    test_method = "test_" + db_test_data["test"]
    getattr(test_db_handler, test_method)(request, db_test_data["table"], **db_test_data["args"])


def test_pipeline_files(request: FixtureRequest, files_test_data: Dict) -> None:
    """Test the file system side of the pipeline.

    Args:
        request: Special fixture providing information of the requesting test function.
        files_test_data: Files test data (fixture).
    """
    test_files_handler = files_test_data["test_files_handler"]
    test_method = "test_" + files_test_data["test"]
    getattr(test_files_handler, test_method)(request, **files_test_data["args"])
