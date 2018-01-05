
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

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Mafft_update

=head1 DESCRIPTION

This RunnableDB adds new genes to already existing alignments.
It fetches the genes to be added from the root_tag 'updated_genes_list'

It is used to add sequences to already existing alignments.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Mafft_update;

use strict;
use warnings;

use Data::Dumper;

use Bio::EnsEMBL::Compara::MemberSet;

use base ( 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MSA' );

sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults },
        'mafft_exe'           => '/bin/mafft',                                 # where to find the mafft executable from $mafft_home
        'input_clusterset_id' => 'copy',
        'output_clusterset_id'=> 'default',
    };
}

sub fetch_input {
    my ($self) = @_;

    #Get adaptors
    #----------------------------------------------------------------------------------------------------------------------------
    #get compara_dba adaptor
    $self->param( 'compara_dba', $self->compara_dba );

    #get current tree adaptor
    $self->param( 'current_tree_adaptor', $self->param('compara_dba')->get_GeneTreeAdaptor );
    $self->param( 'current_gene_tree', $self->param('current_tree_adaptor')->fetch_by_dbID( $self->param('gene_tree_id') ) ) || die "Could not fetch current_gene_tree";

    $self->param( 'tree_adaptor', $self->compara_dba->get_GeneTreeAdaptor );
    my $gene_tree = $self->param('tree_adaptor')->fetch_by_dbID( $self->param('gene_tree_id') ) or die "Could not fetch gene_tree with gene_tree_id='$self->param('gene_tree_id')'";
    my $copy_tree = $self->param('current_gene_tree')->alternative_trees->{ $self->param('input_clusterset_id') };
	$self->param( 'copy_gene_tree', $copy_tree);

    die sprintf( 'Cannot find a "%s" tree for tree_id=%d', $self->param('input_clusterset_id'), $self->param('gene_tree_id') ) unless $copy_tree;
	$self->param( 'protein_tree', $self->param('current_gene_tree'));

    my $input_aln = $self->worker_temp_directory.sprintf('/align.%d.fasta', $copy_tree->dbID || 0);
    $copy_tree->print_alignment_to_file( $input_aln,
        -FORMAT => 'fasta',
        -ID_TYPE => 'SEQUENCE',
        -STOP2X => 1,
    );
    unless(-e $input_aln and -s $input_aln) {
        die "There are no alignments in '$input_aln', cannot continue";
    }

    $self->param( 'alignment_file', $input_aln );
} ## end sub fetch_input

#
# Abstract methods from the base class (MSA)
##############################################

sub get_msa_command_line {
    my $self = shift;

    my $mafft_home = $self->param_required('mafft_home');
    my $mafft_exe  = $self->param_required('mafft_exe');

    #This logic should be replaced by the new method for getting the alignment sequences directly from the adaptor.
    #--------------------------------------------------------------------------------------------------------------
    my $new_seq_file = $self->worker_temp_directory . "/" . $self->param_required('gene_tree_id') . "_new_seq.fasta";

    my %members_2_b_updated;
    my %members_2_b_added;
    if ( $self->param('current_gene_tree')->has_tag('updated_genes_list') ) {
        %members_2_b_updated = map { $_ => 1 } split( /,/, $self->param('current_gene_tree')->get_value_for_tag('updated_genes_list') );
    }

    if ( $self->param('current_gene_tree')->has_tag('added_genes_list') ) {
        %members_2_b_added = map { $_ => 1 } split( /,/, $self->param('current_gene_tree')->get_value_for_tag('added_genes_list') );
    }

	@members_2_b_updated{keys %members_2_b_added} = values %members_2_b_added;

	print "members to update:\n" if ( $self->debug );
    my @members_to_print;
    foreach my $updated_member_stable_id ( keys %members_2_b_updated ) {
        my $seq_member_adaptor = $self->compara_dba->get_SeqMemberAdaptor;
        my $seq_member = $seq_member_adaptor->fetch_by_stable_id($updated_member_stable_id);
        print "$updated_member_stable_id|".$seq_member->seq_member_id."|".$seq_member->sequence_id."\n" if ( $self->debug );
        push @members_to_print, $seq_member;
    }
    Bio::EnsEMBL::Compara::MemberSet->new(-MEMBERS => \@members_to_print)->print_sequences_to_file($new_seq_file, -FORMAT => 'fasta', -ID_TYPE => 'SEQUENCE_ID');


    #--------------------------------------------------------------------------------------------------------------

    die "Cannot execute '$mafft_exe' in '$mafft_home'" unless ( -x $mafft_home . '/' . $mafft_exe );

    return sprintf( '%s/%s --add %s --anysymbol --thread 1 --auto %s > %s', $mafft_home, $mafft_exe, $new_seq_file, $self->param('alignment_file'), $self->param('msa_output') );
} ## end sub get_msa_command_line

1;
