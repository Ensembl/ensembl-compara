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

Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::StoreStatsAsTags

=head1 DESCRIPTION

Takes as input the genome db ids of species of interest and stores as tags the number genes shorter and longer than the average of their orthologs and the number of splits genes in the species tree node table.
    Example run

  standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::StoreStatsAsTags -genome_db_id <genome_db_id> -mlss_id <>

=cut


package Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::StoreStatsAsTags;

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
#        'compara_db' => 'mysql://ensro@compara5/wa2_GeneSetQC_trial',
    	};
}


sub fetch_input {
    my $self = shift;
    print "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% get  gene set stats RunnableDB    $self->param_required('genome_db_id')  \n\n" if ( $self->debug );

    my $genome_db_id            = $self->param_required('genome_db_id');
    my $this_genome_db          = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id);
    my $this_species_tree       = $self->compara_dba->get_SpeciesTreeAdaptor->fetch_by_method_link_species_set_id_label($self->param_required('mlss_id'), 'default');
    my $this_species_tree_node  = $this_species_tree->root->find_leaves_by_field('genome_db_id', $genome_db_id)->[0];
    
    $self->param('species_tree_node', $this_species_tree_node);

     my $short_genes = $self->compara_dba->dbc->db_handle->selectrow_array('select COUNT(*) from gene_member_qc where status = "short-gene" AND genome_db_id = ?', undef, $genome_db_id);
    $self->param('short_genes', $short_genes);
    print "  short genes   , $short_genes " if ( $self->debug );
    my $long_genes = $self->compara_dba->dbc->db_handle->selectrow_array('select COUNT(*) from gene_member_qc where status = "long-gene" AND  genome_db_id = ?', undef, $genome_db_id);
    $self->param('long_genes', $long_genes);
    print "  long genes   , $long_genes " if ( $self->debug );
    my $split_genes = $self->compara_dba->dbc->db_handle->selectrow_array('select COUNT(*) from gene_member_qc where status = "split-gene" AND  genome_db_id = ?', undef, $genome_db_id);
    $self->param('split_genes', $split_genes);
    print "  split genes   , $split_genes " if ( $self->debug );
    print "   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n" if ( $self->debug );
}


sub write_output {
  my $self = shift @_;

    my $species_tree_node       = $self->param('species_tree_node');

    $species_tree_node->store_tag('nb_long_genes',               $self->param('long_genes'));
    $species_tree_node->store_tag('nb_short_genes',               $self->param('short_genes'));
    $species_tree_node->store_tag('nb_split_genes',               $self->param('split_genes'));


}

1;

