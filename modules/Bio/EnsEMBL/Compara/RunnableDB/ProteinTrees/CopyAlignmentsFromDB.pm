
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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CopyTreesFromDB

=head1 DESCRIPTION

1) Used to copy all the alignments from a previous database.

2) But it wont add any new genes at this point. New genes will be addeed by mafft/raxml

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CopyAlignmentsFromDB;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree');

sub param_defaults {
    return {};
}

sub fetch_input {
    my $self = shift @_;

        #Get adaptors
        #----------------------------------------------------------------------------------------------------------------------------
        #get compara_dba adaptor
        $self->param( 'compara_dba', $self->compara_dba );

        #get reuse compara_dba adaptor
        $self->param( 'reuse_compara_dba', $self->get_cached_compara_dba('reuse_db') );

        print Dumper $self->param('compara_dba')       if ( $self->debug );
        print Dumper $self->param('reuse_compara_dba') if ( $self->debug );

        #get reuse tree adaptor
        $self->param( 'reuse_tree_adaptor', $self->param('reuse_compara_dba')->get_GeneTreeAdaptor ) || die "Could not get GeneTreeAdaptor for reuse_tree_adaptor";

        #get current tree adaptor
        $self->param( 'current_tree_adaptor', $self->param('compara_dba')->get_GeneTreeAdaptor ) || die "Could not get GeneTreeAdaptor for current_tree_adaptor";

        #----------------------------------------------------------------------------------------------------------------------------

        #Get gene_tree
        #----------------------------------------------------------------------------------------------------------------------------
        $self->param( 'current_gene_tree', $self->param('current_tree_adaptor')->fetch_by_dbID( $self->param('gene_tree_id') ) );
        $self->param( 'stable_id', $self->param('current_gene_tree')->get_value_for_tag('model_name') ) || die "Could not get value_for_tag: model_name";

        #Get copy tree
        #----------------------------------------------------------------------------------------------------------------------------
        #Need to get tree with ref_root_id and clusterset_id="copy"
        my $sth = $self->param('current_gene_tree')->adaptor->db->dbc->prepare('SELECT root_id FROM gene_tree_root where clusterset_id="copy" and ref_root_id=?;');
        $sth->execute( $self->param('gene_tree_id') );
        $self->param( 'copy_root_id', $sth->fetchrow_array() );
        $sth->finish;
        $self->param( 'copy_gene_tree', $self->param('current_tree_adaptor')->fetch_by_dbID( $self->param('copy_root_id') ) );

        #----------------------------------------------------------------------------------------------------------------------------

        print "Fetching tree for stable ID/root_id: " . $self->param('stable_id') . "/" . $self->param('gene_tree_id') . "\n" if ( $self->debug );

        #Get list of genes to update
        my $updated_genes_list = $self->param('current_gene_tree')->get_value_for_tag( 'updated_genes_list', '' );
        my %members_2_b_updated = map { $_ => 1 } split( /,/, $updated_genes_list );

        #Get list of genes to add
        my $added_genes_list = $self->param('current_gene_tree')->get_value_for_tag( 'added_genes_list', '' );
        my %members_2_b_added = map { $_ => 1 } split( /,/, $added_genes_list );

        #List of members that were added or updated
        my %members_2_b_added_updated;
        $self->param( 'members_2_b_added_updated', \%members_2_b_added_updated );

        foreach my $added_member ( keys(%members_2_b_added) ) {
            $members_2_b_added_updated{$added_member} = 1;
        }
        foreach my $updated_member ( keys(%members_2_b_updated) ) {
            $members_2_b_added_updated{$updated_member} = 1;
        }

        #Get previous tree
        $self->param( 'reuse_gene_tree', $self->param('reuse_tree_adaptor')->fetch_by_stable_id( $self->param('stable_id') ) );
        $self->param( 'reuse_gene_tree_id', $self->param('reuse_gene_tree')->root_id );

        #Newly added genes will not be added here, only genes that were removed or altered will be excluded.
        #if ( defined( $members_2_b_updated{ $member->stable_id } ) ) {
        #print "Removing updated gene: ".$member->stable_id."\n" if ( $self->debug );
        #$self->param('sa')->remove_seq( $self->param('sa')->each_seq_with_id( $member->seq_member_id ) );
        #}

        #Get all the cigar lines for all members in the reused tree.
        my %cigar_lines_reuse_tree;
        foreach my $member ( @{ $self->param('reuse_gene_tree')->get_all_Members } ) {
            $cigar_lines_reuse_tree{ $member->stable_id } = $member->cigar_line;
            print "reusing_cigar:" . $member->stable_id . "\n" if ( $self->debug );
        }

        #Copying the cigar lines to the new tree excluding the members that need update:
        foreach my $current_member ( @{ $self->param('copy_gene_tree')->get_all_Members } ) {
            if ( defined( $cigar_lines_reuse_tree{ $current_member->stable_id } ) && ( !defined( $members_2_b_added_updated{ $current_member->stable_id } ) ) ) {
                $current_member->cigar_line( $cigar_lines_reuse_tree{ $current_member->stable_id } );
                print "copying_cigar:" . $current_member->stable_id . "\n" if ( $self->debug );
            }
        }

} ## end sub fetch_input

sub write_output {
    my $self = shift;

    if ( !$self->param('current_gene_tree')->has_tag('needs_update') ) {
        $self->_store_aln_tags();
    }

    #In case the tree is an identical copy or only_needs_deleting, we would like to store the alignment for the default tree as well.
    # Since it is used by build_HMM_cds_v3 and build_HMM_aa_v3
    if ( ( $self->param('current_gene_tree')->has_tag('identical_copy') && ( $self->param('current_gene_tree')->get_value_for_tag('identical_copy') == 1 ) ) ||
         ( $self->param('current_gene_tree')->has_tag('only_needs_deleting') && ( $self->param('current_gene_tree')->get_value_for_tag('only_needs_deleting') == 1 ) ) ) {
        my $reuse_aln = $self->param('reuse_gene_tree')->alignment;
        $self->param('current_gene_tree')->aln_length( $reuse_aln->aln_length );
        $self->param('current_gene_tree')->aln_method( $reuse_aln->aln_method );

        $self->compara_dba->get_GeneAlignAdaptor->store( $self->param('current_gene_tree') ) || die "Could not store alignment for: current_gene_tree";
    }

    #We always store the alignment for the copy trees.
    my $reuse_aln = $self->param('reuse_gene_tree')->alignment;
    $self->param('copy_gene_tree')->aln_length( $reuse_aln->aln_length );
    $self->param('copy_gene_tree')->aln_method( $reuse_aln->aln_method );

    $self->compara_dba->get_GeneAlignAdaptor->store( $self->param('copy_gene_tree') ) || die "Could not store alignment for: copy_gene_tree";

    #If the current tree is not an update tree, we should not flow to mafft_update.
    #But it must be done after copying the alignment!
    if ( !$self->param('current_gene_tree')->has_tag('needs_update') ) {
        $self->warning("Current tree is not an update tree, we should not flow to mafft_update");
        $self->input_job->autoflow(0);
    }
} ## end sub write_output

sub _store_aln_tags {
    my $self = shift;

    print "storing_tags ...\n";
    foreach my $tag (qw(aln_runtime aln_percent_identity aln_num_residues aln_length)) {
        if ( $self->param('reuse_gene_tree')->has_tag($tag) ) {
            $self->param('copy_gene_tree')->store_tag($tag, $self->param('reuse_gene_tree')->get_value_for_tag($tag) );
        }
    }
}

1;
