
import argparse
from ensembl.compara.citest.citest import CITest


parser = argparse.ArgumentParser()
parser.add_argument("--url", type=str,help="URL to conect to the MySQL database")
parser.add_argument("--url_ref", type=str,help="URL to conect to the reference MySQL database")
parser.add_argument("--test", type=str,help="JSON test file",required=True)
#parser.add_argument("--hive_tables",type=str,help="JSON describing the hive tables",required=True)
parser.add_argument("--user", type=str,help="db conection user id")
parser.add_argument("--password", type=str,help="db connection password")
parser.add_argument("--server", type=str,help="Mysql server adress")
parser.add_argument("--outdir", type=str,help="out directory where to write the file", default="./")
args = parser.parse_args()

citest=CITest()
citest.init_citest(args.url_ref, args.url,args.test,args.outdir)
citest.run_citest()
citest.print_citest_results()
citest.write_citest_results_json()
