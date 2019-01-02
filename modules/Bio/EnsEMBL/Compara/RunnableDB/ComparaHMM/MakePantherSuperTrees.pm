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

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::MakePantherSuperTrees

=head1 DESCRIPTION

Runnable to create super-trees that link the trees of the same Panther
family. Panther idenfiers are expected to be found as "model_id" tags
and to follow the PTHR*_SF* nomenclature.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::MakePantherSuperTrees;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters');


sub param_defaults {
    return {
        'member_type'           => 'protein',
        'sort_clusters'         => 1,
        'immediate_dataflow'    => 1,
    };
}


sub fetch_input {
    my $self = shift @_;

    my $mlss_id = $self->param_required('mlss_id');
    my $gta = $self->compara_dba->get_GeneTreeAdaptor;

    my $all_trees = $gta->fetch_all(
        -MEMBER_TYPE                => $self->param('member_type'),
        -CLUSTERSET_ID              => 'default',
        -METHOD_LINK_SPECIES_SET_ID => $mlss_id,
    );
    $gta->_load_tagvalues_multiple($all_trees);

    # Group the trees when they have the same PTHR stem
    my %panther_fam;
    foreach my $tree (@$all_trees) {
        if ($tree->get_value_for_tag('model_id', '') =~ /(PTHR\d+)_SF\d+/) {
            push @{$panther_fam{$1}}, $tree;
        }
    }
    $self->param('panther_fam', \%panther_fam);

    my $all_matching_clustersets = $gta->fetch_all(
        -TREE_TYPE                  => 'clusterset',
        -MEMBER_TYPE                => $self->param('member_type'),
        -CLUSTERSET_ID              => 'default',
        -METHOD_LINK_SPECIES_SET_ID => $mlss_id,
    );
    $self->param('clusterset', $all_matching_clustersets->[0]);
}


sub write_output {
    my $self = shift @_;

    my $clusterset  = $self->param('clusterset');
    my $panther_fam = $self->param('panther_fam');

    # Do we sort the clusters by decreasing size ?
    my @cluster_list;
    if ($self->param('sort_clusters')) {
        @cluster_list = sort {scalar(@{$panther_fam->{$b}}) <=> scalar(@{$panther_fam->{$a}})} keys %$panther_fam;
    } else {
        @cluster_list = keys %$panther_fam;
    }

    foreach my $panther_id (@cluster_list) {
        $self->add_supertree($clusterset, {
                'model_id'  => $panther_id,
                'trees'     => $panther_fam->{$panther_id},
            } );
    }
}


1;
