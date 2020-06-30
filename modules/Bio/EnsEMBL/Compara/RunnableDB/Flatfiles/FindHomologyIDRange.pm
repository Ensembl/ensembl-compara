=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::Flatfiles::FindHomologyIDRange

=head1 DESCRIPTION



=cut

package Bio::EnsEMBL::Compara::RunnableDB::Flatfiles::FindHomologyIDRange;

use warnings;
use strict;

use Bio::EnsEMBL::Compara::Utils::FlatFile qw(get_line_count);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my ($self) = @_;
    return {
        %{$self->SUPER::param_defaults},
        'range_index'   => 1,
        'offset'        => '#range_index#00000001',
    }
}

sub fetch_input {
    my $self = shift;

    # grab range start from pipeline_wide_parameters
    my $range_start = $self->param('homology_id_range_start');
    return if defined $range_start;

    # initialise the range if it doesn't exist yet (i.e. first job)
    $range_start = $self->param_required('offset');
}

sub run {
    my $self = shift;

    my $this_range_start = $self->param('homology_id_range_start') || $self->param_required('offset');
    $self->param('this_range_start', $this_range_start);

    my $homology_count = get_line_count($self->param('homology_flatfile')) - 1; # remove header line
    $self->param('next_range_start', $this_range_start + $homology_count);
}

sub write_output {
    my $self = shift;

    $self->db->hive_pipeline->add_new_or_update('PipelineWideParameters',
        'param_name' => 'homology_id_range_start',
        'param_value' => $self->param('next_range_start'),
    );

    $self->dataflow_output_id( {
        homology_id_start => $self->param('this_range_start'),
        homology_flatfile => $self->param('homology_flatfile'),
    }, 1 );
}

1;
