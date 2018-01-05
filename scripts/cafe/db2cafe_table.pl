#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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


# This table will serve both for cafe and as a general table of families descriptions.
use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;

use Bio::EnsEMBL::Registry;
#use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
# select * from method_link_species_set where method_link_species_set_id = 40074;
# select * from species_set where species_set_id = 33880;
my $reg = "Bio::EnsEMBL::Registry";

my $help;
my $host = "127.0.0.1";
my $port = "2914";
my $user = "ensadmin";
my $pass = $ENV{'ENSADMIN_PSW'};
my $dbname = "lg4_ensembl_compara_64";
my $url;
my $mlss = 40076;
my $exclude_lcg = 0;
my $registry_file;
my $compara_url;

GetOptions(
	   "h|help" => \$help,
	   "url=s" => \$url,
	   "compara_url=s" => \$compara_url,
	   "conf|registry=s" => \$registry_file,
	   "mlss:i" => \$mlss,
	   "lcg" => \$exclude_lcg,
	   "db" => \$dbname,
	   "host" => \$host,
	  );

if ($help) {
  print <<'EOH';
db2cafe_table.pl -- Get a table compatible for cafe with family frequencies (by genome db)

Options
    [-h|--help]                   Prints this document and exits

 [DB Connection]
    --url <string>           Database url location of the form,
                             mysql://username[:password]\@host[:port]/[release_version]
                             you can also set the connection through the host/port/pass/user/db options (below)
    --compara_url <string>   Compara URL
    --[conf|registry]        Registry file
    --host <string>          Host server
    --port <integer>         Server port
    --pass <string>          Server password
    --user <string>          Server user
    --db <string>            Database name

 [Other options]
    --mlss <integer>         Method link species set in the compara database
    --lcg                    Use this option to filter out low-coverage genomes

EOH
exit(0);

}

if ($registry_file) {
  $reg->load_all($registry_file, 0, 0, 0, "throw_if_missing");
} elsif ($url) {
  $reg->load_registry_from_url($url);
} elsif (!$compara_url) {
  $reg->load_all();
}

$reg->no_version_check(1);

my $compara_dba;
if ($compara_url) {
  use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
  $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$compara_url);
} elsif ($host) {
  $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(
							     -host => $host,
							     -port => $port,
							     -user => $user,
							     -dbname => $dbname,
							     -verbose => 1,
							     -pass => $pass
							    );
} else {
  $compara_dba = $reg->get_DBAdaptor("Multi", "compara");
}

# Get all the species for the mlss:
my $method_link_species_set = $compara_dba->get_MethodLinkSpeciesSetAdaptor()->fetch_by_dbID($mlss);
my $genome_dbs = $method_link_species_set->species_set->genome_dbs();

my @sps_set = @$genome_dbs;
if ($exclude_lcg) {
  my $ss = $compara_dba->get_SpeciesSetAdaptor()->fetch_all_by_name('low-coverage')->[0];
  my %in_ss = map {$_->dbID => 1} @{$ss->genome_dbs};
  @sps_set = grep {!$in_ss{$_->dbID}} @$genome_dbs;
}

my @species_names = map {(split /_/, $_->name)[0]} @sps_set;

# Get the number of members per family
my $tree_adaptor = $compara_dba->get_GeneTreeAdaptor();
my $all_trees = $tree_adaptor->fetch_all(-tree_type => 'tree', -method_link_species_set_id => $mlss, -clusterset_id => 'default');
my $sth = $tree_adaptor->prepare('SELECT genome_db_id FROM gene_tree_node JOIN seq_member USING (seq_member_id) WHERE root_id = ?');
print "FAMILYDESC\tFAMILY\t", join("\t", @species_names), "\n";
for my $tree (@$all_trees) {
  my $root_id = $tree->root_id();
  my $model_name = $tree->stable_id() || $tree->get_value_for_tag('model_name') || $root_id;
  $sth->execute($root_id);

  my %species;
  while (my $row = $sth->fetchrow_arrayref) {
    $species{$row->[0]}++;
  }

  my @flds = ($model_name, $root_id, map {$species{$_->dbID} || 0} @sps_set);
  print join ("\t", @flds), "\n";
}

