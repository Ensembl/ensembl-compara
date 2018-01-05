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

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RemoveBlacklistedGenes

=head1 DESCRIPTION

Removes from the (flat) clusters the genes listed in a file

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::RemoveBlacklistedGenes;

use strict;
use warnings;
use Data::Dumper;

use Bio::EnsEMBL::Utils::IO qw/:slurp/;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $blacklist_genes         = slurp_to_array($self->param_required('blacklist_file'), 1);

    # remove members related to blacklisted genes
    my $gene_member_adaptor     = $self->compara_dba->get_GeneMemberAdaptor;
    my $seq_member_adaptor      = $self->compara_dba->get_SeqMemberAdaptor;
    my $gene_tree_node_adaptor  = $self->compara_dba->get_GeneTreeNodeAdaptor;

    my @blacklist_seq_members;
    foreach my $gene_name (@$blacklist_genes) {
        my $member = $gene_member_adaptor->fetch_by_stable_id($gene_name) || $seq_member_adaptor->fetch_by_stable_id($gene_name);
        unless ( $member ){
            $self->warning( "Cannot find '$gene_name' in the database\n" );
            next;
        }

        my $aligned_member = $gene_tree_node_adaptor->fetch_default_AlignedMember_for_Member($member);
        unless ( $aligned_member ) {
            $self->warning( "Cannot find alignment for '$gene_name' in the database\n" );
            next;
        }
        push @blacklist_seq_members, $aligned_member;
    }

    $self->param('blacklist_seq_members', \@blacklist_seq_members);
}

sub write_output {
    my $self = shift @_;

    my $blacklist_seq_members   = $self->param('blacklist_seq_members');
    my $gene_tree_node_adaptor  = $self->compara_dba->get_GeneTreeNodeAdaptor;
    my $gene_tree_adaptor       = $self->compara_dba->get_GeneTreeAdaptor;

    print Dumper $blacklist_seq_members if $self->debug;

    $self->call_within_transaction( sub {
        # NOTE: Here we assume that the default tree is flat !
        foreach my $m (@$blacklist_seq_members) {
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
