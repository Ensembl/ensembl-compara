
from sqlalchemy import create_engine
from sqlalchemy.sql import text
from ensembl.compara.citest.test import Test


## This class extend the base class Test to test data into the database
## this test start with an intialisation
##
class TableTest(Test):

    def __init__(self):
        Test.__init__(self)
        self.ref_connection_engine=None
        self.target_connection_engine=None
        self.table_tests=[]


    def initialise_tests(self,dic_argument): # str_pipeline_name, obj_ref_connection, obj_target_connection, lst_table_tests):
        self.pipeline_name=dic_argument["str_pipeline_name"]
        self.ref_connection_engine=dic_argument["obj_ref_connection_engine"]
        self.target_connection_engine=dic_argument["obj_target_connection_engine"]
        self.table_tests=dic_argument["lst_table_tests"]

        ###Test that the all tables define in lst_table_tests exists in the databases
        lst_tables_database=self._get_pipeline_table(self.ref_connection_engine)
        for dic_tabl_test in self.table_tests:
            str_table_name=dic_tabl_test["name"]
            if not str_table_name in lst_tables_database:
                raise Exception("Error: table name '"+str_table_name+"' is not in the database")


    def _get_pipeline_table(self, obj_connection_engine):
            TABL_NAME=0
            lst_pipeline_table_names=[]
            str_request="SHOW TABLE STATUS WHERE Rows > 0;"
            obj_request = text(str_request)
            obj_connection=obj_connection_engine.connect()
            obj_result=obj_connection.execute(obj_request)
            for row in obj_result:
                str_table_name=row[TABL_NAME]
                lst_pipeline_table_names.append(str_table_name)
            obj_connection.close()
            return lst_pipeline_table_names


    def run_tests(self):
        for dic_tabl_test in self.table_tests:
            str_table_name=dic_tabl_test["name"]
            int_line_variation=dic_tabl_test["variation"]
            lst_group_by=dic_tabl_test["lst_group_by"]
            lst_columns=dic_tabl_test["columns"]

            #First it compare the number of row between the ref and target db
            self._test_table_number_row(str_table_name, int_line_variation)

            #test the group if defined in json
            if not lst_group_by ==[]:
                self._test_table_number_row_by_group(str_table_name, lst_group_by)

            #test field if present in json
            if not lst_columns ==[]:
                self._test_table_by_column(str_table_name,lst_columns)


    def _test_table_number_row(self, str_table_name, flt_variation):
        result={}
        #do the check for the given table
        int_nb_row_ref=self._get_number_row(self.ref_connection_engine, str_table_name)
        int_nb_row_tar=self._get_number_row(self.target_connection_engine, str_table_name)
        int_variation =int(int_nb_row_ref*flt_variation)
        if abs(int_nb_row_ref - int_nb_row_tar) <= int_variation: # if the test is succesful
            result["succes"]=1
        else:
            result["succes"]=0
        #populate results with
        str_info="ref:"+str(int_nb_row_ref)+"|"+"tar:"+str(int_nb_row_tar)+"|var:"+str(int_nb_row_ref - int_nb_row_tar)
        str_info=str_info+"|exp:"+str(int_variation)
        result["info"]=str_info
        result["table"]=str_table_name
        result["type"]="nb_row"
        self.test_results.append(result)


    def _get_number_row(self,obj_connection_engine, str_table_name):
        str_request="select count(*) from "+str_table_name+";"
        obj_request=text(str_request)
        obj_connection=obj_connection_engine.connect()
        obj_result=obj_connection.execute(obj_request)
        nbRow=0
        for tpl_row in obj_result:
            int_nb_row=tpl_row[0]
        obj_connection.close()
        return int_nb_row


    def _get_autorised_variation_by_group(self,lst_info_group, lst_variations):
            dic_variation={}
            for dic_var in lst_variations:
                dic_variation[dic_var["group"]]=dic_var["var"]
            dic_result={}
            for tpl_group in lst_info_group:
                dic_result[tpl_group[1]]=0
                if tpl_group[1] in dic_variation:
                    int_nb_var=int(tpl_group[0]*dic_variation[tpl_group[1]])
                    dic_result[tpl_group[1]]=int_nb_var
            return dic_result


    def _test_table_number_row_by_group(self, str_table_name, lst_groups):

        for dic_group in lst_groups:
            str_group_by=dic_group["name"]
            lst_variations=dic_group["variations"]

            #do the check for the given table
            lst_result_ref=self._get_number_row_by_group(self.ref_connection_engine, str_table_name, str_group_by)
            lst_result_tar=self._get_number_row_by_group(self.target_connection_engine, str_table_name, str_group_by)

            ## test if the bunber of group are similar between the two datases
            ## if not then failure and stop here the group by check
            result={}
            result["succes"]=0
            if len(lst_result_ref) == len(lst_result_tar):
                result["succes"]=1
            str_info="grp:"+str_group_by+"|ref:"+str(len(lst_result_ref))+"|tar:"+str(len(lst_result_tar))
            result["info"]=str_info
            result["table"]=str_table_name
            result["type"]="nb_row_all_grp"
            self.test_results.append(result)
            if result["succes"]==0:#if the number of group is not the same then there is no reason to continue
                return

            #load the number of autoiruied vairaiton (if group not describe in json then the variaiton expected is 0)
            dic_autorised_variation=self._get_autorised_variation_by_group(lst_result_ref, lst_variations)

            ### for aech group check that the numbers do nat variate more than autorised.
            i=0
            while i < len(lst_result_ref):
                int_variation=dic_autorised_variation[lst_result_ref[i][1]]#get the aurrised variation for the group
                result={}
                result["succes"]=0
                if abs(lst_result_ref[i][0]-lst_result_tar[i][0])<=int_variation: #if the number of each group is different
                    result["succes"]=1
                str_info="grp:"+str_group_by+"|grp_ref:"+str(lst_result_ref[i][1])+"|nb_ref:"+str(lst_result_ref[i][0])
                str_info=str_info+"|grp_tar:"+str(lst_result_tar[i][1])+"|nb_tar:"+str(lst_result_tar[i][0])+"|var:"+str(abs(lst_result_ref[i][0]-lst_result_tar[i][0]))

                result["info"]=str_info
                result["table"]=str_table_name
                result["type"]="nb_row_by_grp"
                self.test_results.append(result)
                i=i+1


    def _get_number_row_by_group(self,obj_connection_engine,str_table_name,str_group_by):
        lst_result=[]
        str_request="select count(*),"+str_group_by+" from "+str_table_name+" group by "+str_group_by+";"
        obj_request=text(str_request)
        obj_connection=obj_connection_engine.connect()
        obj_result=obj_connection.execute(obj_request)
        for tpl_res in obj_result:
            lst_result.append(tpl_res)
        obj_connection.close()
        return sorted(lst_result,key=lambda tuple: tuple[1])# return a list sorted on the group_by value


    def _test_table_by_column(self, str_table_name, lst_columns):

        # transfornm the json based column in sinmple stroing list.
        lst_col =[]
        for column in lst_columns:
            lst_col.append(column["name"])

        dic_column_ref=self._get_column_values(self.ref_connection_engine, str_table_name, lst_col)
        dic_column_tar=self._get_column_values(self.target_connection_engine, str_table_name, lst_col)

        for str_column, lst_fields_ref in dic_column_ref.items():
            lst_fields_tar=dic_column_tar[str_column]
            i=0
            result={}
            result["succes"]=1
            str_val_ref=""
            str_val_tar=""
            while i < len(lst_fields_ref):
                if lst_fields_ref[i] != lst_fields_tar[i]:
                    result["succes"]=0
                    str_val_ref=lst_fields_ref[i]
                    str_val_tar=lst_fields_tar[i]
                    break
                i=i+1
            print("succes "+str(result["succes"]))
            str_info="col:"+str_column+"|val_ref:"+str(str_val_ref)+"|val_tar:"+str(str_val_tar)
            result["info"]=str_info
            result["table"]=str_table_name
            result["type"]="column"
            self.test_results.append(result)


    def _get_column_values(self, obj_connection_engine, str_table, lst_columns):
        # init dictionary
        print("test column in table "+str_table)
        dic_column={}
        str_request=""
        if len(lst_columns)==1:
            str_request="select "+lst_columns[0]+" from "+str_table+";"
        else:
            str_request="select "+",".join(lst_columns)+" from "+str_table+";"
        obj_request=text(str_request)
        print("connecting...")
        obj_connection=obj_connection_engine.connect()
        print("execute request...")
        obj_result=obj_connection.execute(obj_request)
        print("retrieving result...")
        for str_col in obj_result.keys():
            dic_column[str(str_col)]=[]

        # convert the result by row into a result by column
        lst_column_name=obj_result.keys()
        for tpl_row in obj_result:
            i=0
            while i < len(lst_column_name):
                dic_column[str(lst_column_name[i])].append(str(tpl_row[i]))
                i=i+1
        obj_connection.close()
        # sort each column to be comparable between ref and target databases.
        for str_col, lst_val in dic_column.items():
            #i=0
            #while i < len(lst_val):
            #    if lst_val[i] is None:
            #        lst_val[i]="None"
            #    i=i+1
            dic_column[str_col]=sorted(lst_val)
        return dic_column
