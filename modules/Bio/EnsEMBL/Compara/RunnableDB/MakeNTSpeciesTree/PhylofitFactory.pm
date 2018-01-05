=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::PhylofitFactory

=cut

=head1 SYNOPSIS

=cut



package Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::PhylofitFactory;

use strict;
use warnings;

use Data::Dumper;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
 my $self = shift @_;
 
my $prev_compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor( 
 %{ $self->param('previous_compara_db') } );


 my $gab_a = $prev_compara_dba->get_GenomicAlignBlockAdaptor;

 my @genomic_align_block_ids;

 my $mlss_id = $self->param('msa_mlssid');

 my $sql1 = "SELECT COUNT(*) FROM species_set ss ". 
            "INNER JOIN method_link_species_set ".
            "mlss ON mlss.species_set_id = ss.species_set_id ". 
            "WHERE mlss.method_link_species_set_id = ?";

 my $sth1 = $gab_a->dbc->prepare("$sql1");

 $sth1->execute("$mlss_id");

 my $count = $sth1->fetchall_arrayref()->[0]->[0];
 
 # only use alignments with a reasonable number of species
 my $sql2 = "SELECT gab.genomic_align_block_id 
            FROM genomic_align_block gab 
            INNER JOIN genomic_align ga ON
            ga.genomic_align_block_id = gab.genomic_align_block_id 
            INNER JOIN dnafrag df ON df.dnafrag_id = ga.dnafrag_id
            WHERE ga.method_link_species_set_id = ? GROUP BY 
            gab.genomic_align_block_id HAVING COUNT(distinct(df.genome_db_id)) = ?";
 
 my $sth2 = $gab_a->dbc->prepare("$sql2");

 $sth2->execute($mlss_id, $count);
 while(my $genomic_align_block_id = $sth2->fetchrow_array){
  my $genomic_align_block = $gab_a->fetch_by_dbID($genomic_align_block_id);
   # if the alignments consist of ancestral sequences - skip these 
   next if $genomic_align_block->genomic_align_array->[0]->dnafrag->genome_db->name eq "ancestral_sequences";
   push @genomic_align_block_ids, { 'block_id' => $genomic_align_block->dbID, 'tree_mlss_id' => $mlss_id};
 }

 $self->param('gab_ids', \@genomic_align_block_ids);
}

sub write_output {
 my $self = shift @_;
 $self->dataflow_output_id($self->param('gab_ids'), 2); 
}

1;
