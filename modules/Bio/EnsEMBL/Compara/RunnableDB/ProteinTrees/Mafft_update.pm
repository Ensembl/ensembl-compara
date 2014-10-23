
=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
use Data::Dumper;
use base ('Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MSA');

sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults },
        'mafft_exe'  => '/bin/mafft',                                 # where to find the mafft executable from $mafft_home
        'mafft_home' => '/nfs/panda/ensemblgenomes/external/mafft',
        'aln_update' => 1, };
}

#
# Abstract methods from the base class (MSA)
##############################################

sub get_msa_command_line {
    my $self = shift;

    #Get adaptors
    #----------------------------------------------------------------------------------------------------------------------------
    #get compara_dba adaptor
    $self->param( 'compara_dba', $self->compara_dba );

    #get current tree adaptor
    $self->param( 'current_tree_adaptor', $self->param('compara_dba')->get_GeneTreeAdaptor );
    $self->param( 'current_gene_tree', $self->param('current_tree_adaptor')->fetch_by_dbID( $self->param('gene_tree_id') ) ) || die "Could not fetch current_gene_tree";
    $self->param('current_gene_tree')->preload();

    #get alignment members list
    $self->param( 'aln_object', $self->param('current_gene_tree')->alignment );

    my $mafft_home = $self->param_required('mafft_home');
    my $mafft_exe  = $self->param_required('mafft_exe');

    #This logic should be replaced by the new method for getting the alignment sequences directly from the adaptor.
    #--------------------------------------------------------------------------------------------------------------
    my $aln_file     = $self->worker_temp_directory . "/" . $self->param_required('gene_tree_id') . ".fasta";
    my $new_seq_file = $self->worker_temp_directory . "/" . $self->param_required('gene_tree_id') . "_new_seq.fasta";

    use Bio::SeqIO;
    open my $fh, ">", $aln_file or die "Could not open '$aln_file' for writing : $!";
    my $sa = $self->param('aln_object')->get_SimpleAlign( -id_type => 'SEQ' );
    $sa->set_displayname_flat(1);
    my $alignIO = Bio::AlignIO->newFh( -fh => $fh, -format => "fasta" );
    print $alignIO $sa;
    close $fh;

    my $new_seq = Bio::SeqIO->new( -file => ">" . $self->worker_temp_directory . "/" . $self->param_required('gene_tree_id') . "_new_seq.fasta", -format => 'fasta' );
    my %members_2_b_updated = map { $_ => 1 } split( /,/, $self->param('current_gene_tree')->get_value_for_tag('updated_genes_list') );
    my %tree_members = ( map { $_->stable_id => $_ } @{ $self->param('current_gene_tree')->get_all_Members } );
    foreach my $updated_member_stable_id ( keys %members_2_b_updated ) {
		print "======>$updated_member_stable_id\n";
        my $bioseq = $tree_members{$updated_member_stable_id}->bioseq( -ID_TYPE => 'SEQUENCE' );
        $new_seq->write_seq($bioseq);
    }
    #--------------------------------------------------------------------------------------------------------------

    die "Cannot execute '$mafft_exe' in '$mafft_home'" unless ( -x $mafft_home . '/' . $mafft_exe );

    return sprintf( '%s/%s --add %s --thread 1 %s > %s', $mafft_home, $mafft_exe, $new_seq_file, $aln_file, $self->param('msa_output') );
} ## end sub get_msa_command_line

1;
