
import json

from sqlalchemy import create_engine
from sqlalchemy.sql import text
from ensembl.compara.citest.tabletest import TableTest


# This class implement  genric testing for the comparadatabase
class CITest:

        def __init__(self):

            self.url_target=""
            self.url_ref="str_url_ref"

            self.target_connection_engine=None
            self.ref_connection_engine=None

            self.test_parameters=None
            self.table_test_results=[]
            self.file_test_results=[]

            self.out_file=""


        def init_citest(self, str_url_ref, str_url_target, str_test_pipeline_file, str_out_dir,bool_log=False):
            self.url_target=str_url_target
            self.url_ref=str_url_ref
            self.target_connection_engine = create_engine(self.url_target, echo=bool_log)
            self.ref_connection_engine= create_engine(self.url_ref, echo=bool_log)

            # load check parameters for the given pipeline
            self.test_parameters=self._parse_json_file(str_test_pipeline_file)
            str_pipeline_name=self.test_parameters["Pipeline_citest"]["pipeline_name"]
            self.out_file=str_out_dir+"/"+str_pipeline_name+".tst"


        def _parse_json_file(self, str_file_path):
            obj_file=open(str_file_path)
            obj_jason=json.loads(obj_file.read())
            return obj_jason


        def run_citest(self):
            #run check on database tables of the pipeline
            lst_table_tests=self.test_parameters["Pipeline_citest"]["tables"]
            str_pipeline_name=self.test_parameters["Pipeline_citest"]["pipeline_name"]

            if not lst_table_tests ==[]:
                obj_table_test=TableTest()
                dic_argument={}
                dic_argument["str_pipeline_name"]=str_pipeline_name
                dic_argument["obj_ref_connection_engine"]=self.ref_connection_engine
                dic_argument["obj_target_connection_engine"]=self.target_connection_engine
                dic_argument["lst_table_tests"]=lst_table_tests
                obj_table_test.initialise_tests(dic_argument)
                obj_table_test.run_tests()
                self.table_test_results=obj_table_test.test_results

            #run check on output files of the pipeline
            lst_file_tests=self.test_parameters["Pipeline_citest"]["files"]
            if not lst_file_tests ==[]:
                pass


        def print_citest_results(self):
            str_pipeline_name=self.test_parameters["Pipeline_citest"]["pipeline_name"]
            for dic_result in self.table_test_results:
                lst_to_string=[str_pipeline_name,dic_result["table"],dic_result["type"],str(dic_result["succes"]), dic_result["info"]]
                str_line="\t".join(lst_to_string)
                print(str_line)
            for dic_result in self.file_test_results:
                pass


        def write_citest_results_tabular(self):
            str_pipeline_name=self.test_parameters["Pipeline_citest"]["pipeline_name"]
            with open(self.out_file,"w") as obj_file:
                for dic_result in self.table_test_results:
                    str_line="\t".join([str_pipeline_name,dic_result["table"],dic_result["type"],str(dic_result["succes"]), dic_result["info"]])
                    obj_file.write(str_line+"\n")
                for dic_result in self.file_test_results:
                    pass


        def write_citest_results_json(self):
            str_pipeline_name=self.test_parameters["Pipeline_citest"]["pipeline_name"]
            data={'pipeline_result':str_pipeline_name,'table_results': [],'file_results': [] }

            for dic_result in self.table_test_results:
                data['table_results'].append(dic_result)
            for dic_result in self.file_test_results:
                data['file_results'].append(dic_result)

            with open(self.out_file+".json","w") as obj_file:
                json.dump(data, obj_file)
