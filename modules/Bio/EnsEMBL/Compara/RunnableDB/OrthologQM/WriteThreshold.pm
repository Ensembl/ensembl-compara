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

Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::WriteThreshold

=head1 SYNOPSIS

	Write the threshold for "high quality" orthologs for each mlss_id to method_link_species_set_tag

=head1 DESCRIPTION

	Right now, we're using a static cutoff of 50. This may change.
	Takes only 'mlss' as an input id

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::WriteThreshold;

use strict;
use warnings;
use Data::Dumper;
use DBI;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 write_output

	Description: write threshold to mlss_tag

=cut

sub write_output {
	my $self = shift;
	my @mlss_ids = @{ $self->param('mlss') };

	my $dba = $self->get_cached_compara_dba('pipeline_url');
	# my $dba;
	# if ( $self->param('alt_aln_db') ) { $dba = $self->get_cached_compara_dba('alt_aln_db'); }
	# else { $dba = $self->compara_dba }

	# write threshold to mlss_tag
	my $mlss_adap = $dba->get_MethodLinkSpeciesSetAdaptor;
	for my $this_mlss ( @mlss_ids ) {
		my $mlss = $mlss_adap->fetch_by_dbID( $this_mlss );
		unless ( defined $mlss ) {
			warn "Could not find mlss with dbID $this_mlss\n";
			next;
		}
		$mlss->store_tag( 'wga_quality_threshold', $self->_calculate_threshold ) if defined $mlss;
	}
}

sub _calculate_threshold {
	return 50;
}

1;