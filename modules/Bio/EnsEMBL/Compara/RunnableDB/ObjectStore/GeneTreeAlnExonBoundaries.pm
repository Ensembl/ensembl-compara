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

=cut

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ObjectStore::GeneTreeAlnExonBoundaries

=head1 DESCRIPTION

This eHive Runnable prepares a data-structure holding the exon boundaries
for a given GeneTree.
The data are used by the web-site

Required parameters:
 - gene_tree_id: the root_id of the GeneTree

Branch events:
 - #1: autoflow on success (eHive default)

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ObjectStore::GeneTreeAlnExonBoundaries;

use strict;
use warnings;

use JSON;

use Bio::EnsEMBL::Compara::Utils::Preloader;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


## Fetch the alignment from the database
sub fetch_input {
    my $self = shift @_;

    $self->dbc and $self->dbc->disconnect_if_idle();

    my $gene_tree_id    = $self->param_required('gene_tree_id');
    my $tree_adaptor    = $self->compara_dba->get_GeneTreeAdaptor;
    my $gene_tree       = $tree_adaptor->fetch_by_dbID( $gene_tree_id ) or die "Could not fetch gene_tree with gene_tree_id='$gene_tree_id'";
    my $alignment       = $gene_tree->alignment();

    $self->param('alignment', $alignment);
    $self->param('gene_tree', $gene_tree);
}

## Compute the alignment strings and exon lengths, and stringify the result
sub run {
    my $self = shift @_;

    $self->dbc and $self->dbc->disconnect_if_idle();

    my $alignment = $self->param('alignment');
    my $exon_boundaries_struct = {};
    foreach my $aligned_member (@{$alignment->get_all_Members()}) {
        my $aligned_sequence_bounded_by_exon = $aligned_member->alignment_string('exon_bounded');
        my @bounded_exons = split ' ', $aligned_sequence_bounded_by_exon;
        pop @bounded_exons;

        my $aligned_exon_lengths = [ map length ($_), @bounded_exons ];

        my $aligned_exon_positions = [];
        my $exon_end;
        for my $exon_length (@$aligned_exon_lengths) {
            $exon_end += $exon_length;
            push @$aligned_exon_positions, $exon_end;
        }

        # The key here is a seq_member_id
        $exon_boundaries_struct->{$aligned_member->dbID()} = {
            'num_exons' => scalar @$aligned_exon_positions,
            'positions' => $aligned_exon_positions,
        };
    }

    # Serialize in JSON
    my $jf = JSON->new()->pretty(0);
    my $exon_boundaries_json = $jf->encode($exon_boundaries_struct);
    $self->param('exon_boundaries_json', $exon_boundaries_json);
}

## Store the data in the database
sub write_output {
    my $self = shift @_;

    $self->dbc and $self->dbc->disconnect_if_idle();

    $self->compara_dba->get_GeneTreeObjectStoreAdaptor->store($self->param('gene_tree_id'), 'exon_boundaries', $self->param('exon_boundaries_json'))
        || die "Nothing was stored in the database for gene_tree_id=".$self->param('gene_tree_id');
}

1;
