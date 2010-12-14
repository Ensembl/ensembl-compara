#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::FlowMemberSeq

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $store_seq_cds = Bio::EnsEMBL::Compara::RunnableDB::FlowMemberSeq->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$store_seq_cds->fetch_input(); #reads from DB
$store_seq_cds->run();
$store_seq_cds->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

Load a list of member_ids, and for each member dataflow
    (member_id, sequence_cds and length(sequence_cds)) to be stored in sequence_cds table
and 
    (member_id, sequence_exon_bounded and length(sequence_exon_bounded)) to be stored in sequence_exon_bounded table.

=cut


=head1 CONTACT

  Contact Albert Vilella on module implementation/design detail: avilella@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut


package Bio::EnsEMBL::Compara::RunnableDB::FlowMemberSeq;

use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   fetches the members
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
    my $self = shift @_;

    my $ids = $self->param('ids') or die "'ids' array is an obligatory parameter and has to be be defined";

    my $member_adaptor = $self->compara_dba->get_MemberAdaptor;
    my @members = ();

    foreach my $id (@$ids) {
        push @members, $member_adaptor->fetch_by_dbID($id);
    }
    
    $self->param('members', \@members);
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   dataflows sequence_cds entries
    Returns :   none
    Args    :   none

=cut


sub write_output {
    my $self = shift @_;

    my $members = $self->param('members');

    foreach my $member (@$members) {
        my $sequence_cds = $member->sequence_cds;

        $self->dataflow_output_id( {
            'member_id'     => $member->dbID,
            'sequence_cds'  => $sequence_cds,
            'length'        => length($sequence_cds),
        }, 2);


        my $sequence_exon_bounded = $member->sequence_exon_bounded;

        $self->dataflow_output_id( {
            'member_id'             => $member->dbID,
            'sequence_exon_bounded' => $sequence_exon_bounded,
            'length'                => length($sequence_exon_bounded),
        }, 3);
    }
}

1;

