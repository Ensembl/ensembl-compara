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

Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Fetch_genetic_distance

=head1 DESCRIPTION

Take as input the mlss id of a pair of species
use the mlss id to get the species genome db ids and then get their last common ancester node object and uses that to get their genetic distance

Example run

  standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Fetch_genetic_distance  -goc_mlss_id <>

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Fetch_genetic_distance;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {

	my $self = shift;
	my $mlss_id = $self->param_required('goc_mlss_id');
	$self->param('mlss_adaptor', $self->compara_dba->get_MethodLinkSpeciesSetAdaptor);
  my $mlss = $self->param('mlss_adaptor')->fetch_by_dbID($mlss_id);

  $self->param('homology_adaptor', $self->compara_dba->get_HomologyAdaptor);
	my $homology = $self->param('homology_adaptor')->fetch_all_by_MethodLinkSpeciesSet($mlss);
  $self->param('species_tree_adap' , $self->compara_dba->get_SpeciesTreeAdaptor );

  my $species_tree_root_id = $homology->[0]->species_tree_node()->_root_id();

  $self->param('species_tree', $self->param('species_tree_adap')->fetch_by_root_id($species_tree_root_id));

	$self->param('mlss', $mlss);
  $self->param('genome_dbs' , $mlss->species_set()->genome_dbs());

  print "------------START OF Fetch_genetic_distance ------------\n mlss_id --------- $mlss_id \n" if ($self->debug);
  

}

sub run {

  my $self = shift;

  #get genetic distance 

  $self->param('genetic_dist', $self->_get_genetic_dist());

}

sub write_output {

  my $self = shift;
  $self->dataflow_output_id( {'genetic_distance' => $self->param('genetic_dist')} , 1);
    
}


sub _get_genetic_dist {
    my $self = shift;

    my $lca_node = $self->param('species_tree')->find_lca_of_GenomeDBs( $self->param('genome_dbs') );

    my $genetic_dist = $lca_node->get_divergence_time() || 101;
    print "\n\n  GENETIC DISTANCE :  $genetic_dist \n\n" if ( $self->debug >3 );
    return $genetic_dist;
} ## end sub _get_genetic_dist




1;
