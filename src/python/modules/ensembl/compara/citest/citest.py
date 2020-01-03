
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


"""Module describing the CITest main class.
"""

import json

from sqlalchemy import create_engine
from ensembl.compara.citest.tabletest import TableTest


class CITest:
    """This class implement generic testing for the Ensembl compara pipeline
    """

    def __init__(self):
        """constructor
        """
        self.url_target = ""
        self.url_ref = ""

        self.target_connection_engine = None
        self.ref_connection_engine = None

        self.test_parameters = None
        self.table_test_results = []
        self.file_test_results = []

        self.out_file = ""


    def init_citest(self, str_url_ref, str_url_target, str_test_pipeline_file,
                    str_out_dir, bool_log=False):
        """Initialise citest parameters
        Args:
            str_url_ref: the url to the reference database (str)
            str_url_target: the url to the target database (str)
            str_test_pipeline_file: the path to the json file that describe the
            test to be done for a given pipeline (str)
            str_out_dir: path to the out directory where tosave the outfile (str)
            bool_log: flag tellin whether sql alchemy log are on or of (bool)

        Returns:
                None
        """
        self.url_target = str_url_target
        self.url_ref = str_url_ref
        self.target_connection_engine = create_engine(self.url_target, echo=bool_log)
        self.ref_connection_engine = create_engine(self.url_ref, echo=bool_log)

        # load check parameters for the given pipeline
        self.test_parameters = self._parse_json_file(str_test_pipeline_file)
        str_pipeline_name = self.test_parameters["Pipeline_citest"]["pipeline_name"]
        self.out_file = str_out_dir+"/"+str_pipeline_name+".tst"

    @staticmethod
    def _parse_json_file(str_file_path):
        """Load a json file and return its content

        Args:
            str_file_path: the file path to the json file

        Returns:
                return a dictionary representing the json data
        """
        obj_file = open(str_file_path)
        obj_jason = json.loads(obj_file.read())
        return obj_jason

    def run_citest(self):
        """Main function that run all the CITest test for a given pipeline

        Run all the CITest described in the json file describing the test
        for a given pipeline_name. At the moment this method implement DB test
        but in the future new kind of test will need to be implemented (file, trees...)

        Args:
            str_file_path: None

        Returns:
                None
        """
        #run check on database tables of the pipeline
        lst_table_tests = self.test_parameters["Pipeline_citest"]["tables"]
        str_pipeline_name = self.test_parameters["Pipeline_citest"]["pipeline_name"]

        if not lst_table_tests == []:
            obj_table_test = TableTest()
            dic_argument = {}
            dic_argument["str_pipeline_name"] = str_pipeline_name
            dic_argument["obj_ref_connection_engine"] = self.ref_connection_engine
            dic_argument["obj_target_connection_engine"] = self.target_connection_engine
            dic_argument["lst_table_tests"] = lst_table_tests
            obj_table_test.initialise_tests(dic_argument)
            obj_table_test.run_tests()
            self.table_test_results = obj_table_test.test_results

        #run check on output files of the pipeline
        lst_file_tests = self.test_parameters["Pipeline_citest"]["files"]
        if not lst_file_tests == []:
            pass

    def print_citest_results(self):
        """This method print on the screen the CITest results

        Args:
             None

        Returns:
            None
        """
        str_pipeline_name = self.test_parameters["Pipeline_citest"]["pipeline_name"]
        for dic_result in self.table_test_results:
            lst_to_string = [str_pipeline_name, dic_result["table"]]
            lst_to_string = lst_to_string + [dic_result["type"], str(dic_result["success"])]
            lst_to_string = lst_to_string + [dic_result["info"]]
            str_line = "\t".join(lst_to_string)
            print(str_line)
        for dic_result in self.file_test_results:
            pass

    def write_citest_results_tabular(self):
        """This method write the CITest result in the outfile in a tabular mode

        Args:
             None

        Returns:
            None
        """
        str_pipeline_name = self.test_parameters["Pipeline_citest"]["pipeline_name"]
        with open(self.out_file, "w") as obj_file:
            for dic_result in self.table_test_results:
                lst_to_string = [str_pipeline_name, dic_result["table"], dic_result["type"]]
                lst_to_string = lst_to_string + [str(dic_result["success"]), dic_result["info"]]
                str_line = "\t".join(lst_to_string)
                obj_file.write(str_line+"\n")
            for dic_result in self.file_test_results:
                pass


    def write_citest_results_json(self):
        """This method write the CITest result in a json file

        Args:
             None

        Returns:
            None
        """
        str_pipeline_name = self.test_parameters["Pipeline_citest"]["pipeline_name"]
        data = {'pipeline_result':str_pipeline_name, 'table_results': [], 'file_results': []}

        for dic_result in self.table_test_results:
            data['table_results'].append(dic_result)
        for dic_result in self.file_test_results:
            data['file_results'].append(dic_result)

        with open(self.out_file+".json", "w") as obj_file:
            json.dump(data, obj_file)
