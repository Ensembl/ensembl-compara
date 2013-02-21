=pod 

=head1 NAME

Bio::EnsEMBL::BuildHMMprofiles::RunnableDB::PrepareSequence

=cut

=head1 DESCRIPTION

This module reads in a fasta protein sequence file, for each
sequence create a job in the subsequent blastp analysis, for
parallelization of the blastp step.

=cut
package Bio::EnsEMBL::BuildHMMprofiles::RunnableDB::PrepareSequence;

use strict;
use warnings;

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
my $fasta_file;
my $output_dir;

sub fetch_input {
    my $self = shift @_;
    
    $fasta_file = $self->param('fasta_file');

return;
}

=head2 run

  Arg[1]     : -none-
  Example    : $self->run;
  Function   : Retrieve protein sequence and single blast job for each of them
  Returns    : 1 on successful completion
  Exceptions : dies if runnable throws an unexpected error

=cut
sub run {
    my $self = shift @_;

    my $fasta_seq = Bio::SeqIO->new(-file => $fasta_file,-format => 'fasta');
 
    while ( my $seq = $fasta_seq->next_seq() )
    {
        my $len = length($seq->seq);
	next unless ($len > 2);	   
        $self->dataflow_output_id( { 'seq' => $seq }, 2 );
        
        undef $seq;
    } 
    undef $fasta_seq;

return;
}

sub write_output {
    my $self = shift @_;

return;
}

1;
