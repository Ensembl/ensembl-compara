=pod

=head1 NAME

Bio::EnsEMBL::Hive::RunnableDB::BuildHMMprofiles::CreateBlastDB
#Bio::EnsEMBL::Compara::RunnableDB::CreateBlastDB

=head1 DESCRIPTION

This module takes in a sequence file in Fasta format 
and creates a Blast database from this file.

=head1 MAINTAINER

$Author: ckong $

=head VERSION

=cut

package Bio::EnsEMBL::Hive::RunnableDB::BuildHMMprofiles::CreateBlastDB;
#package Bio::EnsEMBL::Compara::RunnableDB::CreateBlastDB;

use Bio::DB::Fasta;
use strict;
use Data::Dumper;
use Bio::EnsEMBL::Hive::RunnableDB::BuildHMMprofiles::BlastDB;
#use Bio::EnsEMBL::Analysis::Tools::BlastDB;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

my $fasta_file;
my $xdformat_exe;
my $output_dir;

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Retrieving required parameters
    Returns :   none
    Args    :   none

=cut
sub fetch_input {
    my $self = shift @_;

    $fasta_file   = $self->param('fasta_file');	
    $xdformat_exe = $self->param('xdformat_exe');
    $output_dir   = $self->param('output_dir');

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
 
    $self->check_directory;  	
 
    # configure the fasta file for use as a blast database file:
    my $blastdb         = Bio::EnsEMBL::Hive::RunnableDB::BuildHMMprofiles::BlastDB->new(
    #my $blastdb        = Bio::EnsEMBL::Analysis::Tools::BlastDB->new(
        -sequence_file => $fasta_file,
#        -mol_type      => 'DNA',
        -mol_type      => 'PROTEIN',
        -xdformat_exe  => $xdformat_exe,
	-output_dir    => $output_dir,
    );
    $blastdb->create_blastdb;

    my $db = Bio::DB::Fasta->new($fasta_file);

return;
}

=head2 check_directory

  Arg[1]     : -none-
  Example    : $self->check_directory;
  Function   : Check if the $output_dir exists, if not create it
  Returns    : None
  Exceptions : dies if fail when creating $output_dir directory 

=cut
sub check_directory {
    my $self = shift @_;

    unless (-e $output_dir) { ## Make sure the directory exists
        print STDERR "$output_dir doesn't exists. I will try to create it\n" if ($self->debug());
        print STDERR "mkdir $output_dir (0755)\n" if ($self->debug());
        die "Impossible create directory $output_dir\n" unless (mkdir $output_dir, 0755 );
    }

return;
}

1;

