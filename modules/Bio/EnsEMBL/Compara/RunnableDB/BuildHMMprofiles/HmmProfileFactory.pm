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

Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::HmmProfileFactory

=head1 DESCRIPTION

 This module create a hmmbuild job for each multiple alignment output

=cut
package Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::HmmProfileFactory;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::Perl;
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
  Function   : Retrieve list of msa output and create hmmbuild job
               for each file
  Returns    : 1 on successful completion
  Exceptions : dies if runnable throws an unexpected error

=cut
sub run {
    my $self = shift @_;

    my $msa_dir     = $self->param('msa_dir');
    $self->throw('msa_dir is an obligatory parameter') unless (defined $self->param('msa_dir'));

    opendir(DIR, $msa_dir) or die "Error openining dir '$msa_dir' : $!";
    my @msa_subdir = readdir DIR;
   
    foreach my $msa_subdir (@msa_subdir){
      next unless $msa_subdir =~/^msa/;  
      my $dir = $msa_dir.'/'.$msa_subdir;
      opendir(DIR_2, $dir) or die "Error openining dir '$dir' : $!";

      while ((my $filename = readdir (DIR_2))) {
        my $filesize = -s "$filename";
        next unless $filename =~/^cluster/;
        $filename    = $dir.'/'.$filename;
        $self->dataflow_output_id( { 'msa' => $filename }, 2 ); 
        } 
    }
return;
}

sub write_output {
    my $self = shift @_;

return;
}

1;
