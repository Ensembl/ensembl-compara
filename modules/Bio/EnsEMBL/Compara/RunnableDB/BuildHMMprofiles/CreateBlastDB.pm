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

    my $fasta_file        = $self->param('fasta_file');
    my $xdformat_exe      = $self->param('xdformat_exe');
    my $buildprofiles_dir = $self->param('buildprofiles_dir');

    $self->throw('fasta_file is an obligatory parameter') unless (defined $self->param('fasta_file'));
    $self->throw('xdformat_exe is an obligatory parameter') unless (defined $self->param('xdformat_exe'));
    $self->throw('buildprofiles_dir is an obligatory parameter') unless (defined $self->param('buildprofiles_dir'));
 
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

