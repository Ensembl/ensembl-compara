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
"""
 Module describing the baseclass for CITest test.

 this is an abstract class and need to be implemented
 in a child class specifying the type of test (SQL, file, trees...)
"""

from abc import ABC, abstractmethod

class Test(ABC):
    """
    Abstract class for test in citest
    """

    def __init__(self):
        """constructor
        """
        self.test_results = []
        self.pipeline_name = ""

    def initialise_tests(self, dic_argument):
        """Initialise a CITest test

        This method initialise a test type using parameters given in argument

        Args:
            dic_argument: dictionary with argument used for the initialisation.
                          It has to have "str_pipeline_name" key valorised
        Returns:
            None
        """
        self.pipeline_name = dic_argument["str_pipeline_name"]

    @abstractmethod
    def run_tests(self):
        """Main function to run the test

        This method has to be implemented in the child class

        Args:
            None

        Returns:
            None
        """
        return
