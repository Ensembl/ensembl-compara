=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClassifyFactory

=head1 DESCRIPTION


=head1 MAINTAINER

$Author: ckong $

=cut
package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClassifyFactory;

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
  Function   : 
  Returns    : 1 on successful completion
  Exceptions : dies if runnable throws an unexpected error

=cut
sub run {
    my $self = shift @_;

    my $sql                = "SELECT member_id,genome_db_id,cluster_dir_id FROM sequence_unclassify";
    my $sth                = $self->compara_dba->dbc->prepare($sql);
    $sth->execute();

    while (my $row = $sth->fetchrow_arrayref) { 
            my $member_id         = $row->[0];
            my $genomeDB_id       = $row->[1];
            my $cluster_dir_count = $row->[2];  
            $self->dataflow_output_id( { 'non_annot_member' => $member_id,'genomeDB_id'=> $genomeDB_id,'cluster_dir_count'=>$cluster_dir_count }, 2);
    }
return;
}

sub write_output {
    my $self = shift @_;

return;
}

1;
