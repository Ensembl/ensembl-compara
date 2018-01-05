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

Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::StoreGocStatsAsMlssTags

=head1 DESCRIPTION

Take as input the mlss id of a pair of species
use the mlss id to query homology table 
store distribution of goc score as tags in the mlss_tag table

Example run

  standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::StoreGocStatsAsMlssTags -genome_db_id <genome_db_id> -goc_mlss_id <>

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::StoreGocStatsAsMlssTags;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
	my $self = shift;
	my $mlss_id = $self->param_required('goc_mlss_id');
  my $thresh = $self->param_required('goc_threshold');
  my $goc_dist = $self->param_required('goc_dist');
  my $perc_above_thresh = $self->param_required('perc_above_thresh');
	print "11111111111111111111 \n  mlss id ------ $mlss_id   \n 111111111111111111111111111111111111111\n\n" if ( $self->debug );
	print Dumper($goc_dist) if ( $self->debug );

	$self->param('mlss_adaptor', $self->compara_dba->get_MethodLinkSpeciesSetAdaptor);
	my $mlss = $self->param('mlss_adaptor')->fetch_by_dbID($mlss_id);
	$self->param('mlss', $mlss);
  $self->param('threshold', $thresh);
  $self->param('goc_distribution', $goc_dist);
  $self->param('percentage_above_thresh' , $perc_above_thresh);
}

sub write_output {
  	my $self = shift @_;

  	my $mlss = $self->param('mlss');
  	foreach my $dist (@{$self->param('goc_distribution')}) {

  		if (! defined $dist->[0]) {
  			$mlss->store_tag("n_goc_null",               $dist->[1]);
  		}
  		else {
			$mlss->store_tag("n_goc_$dist->[0]",               $dist->[1]);
		  }
    }

    $mlss->store_tag("goc_quality_threshold",         $self->param('threshold'));
    $mlss->store_tag("perc_orth_above_goc_thresh",    $self->param('percentage_above_thresh'));

}

1;
