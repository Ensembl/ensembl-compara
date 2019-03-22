=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::SetGerpNeutralRate

=head1 DESCRIPTION

Calculate the neutral rate of the species tree for use for those alignments
where the default depth threshold is too high to call any constrained
elements (e.g. 3-way birds).

The Runnable stores the depth threshold as the "depth_threshold"
pipeline-wide parameter.  It can be overriden by setting its
'requested_depth_threshold' parameter.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::SetGerpNeutralRate;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    my ($self) = @_;
    return {
        %{ $self->SUPER::param_defaults },
        'requested_depth_threshold'         => undef,
    };
}


sub fetch_input {
    my( $self) = @_;

    if (defined $self->param('requested_depth_threshold')) {
        $self->param('computed_depth_threshold', $self->param('requested_depth_threshold'));
        return;
    }

    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->param_required('mlss_id'));

    if (($mlss->name =~ /(sauropsid|bird)/i) || ($self->dbc && ($self->dbc->dbname =~ /(sauropsid|bird)/i))) {
        # A bit of institutional knowledge. This value was found to be
        # better years ago, at at time we only had 3 birds
        # MM: in Mar 2019, on the 34-sauropsids alignment, this threshold
        # helps tagging 5-20% more of the genome as conserved on 10
        # species. For the other 24 species, the CEs are ~5% shorter but
        # there are ~5% less of them, so no overall difference.
        $self->param('computed_depth_threshold', '0.35');
        return;
    }

    my $neutral_rate = 0;
    foreach my $node ($mlss->species_tree->root->get_all_subnodes) {
        $neutral_rate += $node->distance_to_parent;
    }

    my $default_depth_threshold = 0.5;
    if ($neutral_rate < $default_depth_threshold) {
        $self->param('computed_depth_threshold', $neutral_rate);
    } else {
        $self->param('computed_depth_threshold', undef);
    }
}


sub write_output {
    my ($self) = @_;

    if (defined $self->param('computed_depth_threshold')) {
        $self->dataflow_output_id({
                'param_name'    => 'depth_threshold',
                'param_value'   => $self->param('computed_depth_threshold'),
            }, 2);
    }
}

1;
