# regarding copyright ownership.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Utils::Test qw(standaloneJob);
use Bio::EnsEMBL::Hive::DBSQL::DBConnection;
use Bio::EnsEMBL::Test::MultiTestDB;

use Test::Most;

use Cwd 'abs_path';

BEGIN {
    # Check module can be seen and compiled
    use_ok('Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::MakeDiamondDBPerGenomeDB');
}

# Load test DB
my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('homology_annotation');
my $dba = $multi_db->get_DBAdaptor('compara');
my $dbc = Bio::EnsEMBL::Hive::DBSQL::DBConnection->new(-dbconn => $dba->dbc);
my $compara_db = $dbc->url;

my $genome_db_id = 135;
my $genome_db    = $dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id);
# Species fasta inputfile
my $test_fasta_dir = abs_path($0);
$test_fasta_dir    =~ s!makeDiamondDBPerGenomeDB\.t!homology_annotation_input!;
my $exp_fasta = $genome_db->_get_members_dump_path($test_fasta_dir);
my $query_db_name = $exp_fasta;
$query_db_name =~ s/\.fasta$//;

# Expected dataflow output
my $exp_dataflow = {
    'genome_db_id'  => '135',
    'query_db_name' => $query_db_name,
};

standaloneJob(
    'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::MakeDiamondDBPerGenomeDB',
    # Input parameters
    {
        'compara_db'        => $compara_db,
        'members_dumps_dir' => $test_fasta_dir,
        'fasta_file'        => $exp_fasta,
        'genome_db_id'      => $genome_db_id,
        'dry_run'           => 1,
        'diamond_exe'       => 'diamond',
    },
    # Output
    [
        [
            'WARNING',
            "diamond makedb --in $exp_fasta -d $query_db_name has not been executed"
        ],
        [
            'DATAFLOW',
            $exp_dataflow,
            1
        ],
    ]
);

# Check fasta file is written
ok(-e $exp_fasta, "fasta file exists");
unlink $exp_fasta;

done_testing();
