
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

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CDHit

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take a ProteinTree as input
This must already have a multiple alignment run on it. It uses that alignment
as input create a HMMER HMM profile

input_id/parameters format eg: "{'gene_tree_id'=>1234}"
    gene_tree_id : use 'id' to fetch a cluster from the ProteinTree

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CDHit;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::AlignedMemberSet;
use File::Copy qw(copy);

use base ( 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::LoadModels', 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree' );

sub fetch_input {
    my $self = shift @_;

    my $protein_tree_id = $self->param_required('gene_tree_id');
    $self->param( 'tree_adaptor', $self->compara_dba->get_GeneTreeAdaptor );
    $self->param( 'gene_tree', $self->param('tree_adaptor')->fetch_by_dbID($protein_tree_id) ) || die "Could not fetch gene_tree with gene_tree_id='$protein_tree_id'";
    my $protein_tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($protein_tree_id) or die "Could not fetch protein_tree with gene_tree_id='$protein_tree_id'";
    $self->param( 'protein_tree', $protein_tree );

    my $members = $protein_tree->alignment->get_all_Members;

    if ( scalar @$members < 4 ) {
        $self->complete_early( sprintf( 'CDHit will not run with only %d members.', scalar(@$members) ) );
    }

    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences( $self->compara_dba->get_SequenceAdaptor, $protein_tree->member_type, $members );


    $self->require_executable('cdhit_exe');
}

=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs cdhit
    Returns :   none
    Args    :   none

=cut

sub run {
    my $self = shift @_;
    $self->run_cdhit;
}

=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores new filter_level_4 trees
    Returns :   none
    Args    :   none

=cut

sub write_output {
    my $self = shift @_;

    $self->call_within_transaction( sub { $self->_write_output } );
    my $output_id = {'gene_tree_id' => $self->param('new_tree')->root_id};
    $self->dataflow_output_id($output_id, 1);
}

##########################################
#
# internal methods
#
##########################################

sub _write_output {
    my $self      = shift @_;
    my $leafcount = scalar( @{ $self->param('new_tree')->root->get_all_leaves } );

    #Delete old tree so there is no conflict with the stable_ids
    #$self->compara_dba->get_GeneTreeAdaptor->delete_tree( $self->param('gene_tree') ) || die "Could not store (FastTree/supertree) tree.";
    $self->compara_dba->get_GeneTreeAdaptor->store( $self->param('gene_tree') ) || die "Could not store (FastTree/supertree) tree.";
    $self->compara_dba->get_GeneTreeAdaptor->store( $self->param('new_tree') )  || die "Could not store (FastTree/supertree) tree.";
    $self->param('new_tree')->copy_tags_from( $self->param('gene_tree'), $self->param('tags_to_copy') );
    $self->param('new_tree')->add_tag( 'gene_count', $leafcount );
    $self->param('new_tree')->adaptor->_store_all_tags( $self->param('new_tree') );
}

sub run_cdhit {
    my $self = shift;

    #Get all the children from the itial tree
    my @main_tree_children = @{ $self->param('gene_tree')->root->get_all_leaves};

    die "Something went wrong when getting the members for gene_tree." if (scalar(@main_tree_children) <= 1);

    #Required parameters
    my $cdhit_exe         = $self->param_required('cdhit_exe');
    my $cdhit_threshold   = $self->param_required('cdhit_identity_threshold');
    my $cdhit_mem         = $self->param_required('cdhit_memory_in_mb');
    my $cdhit_num_threads = $self->param_required('cdhit_num_threads');
    my $tmp_dir           = $self->worker_temp_directory;
    my $aln_file          = "$tmp_dir/input_seqs.fasta";

    #Fetch unaligned sequences for the current tree
    my $removed_columns = undef;
    if ( $self->param('gene_tree')->has_tag('removed_columns') ) {
        my @removed_columns = eval( $self->param('gene_tree')->get_value_for_tag('removed_columns') );
        $removed_columns = \@removed_columns;
        print "Removing columns.\n" if ( $self->debug() );
    }
    else {
        $self->warning( sprintf( "The 'removed_columns' is missing from tree dbID=%d\n", $self->param('gene_tree')->dbID ) );
    }

    $self->param('gene_tree')->print_sequences_to_file($aln_file, -id_type => 'MEMBER', -REMOVED_COLUMNS => $removed_columns,);

    #CDHit main result file
    my $sequences_to_keep_file = "$tmp_dir/new_fasta.fasta";

    #Run CDHit:
    my $cmd = "$cdhit_exe -i $aln_file -o $sequences_to_keep_file -c $cdhit_threshold -M $cdhit_mem -T $cdhit_num_threads";
    print "CDHit COMMAND LINE:$cmd\n" if $self->debug;

    #Die in case of any problems with CDHit.
    system($cmd) == 0 or die "Error while running CDHit command: $cmd";

    #List of sequences to include. Sequences that are in the CDHit output:
    my %sequences_to_keep;
    my $input_seqio = Bio::SeqIO->new( -file => $sequences_to_keep_file );
    while ( my $seq_object_1 = $input_seqio->next_seq ) {
        #if id is in the list to include
        $sequences_to_keep{ $seq_object_1->id } = 1;
        #print "\t\tKEEP:|".$seq_object_1->id."|\n";
    }

    if ( scalar( keys %sequences_to_keep ) == scalar(@main_tree_children) ) {
        $self->compara_dba->get_GeneTreeAdaptor->change_clusterset( $self->param('gene_tree'), "filter_level_4" );
        $self->input_job->autoflow(0);
        my $output_id = {'gene_tree_id' => $self->param('gene_tree')->root_id};
        $self->dataflow_output_id($output_id, 1);
        $self->complete_early("CDHit did not exclude any members, so we just copy the tree to the next filter level (filter_level_4)");
    }

    my $stable_id = $self->param('gene_tree')->stable_id;
    $stable_id = $self->param('gene_tree')->root_id if (!$stable_id);

    $self->param('gene_tree')->stable_id( $stable_id . "_CDHit" );

    # The new tree object
    my $new_tree = new Bio::EnsEMBL::Compara::GeneTree( -tree_type                  => 'tree',
                                                        -clusterset_id              => 'filter_level_4',
                                                        -member_type                => $self->param('gene_tree')->member_type,
                                                        -method_link_species_set_id => $self->param('gene_tree')->method_link_species_set_id,
                                                        -stable_id                  => $stable_id );

    $new_tree->root->{'_different_tree_object'} = 1;

    #print "\n\n\n>>>>>>>PAT:$stable_id<<<<\n\n\n";
    #foreach my $child ( @{ $self->param('gene_tree')->root->children } ) {
    foreach my $child (@main_tree_children) {
        if ( $sequences_to_keep{ $child->dbID } ) {
            my $leaf = new Bio::EnsEMBL::Compara::GeneTreeMember;
            $leaf->seq_member_id( $child->dbID );
            #print "\t\t===>".$child->seq_member_id."|\n";
            $new_tree->add_Member($leaf);
        }
    }
    $new_tree->add_tag( 'gene_count', scalar( @{ $new_tree->root->children } ) );

    $self->param( 'new_tree', $new_tree );

} ## end sub run_cdhit

1;
