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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::GetSplitGenes

=head1 DESCRIPTION

Takes as input the genome db ids of species of interest and outputs the total number of and the stable ids of the genes identified as split genes 
    Example run

  standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::get_split_genes -genome_db_id <genome_db_id>

=cut


package Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::GetSplitGenes;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 param_defaults

    Description : Implements param_defaults() interface method of Bio::EnsEMBL::Hive::Process that defines module defaults for parameters. Lowest level parameters

=cut

sub param_defaults {
    my $self = shift;
    return {
    	%{ $self->SUPER::param_defaults() },
#    	'genome_db_id' => 4,
#    	'compara_db' => 'mysql://ensro@compara1/mm14_protein_trees_82',
    	};
}


sub fetch_input {
    my $self = shift;
    print "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% get split genes RunnableDB\n\n" if ($self->debug);
    my $genome_db_id = $self->param_required('genome_db_id');
  
    # Fetch the split genes
    my $split_genes = $self->compara_dba->dbc->db_handle->selectall_arrayref('SELECT seq_member_id, gm.stable_id FROM split_genes sg JOIN seq_member sm USING (seq_member_id) JOIN gene_member gm USING (gene_member_id) WHERE sm.genome_db_id = ?', undef, $genome_db_id);
    $self->param('split_genes_hash', $split_genes);
    print Dumper($split_genes) if ($self->debug >3);
#    die;
}

sub run {
	my $self = shift @_;
  my $count = 0;
  my @sg_keys = @{$self->param('split_genes_hash')};
  
  for my $smid (@sg_keys) {
    print " $smid->[0]    %%%%%%%%%% $smid->[1]   %%%%%%%%%%%%%%%%%%%%%%%%%%%%\n" if ($self->debug >3);
    $self->dataflow_output_id( {'genome_db_id' => $self->param_required('genome_db_id'), 'seq_member_id' => $smid->[0], 'gene_member_stable_id' => $smid->[1], 'status' => 'split-gene' }, 2 );
    $count +=1;
#    if ($count == 10){
 #     last;
  #  }
  }

}

sub write_output {
  my $self = shift;
  
  $self->dataflow_output_id( { 'genome_db_id' => $self->param_required('genome_db_id')}, 1 );
}

1;
