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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClassifyFactory


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
