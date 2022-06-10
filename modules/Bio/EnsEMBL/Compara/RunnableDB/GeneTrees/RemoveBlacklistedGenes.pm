=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RemoveBlacklistedGenes

=head1 DESCRIPTION

Removes the stable_id corresponding to a genome_db from a flat gene tree/cluster.
    The blocklist_file should follow the format:
<stable_id> <genome_db_id>
ENSTNIG00000004376 65
ENSTNIG00000004377 65

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::RemoveBlacklistedGenes;

use strict;
use warnings;
use Data::Dumper;

use Bio::EnsEMBL::Utils::IO qw/:slurp/;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $blocklist_genes_genomes = slurp_to_array($self->param_required('blocklist_file'), 1);

    # remove members related to blocklisted genes
    my $gene_member_adaptor     = $self->compara_dba->get_GeneMemberAdaptor;
    my $seq_member_adaptor      = $self->compara_dba->get_SeqMemberAdaptor;
    my $gene_tree_node_adaptor  = $self->compara_dba->get_GeneTreeNodeAdaptor;

    my @blocklist_seq_members;
    foreach my $stable_id_genome_db_id ( @$blocklist_genes_genomes ) {
        my ($stable_id, $genome_db_id) = split / /, $stable_id_genome_db_id;
        my $member = $gene_member_adaptor->fetch_by_stable_id_GenomeDB($stable_id, $genome_db_id) ||
            $seq_member_adaptor->fetch_by_stable_id_GenomeDB($stable_id, $genome_db_id) ||
            undef;
        if (! defined $member) {
            $self->warning( "Cannot find '$stable_id' for '$genome_db_id' in the database\n" );
            next;
        }

        my $aligned_member = $gene_tree_node_adaptor->fetch_default_AlignedMember_for_Member($member);
        unless ( $aligned_member ) {
            $self->warning( "Cannot find alignment for '$stable_id' for '$genome_db_id' in the database\n" );
            next;
        }
        push @blocklist_seq_members, $aligned_member;
    }

    $self->param('blocklist_seq_members', \@blocklist_seq_members);
}

sub write_output {
    my $self = shift @_;

    my $blocklist_seq_members   = $self->param('blocklist_seq_members');
    my $gene_tree_node_adaptor  = $self->compara_dba->get_GeneTreeNodeAdaptor;
    my $gene_tree_adaptor       = $self->compara_dba->get_GeneTreeAdaptor;

    print Dumper $blocklist_seq_members if $self->debug;

    $self->call_within_transaction( sub {
        # NOTE: Here we assume that the default tree is flat !
        foreach my $m (@$blocklist_seq_members) {
            if (!$m->tree){
                next;
            }
            $m->tree->store_tag( 'gene_count', $m->tree->get_value_for_tag('gene_count') - 1 );
            $gene_tree_node_adaptor->remove_seq_member($m);
            # remove cluster if too small to create tree
            $gene_tree_adaptor->delete_tree( $m->tree ) if ( $m->tree->get_value_for_tag('gene_count') < 2 ); 
        }
    });
}


1;
