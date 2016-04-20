=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

   Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::StoreGocDistAsMlssTags

=head1 SYNOPSIS

=head1 DESCRIPTION
Take as input the mlss id of a pair of species
use the mlss id to query homology table 
store distribution of goc score as tags in the mlss_tag table

Example run

  standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::StoreGocDistAsMlssTags -genome_db_id <genome_db_id> -mlss_id <>

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::StoreGocDistAsMlssTags;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Bio::EnsEMBL::Registry;


=head2 param_defaults

    Description : Implements param_defaults() interface method of Bio::EnsEMBL::Hive::Process that defines module defaults for parameters. Lowest level parameters

=cut

sub param_defaults {
    my $self = shift;
    return {
            %{ $self->SUPER::param_defaults() },
#		'mlss_id'	=>	'100021',
#		'compara_db' => 'mysql://ensro@compara4/OrthologQM_test_db',
#		'compara_db' => 'mysql://ensro@compara4/wa2_protein_trees_84'
    };
}



sub fetch_input {
	my $self = shift;
	my $mlss_id = $self->param_required('mlss_id');
	my $query = "SELECT goc_score , COUNT(*) FROM homology where method_link_species_set_id =$mlss_id GROUP BY goc_score";
	my $goc_distribution = $self->compara_dba->dbc->db_handle->selectall_arrayref($query);
	$self->param('goc_dist', $goc_distribution);

	print "11111111111111111111111111111111111111111111111111111111111\n\n" if ( $self->debug );
	print Dumper($goc_distribution) if ( $self->debug );

	$self->param('mlss_adaptor', $self->compara_dba->get_MethodLinkSpeciesSetAdaptor);
	my $mlss = $self->param('mlss_adaptor')->fetch_by_dbID($mlss_id);
	$self->param('mlss', $mlss);

}

sub write_output {
  my $self = shift @_;

  my $mlss = $self->param('mlss');
  foreach my $dist (@{$self->param('goc_dist')}) {
	  $mlss->store_tag("goc_$dist->[0]",               $dist->[1]);

	}
}

1;