=head1 NAME

Bio::EnsEMBL::Hive::RunnableDB::ComparaHMM::CreateSequence

=head1 DESCRIPTION

This module create a fasta file using 'member_id's from 
the table sequence_unclassify. To be used to build new 
HMM profiles

=head1 MAINTAINER

$Author: ckong $

=cut
package Bio::EnsEMBL::Hive::RunnableDB::ComparaHMM::CreateSequence;

use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::Perl;
use Bio::Seq; 
use Bio::SeqIO; 
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Retrieving required parameters
    Returns :   none
    Args    :   none

=cut
sub fetch_input {
    my $self = shift @_;

return;
}

=head2 run

  Arg[1]     : -none-
  Example    : $self->run;
  Function   : Retrieve protein sequence and create single blast job for each of them
  Returns    : 1 on successful completion
  Exceptions : dies if runnable throws an unexpected error

=cut
sub run {
    my $self = shift @_;

    $sequence_dir          = $self->param('buildprofiles_dir');
    $self->throw('buildprofiles_dir is an obligatory parameter') unless (defined $self->param('buildprofiles_dir'));

    my $sql                = "SELECT member_id FROM sequence_unclassify";
    my $sth                = $self->compara_dba->dbc->prepare($sql);
    $sth->execute();

    my $SeqMemberAdaptor   = $self->compara_dba->get_SeqMemberAdaptor;
    my $unclassify_members = $sequence_dir."/unclassify_sequence.fa";
    open my $data,">","$unclassify_members" or die $!;

    while (my $row = $sth->fetchrow_arrayref) { 
            my $member_id = $row->[0];
            my $member    = $SeqMemberAdaptor->fetch_by_dbID($member_id);
            my $seq       = $member->sequence;
            $seq          =~ s/(.{72})/$1\n/g;
            chomp $seq;
            print $data ">" . $member->member_id . "\n$seq\n";
    }
    close($data);

return;
}

sub write_output {
    my $self = shift @_;

return;
}

1;
