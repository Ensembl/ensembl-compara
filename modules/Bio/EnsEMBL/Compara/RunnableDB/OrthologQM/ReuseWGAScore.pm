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

Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::ReuseWGAScore

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::ReuseWGAScore;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub write_output {
    my $self = shift;

    my $homo_adaptor = $self->compara_dba->get_HomologyAdaptor;
    foreach my $score_info ( @{ $self->param_required('reuse_list') } ) {
    	$homo_adaptor->update_wga_coverage( $score_info->{'homology_id'}, $score_info->{'prev_wga_score'} );
    }
}

1;
