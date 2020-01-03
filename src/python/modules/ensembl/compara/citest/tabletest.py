
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
 Module describing the class TableTest

"""


from sqlalchemy.sql import text
from ensembl.compara.citest.test import Test


## This class extend the base class Test to test data into the database
## this test start with an intialisation
##
class TableTest(Test):
    """This class implement MySQL database test comparison for CITEST_TAR

    This class inherit from the abstract class Test. It implement
    the test in CITest that compare databases.
    """

    def __init__(self):
        """constructor
        """
        Test.__init__(self)
        self.ref_connection_engine = None
        self.target_connection_engine = None
        self.table_tests = []

    def initialise_tests(self, dic_argument):
        """Initialise the table test

        This method extend the initialise_tests from the abstract class Test
        Args:
            dic_argument: this argument is a dictionary of key value the
                          compulsory keys are:
                          'str_pipeline_name' for the name of pipeline_name
                          'obj_ref_connection_engine' connection engine to the ref db
                          'obj_target_connection_engine' connection engine to the tar db
                          'lst_table_tests' list of object from json file defining table to test
            Returns:
                None

            Raises:
                Exception
        """
        self.pipeline_name = dic_argument["str_pipeline_name"]
        self.ref_connection_engine = dic_argument["obj_ref_connection_engine"]
        self.target_connection_engine = dic_argument["obj_target_connection_engine"]
        self.table_tests = dic_argument["lst_table_tests"]

        # Test that the all tables define in lst_table_tests exists
        # in the databases
        lst_tables_database = self._get_pipeline_table(self.ref_connection_engine)
        for dic_tabl_test in self.table_tests:
            str_table_name = dic_tabl_test["name"]
            if not str_table_name in lst_tables_database:
                raise Exception("Error: table name '" + str_table_name + "' is not in the database")

    @staticmethod
    def _get_title_value_line(lst_titles, lst_values):
        """Create a title value string

        This method create a title value string with the folowing format:
        'title1:value1|title2:value2|...|titlen:valuen'
        Args:
            lst_titles: this argument is the list of titles
            lst_values: this argument is the list of values. The values need to be in
                        the corresponding order of the titles.
            Returns:
                string line formated title1:value1|title2:value2|...|titlen:valuen

            Raises:
                AssertionError if lst_titles and lst_values do not have the same number of elements
        """
        # we need to make sure that the two list has the same number of elements
        assert len(lst_titles) == len(lst_values), "different number of elements in values and titles"
        str_info = "|".join("{}:{}".format(*t) for t in zip(lst_titles, lst_values))
        return str_info

    @staticmethod
    def _get_pipeline_table(obj_connection_engine):
        """Get the list of tables in the database
        Args:
            obj_connection_engine: a connection engine (complex from sqlalchemy)
        Returns:
            list of table name (list of string)
        """
        tabl_name = 0
        lst_pipeline_table_names = []
        str_request = "SHOW TABLE STATUS WHERE Rows > 0;"
        obj_request = text(str_request)
        obj_connection = obj_connection_engine.connect()
        obj_result = obj_connection.execute(obj_request)
        for row in obj_result:
            str_table_name = row[tabl_name]
            lst_pipeline_table_names.append(str_table_name)
        obj_connection.close()
        return lst_pipeline_table_names

    def run_tests(self):
        """Main function running the table tests

        For each tables intialised in initialise_tests this method will
        compare the number of row between the reference and target db
        and if some table has group by test and/or column test it will carry on
        these tests.
            Args:
                None
            Returns:
                None
        """
        for dic_tabl_test in self.table_tests:
            str_table_name = dic_tabl_test["name"]
            int_line_variation = dic_tabl_test["variation"]
            lst_group_by = dic_tabl_test["lst_group_by"]
            lst_columns = dic_tabl_test["columns"]

            #First it compare the number of row between the ref and target db
            self._test_table_number_row(str_table_name, int_line_variation)

            #test the group if defined in json
            if not lst_group_by == []:
                self._test_table_number_row_by_group(str_table_name, lst_group_by)

            #test field if present in json
            if not lst_columns == []:
                self._test_table_by_column(str_table_name, lst_columns)

    def _test_table_number_row(self, str_table_name, flt_variation):
        """Function comparing the number of row between a table in the ref and target DB

        For each tables intialised in initialise_tests this method will
        compare the number of row between the reference and target db
        and if some table has group by test and/or column test it will carry on
        these tests. The result of the test is store as dictionary
        in self.test_results attribute
            Args:
                str_table_name: the name of the table to test (str)
                flt_variation: the variation (flt)
            Returns:
                None
        """
        result = {}
        #do the check for the given table
        int_nb_row_ref = self._get_number_row(self.ref_connection_engine, str_table_name)
        int_nb_row_tar = self._get_number_row(self.target_connection_engine, str_table_name)
        int_variation = int(int_nb_row_ref*flt_variation)
        result["success"] = 0
        if abs(int_nb_row_ref - int_nb_row_tar) <= int_variation: # if the test is succesful
            result["success"] = 1

        #populate results with test information
        str_info = "ref:" + str(int_nb_row_ref) + "|" + "tar:" + str(int_nb_row_tar)
        str_info = str_info + "|var:" + str(int_nb_row_ref - int_nb_row_tar)
        str_info = str_info + "|exp:" + str(int_variation)

        lst_titles = ["ref", "tar", "var", "exp"]
        lst_values = [str(int_nb_row_ref), str(int_nb_row_tar),
                      str(int_nb_row_ref - int_nb_row_tar), str(int_variation)]
        result["info"] = self._get_title_value_line(lst_titles, lst_values)
        result["table"] = str_table_name
        result["type"] = "nb_row"
        self.test_results.append(result)

    @staticmethod
    def _get_number_row(obj_connection_engine, str_table_name):
        """Static method counting the number of row of a table

            Args:
                obj_connection_engine: the connection engine to the db
                to connect (complex from sqlalchemy)
                str_table_name: the name of the table (str)
            Returns:
                the number of row (int)
        """
        str_request = "SELECT COUNT(*) FROM "+str_table_name+";"
        obj_request = text(str_request)
        obj_connection = obj_connection_engine.connect()
        obj_result = obj_connection.execute(obj_request)
        for tpl_row in obj_result:
            int_nb_row = tpl_row[0]
        obj_connection.close()
        return int_nb_row

    @staticmethod
    def _get_autorised_variation_by_group(lst_info_group, lst_variations):
        """Static method counting the number of row of a table

            Args:
                obj_connection_engine: the connection engine to
                the db to connect (complex from sqlalchemy)
                str_table_name: the name of the table (str)
            Returns:
                the number of row (int)
        """
        dic_variation = {}
        for dic_var in lst_variations:
            dic_variation[dic_var["group"]] = dic_var["var"]
        dic_result = {}
        for tpl_group in lst_info_group:
            dic_result[tpl_group[1]] = 0
            if tpl_group[1] in dic_variation:
                dic_result[tpl_group[1]] = dic_variation[tpl_group[1]]
        return dic_result

    def _test_table_number_row_by_group(self, str_table_name, lst_groups):
        """Function comparing the number of row for each group of a 'group by'

           This function. For some groups in the 'group by' it allow some variation
           expressed as a frequency in the variation autorised. The result of the test
           is store as dictionary in self.test_results attribute

            Args:
                str_table_name: the name of the table to test (str)
                lst_groups: list of 'group by' for a given table represented
                by a list of dictionary as it a json object.
            Returns:
                None
        """
        for dic_group in lst_groups:
            str_group_by = dic_group["name"]
            lst_variations = dic_group["variations"]

            #do the check for the given table
            lst_result_ref = self._get_number_row_by_group(self.ref_connection_engine,
                                                           str_table_name,
                                                           str_group_by)
            lst_result_tar = self._get_number_row_by_group(self.target_connection_engine,
                                                           str_table_name,
                                                           str_group_by)

            ## test if the bunber of group are similar between the two datases
            result = {}
            result["success"] = 1
            lst_titles = ["grp", "ref", "tar"]
            lst_values = [str_group_by, str(len(lst_result_ref)), str(len(lst_result_tar))]
            result["info"] = self._get_title_value_line(lst_titles, lst_values)
            result["table"] = str_table_name
            result["type"] = "nb_row_grp"
            # if the number of group is not the same then faillure
            if len(lst_result_ref) != len(lst_result_tar):
                result["success"] = 0
                self.test_results.append(result)
                return

            # in this part we test that all groups have the same number
            # of element  within the accepted variation
            i = 0
            dic_autorised_variation = self._get_autorised_variation_by_group(lst_result_ref,
                                                                             lst_variations)
            while i < len(lst_result_ref):
                tpl_res_ref = lst_result_ref[i]
                tpl_res_tar = lst_result_tar[i]
                if tpl_res_ref[1] != tpl_res_tar[1]:
                    result["success"] = 0
                    lst_titles = ["ref_grp_val", "tar_grp_val"]
                    lst_values = [str(tpl_res_ref[1]), str(tpl_res_ref[2])]
                    result["info"] = self._get_title_value_line(lst_titles, lst_values)
                    self.test_results.append(result)
                    return
                flt_variation = 0.0
                #we authorise variation in the number of memebers belonging to each groups
                if tpl_res_ref[1] in dic_autorised_variation:
                    flt_variation = dic_autorised_variation[lst_result_ref[i][1]]
                if abs(tpl_res_ref[0] - tpl_res_tar[0]) > (flt_variation * tpl_res_ref[0]):
                    result["success"] = 0
                    lst_titles = ["ref_grp_val", "ref_grp_nb", "tar_grp_val", "tar_grp_nb"]
                    lst_values = [str(tpl_res_ref[1]), str(tpl_res_ref[0]),
                                  str(tpl_res_tar[1]), str(tpl_res_tar[0])]
                    result["info"] = self._get_title_value_line(lst_titles, lst_values)
                    self.test_results.append(result)
                i = i + 1
            self.test_results.append(result)

    @staticmethod
    def _get_number_row_by_group(obj_connection_engine, str_table_name, str_group_by):
        """Count the number of row of for each group from a 'group by' in a given table

            Args:
                obj_connection_engine: the connection engine to
                the db to connect (complex from sqlalchemy)
                str_table_name: the name of the table (str)
                str_group_by: the name of the column where to do a group by (str)
            Returns:
                a list of tuple (number row, group name) where number row is a int
                and group name is the value for a given group.
        """
        lst_result = []
        str_request = "SELECT COUNT(*)," + str_group_by + " FROM " + str_table_name
        str_request = str_request + " GROUP BY " + str_group_by + ";"
        obj_request = text(str_request)
        obj_connection = obj_connection_engine.connect()
        obj_result = obj_connection.execute(obj_request)
        for tpl_res in obj_result:
            lst_result.append(tpl_res)
        obj_connection.close()
        # return a list sorted on the group_by value
        return sorted(lst_result, key=lambda tuple: tuple[1])


    def _test_table_by_column(self, str_table_name, lst_columns):
        """Function comparing columns field by field between the reference and target DB

        The result of the test is store as a list of dicrtionaries in the attirbut self.test_results
            Args:
                str_table_name: the name of the table to test (str)
                lst_columns: list of columns to test (list of dictionary).
            Returns:
                None
        """
        # transfornm the json based column in sinmple stroing list.
        lst_col = []

        # extract the column name information from the JSON
        # and format it as a list of string required in _get_column_values()
        for column in lst_columns:
            lst_col.append(column["name"])

        dic_column_ref = self._get_column_values(self.ref_connection_engine,
                                                 str_table_name, lst_col)
        dic_column_tar = self._get_column_values(self.target_connection_engine,
                                                 str_table_name, lst_col)


        # in this loop we comapre the fields of each column between
        # the reference and target db. If not similar then no succes.
        for str_column, lst_fields_ref in dic_column_ref.items():
            lst_fields_tar = dic_column_tar[str_column]
            i = 0
            result = {}
            result["success"] = 1
            str_val_ref = ""
            str_val_tar = ""
            while i < len(lst_fields_ref):
                if lst_fields_ref[i] != lst_fields_tar[i]:
                    result["success"] = 0
                    str_val_ref = lst_fields_ref[i]
                    str_val_tar = lst_fields_tar[i]
                    break
                i = i + 1

            lst_titles = ["col", "val_ref", "val_tar"]
            lst_values = [str_column, str_val_ref, str_val_tar]
            result["info"] = self._get_title_value_line(lst_titles, lst_values)
            result["table"] = str_table_name
            result["type"] = "column"
            self.test_results.append(result)


    @staticmethod
    def _get_column_values(obj_connection_engine, str_table, lst_columns):
        """Get the values form the columns requested.

        This function get the value from a list of column name.
        If '*' is used as a column name it means every column. If with '*' other
        column are given then it means every column name except the one given in
        addition to '*'

            Args:
                obj_connection_engine: the connection engine to
                the db to connect (complex from sqlalchemy)
                str_table_name: the name of the table (str)
                lst_columns: list of column name (list of str)
            Returns:
                a dictionary of with the key if the column name and the value
                the list of values for this column. the value are sorted.
        """
        # init dictionary
        dic_column = {}

        #look if there is a "*" in the list of fields
        bool_tag_all = False
        for str_column in lst_columns:
            if str_column == "*":
                bool_tag_all = True

        str_request = ""
        if bool_tag_all:#if bool_tag_all is true then select all collumn from the table
            str_request = "SELECT * FROM " + str_table + ";"
        elif len(lst_columns) == 1:
            str_request = "SELECT " + lst_columns[0] + " FROM " + str_table + ";"
        else:
            str_request = "SELECT " + ",".join(lst_columns) + " FROM " + str_table + ";"

        obj_request = text(str_request)
        obj_connection = obj_connection_engine.connect()
        obj_result = obj_connection.execute(obj_request)

        for str_col in obj_result.keys():
            # if there is a "*" in the lst column then all other columns are
            # defined to be excluded so we exclud them
            if bool_tag_all and str(str_col) in lst_columns:
                continue
            dic_column[str(str_col)] = []

        # convert the result by row into a result by column
        lst_column_name = obj_result.keys()
        for tpl_row in obj_result:
            i = 0
            while i < len(lst_column_name):
                # if there is a "*" in the lst column then all other columns are
                # defined to be excluded so we exclud them
                if bool_tag_all and  str(lst_column_name[i]) in lst_columns:
                    i = i + 1
                    continue
                dic_column[str(lst_column_name[i])].append(str(tpl_row[i]))
                i = i + 1
        obj_connection.close()
        # sort each column to be comparable between ref and target databases.
        for str_col, lst_val in dic_column.items():
            dic_column[str_col] = sorted(lst_val)
        return dic_column
