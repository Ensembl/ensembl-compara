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

my ($reg_conf, $division, $help, $compara_name, $species, $summary);

GetOptions('help'               => \$help,
		   'compara|c=s'        => \$compara_name,
		   'species|s=s'        => \$species,
		   'reg_conf|regfile=s' => \$reg_conf,);

if ($help or !$reg_conf or !$compara_name) {
  pod2usage(1);
}

my $db_name = 'GO';

Bio::EnsEMBL::Registry->load_all($reg_conf);
#Bio::EnsEMBL::Registry->set_disconnect_when_inactive(1);

# get compara database
my ($compara) = grep { $_->dbc()->dbname() eq $compara_name }
  @{Bio::EnsEMBL::Registry->get_all_DBAdaptors(-GROUP => 'compara')};

# get ontology db adaptor
my $onto_dba =
  Bio::EnsEMBL::Registry->get_DBAdaptor('Multi', 'ontology');

my $adaptor =
  Bio::EnsEMBL::Compara::DBSQL::XrefAssociationAdaptor->new($compara);
my $gdb = $compara->get_GenomeDBAdaptor();
my @genome_dbs =
  grep { $_->name() ne 'ancestral_sequences' } @{$gdb->fetch_all()};
if (defined $species) {
  @genome_dbs = grep { $_->name() eq $species } @genome_dbs;
}

my $go_sql = qq/
select distinct g.stable_id,x.dbprimary_acc
from xref x
join external_db db using (external_db_id)
join object_xref ox using (xref_id)
join translation t on (t.translation_id=ox.ensembl_id and ox.ensembl_object_type='Translation')
join transcript tc using (transcript_id)
join gene g using (gene_id)
join seq_region s on (g.seq_region_id=s.seq_region_id) 
join coord_system c using (coord_system_id)  
where db.db_name='$db_name' and c.species_id=?
UNION
select distinct g.stable_id,x.dbprimary_acc
from xref x
join external_db db using (external_db_id)
join object_xref ox using (xref_id)
join transcript tc on (tc.transcript_id=ox.ensembl_id and ox.ensembl_object_type='Transcript')
join gene g using (gene_id)
join seq_region s on (g.seq_region_id=s.seq_region_id) 
join coord_system c using (coord_system_id)  
where db.db_name='$db_name' and c.species_id=?
/;
my $go_parent_sql = qq/
SELECT DISTINCT
        parent_term.accession, parent_term.name
FROM    term parent_term
  JOIN  closure ON (closure.parent_term_id = parent_term.term_id)
  JOIN  ontology ON (closure.ontology_id = ontology.ontology_id)
  JOIN  term child_term ON (child_term.term_id=closure.child_term_id)
WHERE   child_term.accession = ?
  AND   closure.distance > -1
  AND   closure.ontology_id = parent_term.ontology_id
  AND   ontology.name = '$db_name'/;

my $go_parents = {};

sub get_go_parents {
  my ($term) = @_;
  if (!defined $go_parents->{$term}) {
	$go_parents->{$term} = $onto_dba->dbc()->sql_helper()
	  ->execute_simple(-SQL => $go_parent_sql, -PARAMS => [$term]);
  }
  return $go_parents->{$term};
}


for my $genome_db (@genome_dbs) {
  my $dba = $genome_db->db_adaptor();
  print "Processing " . $dba->species() . "\n";
$compara->dbc()->sql_helper()->execute_update(
-SQL=>q/delete mx.* from member_xref mx 
join external_db e using (external_db_id) 
join gene_member m using (gene_member_id) 
join genome_db g using (genome_db_id) where e.db_name=? and g.name=?/,
-PARAMS=>[$db_name, $dba->species()]);
  $adaptor->store_member_associations(
	$dba, $db_name,
	sub {
	  my ($compara, $core, $db_name) = @_;
	  my $member_acc_hash = {};
	  $core->dbc()->sql_helper()->execute_no_return(
		-SQL      => $go_sql,
		-CALLBACK => sub {
		  my ($gene_id, $term) = @{shift @_};
		  # iterate over parents (inclusive)
		  for my $go_term (@{get_go_parents($term)}) {
			push @{$member_acc_hash->{$gene_id}},
			  $go_term;
		  }
		  return;
		},
		-PARAMS => [$core->species_id(), $core->species_id()]);
	  return $member_acc_hash;
	});
  print "Completed processing " . $dba->species() . "\n";
  $dba->dbc()->disconnect_if_idle();
} ## end for my $genome_db (@genome_dbs)

