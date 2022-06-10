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

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MafftUpdate

=head1 DESCRIPTION

This RunnableDB adds new genes to already existing alignments.
It fetches the genes to be added from the root_tag 'updated_genes_list'

It is used to add sequences to already existing alignments.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MafftUpdate;

use strict;
use warnings;

use Data::Dumper;
use Array::Utils qw/ array_minus /;

use Bio::EnsEMBL::Compara::MemberSet;

use base ( 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MSA' );

sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults },
        'input_clusterset_id' => 'copy',
        'output_clusterset_id'=> 'default',
    };
}

sub fetch_input {
    my ($self) = @_;

    #get current tree adaptor
    $self->param( 'current_tree_adaptor', $self->compara_dba->get_GeneTreeAdaptor );
    my $current_gene_tree = $self->param('current_tree_adaptor')->fetch_by_dbID( $self->param('gene_tree_id') );
    $self->param(
        'current_gene_tree', $current_gene_tree || $self->die_no_retry("Could not fetch current_gene_tree")
    );
    #get previous tree adaptor
    $self->param( 'reuse_tree_adaptor', $self->param('reuse_compara_dba')->get_GeneTreeAdaptor );
    $self->param( 'previous_gene_tree',
        $self->param('reuse_tree_adaptor')->fetch_by_stable_id( $current_gene_tree->stable_id )
    );

    my $copy_tree = $self->param('current_gene_tree')->alternative_trees->{ $self->param('input_clusterset_id') };
	$self->param( 'copy_gene_tree', $copy_tree);

    die sprintf( 'Cannot find a "%s" tree for tree_id=%d', $self->param('input_clusterset_id'), $self->param('gene_tree_id') ) unless $copy_tree;
	$self->param( 'protein_tree', $self->param('current_gene_tree'));

    my $input_aln = $self->worker_temp_directory.sprintf('/align.%d.fasta', $copy_tree->dbID || 0);
    $copy_tree->print_alignment_to_file( $input_aln,
        -FORMAT => 'fasta',
        -ID_TYPE => 'SEQUENCE',
        -STOP2X => 1,
        -SEQ_TYPE => $self->param('cdna') ? 'cds' : undef,
    );
    unless(-e $input_aln and -s $input_aln) {
        die "There are no alignments in '$input_aln', cannot continue";
    }

    $self->param( 'alignment_file', $input_aln );
}


sub parse_and_store_alignment_into_proteintree {
    my $self = shift;
    $self->SUPER::parse_and_store_alignment_into_proteintree(@_);
    $self->param('protein_tree')->seq_type('cds') if $self->param('cdna');
}


#
# Abstract methods from the base class (MSA)
##############################################

sub get_msa_command_line {
    my $self = shift;

    my $mafft_exe  = $self->require_executable('mafft_exe');

    my $new_seq_file = $self->worker_temp_directory . "/" . $self->param_required('gene_tree_id') . "_new_seq.fasta";

    my @prev_member_list = @{$self->param('previous_gene_tree')->get_all_Members()};
    my @curr_member_list = @{$self->param('current_gene_tree')->get_all_Members()};
    my %prev_members = ( map { ($_->genome_db->dbID . " " . $_->stable_id) => 1 } @prev_member_list );
    my %curr_members = ( map { ($_->genome_db->dbID . " " . $_->stable_id) => 1 } @curr_member_list );

    my @prev_members = keys %prev_members;
    my @curr_members = keys %curr_members;
    my @updated_genome_db_members = array_minus( @curr_members, @prev_members );

	print "members to update:\n" if ( $self->debug );
    my @members_to_print;
    my $seq_member_adaptor = $self->compara_dba->get_SeqMemberAdaptor;

    foreach my $updated_genome_db_member_stable_id ( @updated_genome_db_members ) {
        my ($genome_db_id, $stable_id) = split / /, $updated_genome_db_member_stable_id;
        my $seq_member = $seq_member_adaptor->fetch_by_stable_id_GenomeDB($stable_id, $genome_db_id);
        print $stable_id . "|" . $seq_member->seq_member_id . "|" . $seq_member->sequence_id . "\n" if ( $self->debug );
        push @members_to_print, $seq_member;
    }

    Bio::EnsEMBL::Compara::MemberSet->new(-MEMBERS => \@members_to_print)->print_sequences_to_file($new_seq_file, -FORMAT => 'fasta', -ID_TYPE => 'SEQUENCE_ID', -SEQ_TYPE => $self->param('cdna') ? 'cds' : undef);

    return sprintf( '%s --add %s --anysymbol --thread 1 --auto %s > %s', $mafft_exe, $new_seq_file, $self->param('alignment_file'), $self->param('msa_output') );
}

1;
