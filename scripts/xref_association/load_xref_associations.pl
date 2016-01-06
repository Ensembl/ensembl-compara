#!/bin/env perl
# Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

use warnings;
use strict;
use Getopt::Long qw(:config pass_through);
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Compara::DBSQL::XrefAssociationAdaptor;

my ($reg_conf, $division, $help, $compara_name, $db_name, $species,
	$summary);

GetOptions('help'               => \$help,
		   'compara|c=s'        => \$compara_name,
		   'db_name|n=s'        => \$db_name,
		   'species|s=s'        => \$species,
		   'reg_conf|regfile=s' => \$reg_conf,);

if ($help or !$reg_conf or !$compara_name or !$db_name) {
  pod2usage(1);
}

Bio::EnsEMBL::Registry->load_all($reg_conf);
#Bio::EnsEMBL::Registry->set_disconnect_when_inactive(1);

# get compara database
my ($compara) = grep { $_->dbc()->dbname() eq $compara_name }
  @{Bio::EnsEMBL::Registry->get_all_DBAdaptors(-GROUP => 'compara')};

my $adaptor =
  Bio::EnsEMBL::Compara::DBSQL::XrefAssociationAdaptor->new($compara);
my $gdb = $compara->get_GenomeDBAdaptor();
my @genome_dbs =
  grep { $_->name() ne 'ancestral_sequences' } @{$gdb->fetch_all()};
if (defined $species) {
  @genome_dbs = grep { $_->name() eq $species } @genome_dbs;
}
for my $genome_db (@genome_dbs) {
  my $dba = $genome_db->db_adaptor();
  if (defined $dba) {
	print "Processing " . $dba->species() . "\n";
	$compara->dbc()->sql_helper()->execute_update(
	  -SQL => q/delete mx.* from member_xref mx 
join external_db e using (external_db_id) 
join gene_member m using (gene_member_id) 
join genome_db g using (genome_db_id) where e.db_name=? and g.name=?/,
	  -PARAMS => [$db_name, $dba->species()]);
	$adaptor->store_member_associations($dba, $db_name);
  }
  print "Completed processing " . $dba->species() . "\n";
  $dba->dbc()->disconnect_if_idle();
}
