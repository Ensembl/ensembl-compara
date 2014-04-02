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

Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::CreateBlastDB

=head1 DESCRIPTION

This module takes in a sequence file in Fasta format 
and creates a Blast database from this file.


=cut
package Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::CreateBlastDB;

use strict;
use Bio::DB::Fasta;
use Data::Dumper;
use Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::BlastDB;
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
  Function   : Creating blastDB
  Returns    : 1 on successful completion
  Exceptions : dies if runnable throws an unexpected error 

=cut
sub run {
    my $self = shift @_;

    my $fasta_file        = $self->param_required('fasta_file');
    my $xdformat_exe      = $self->param_required('xdformat_exe');
    my $buildprofiles_dir = $self->param_required('buildprofiles_dir');
 
    $self->check_directory($buildprofiles_dir);  	
    # configure the fasta file for use as a blast database file:
    my $blastdb         = Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::BlastDB->new(
        -sequence_file => $fasta_file,
        -mol_type      => 'PROTEIN',
        -xdformat_exe  => $xdformat_exe,
	-output_dir    => $buildprofiles_dir,
    );
    $blastdb->create_blastdb;
    my $db = Bio::DB::Fasta->new($fasta_file);

return;
}

=head2 check_directory

  Arg[1]     : -none-
  Example    : $self->check_directory;
  Function   : Check if the directory exists, if not create it
  Returns    : None
  Exceptions : dies if fail when creating directory 

=cut
sub check_directory {
    my ($self,$dir) = @_;

    unless (-e $dir) {
        print STDERR "$dir doesn't exists. I will try to create it\n" if ($self->debug());
        print STDERR "mkdir $dir (0755)\n" if ($self->debug());
        die "Impossible create directory $dir\n" unless (mkdir $dir, 0755 );
    }

return;
}


1;

