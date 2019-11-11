

###################################
# Base class for a test in citest
#
class Test:

    #constructor
    def __init__(self):
        self.test_results=[]
        self.pipeline_name=""

    ## This method is to be used in a initialise_tests method
    ## implemented in the child class.
    def initialise_tests(self,dic_argument):
        self.pipeline_name=dic_argument["str_pipeline_name"]

    ## This method need to be overiden in child class
    ## this is the main funciton called to run the test
    def run_tests(self):
        pass
