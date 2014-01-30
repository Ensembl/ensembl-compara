=head1 NAME

Bio::EnsEMBL::Hive::RunnableDB::BuildHMMprofiles::HmmBuild;

=head1 DESCRIPTION

This module reads in a msa alignment file, creating HMM
profile for each of the alignment.

=head1 MAINTAINER

$Author: ckong $

=cut
package Bio::EnsEMBL::Hive::RunnableDB::BuildHMMprofiles::HmmBuild;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
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
  Function   : Retrieve msa alignment and for each run hmmbuild job
  Returns    : 1 on successful completion
  Exceptions : dies if runnable throws an unexpected error

=cut
sub run {
    my $self = shift @_;

    my $hmmbuild_exe = $self->param('hmmbuild_exe');
    my $hmmLib_dir   = $self->param('hmmLib_dir');
    my $msa_dir      = $self->param('msa_dir');
    my $msa          = $self->param('msa');

    $self->throw('hmmbuild_exe is an obligatory parameter') unless (defined $self->param('hmmbuild_exe'));
    $self->throw('hmmLib_dir is an obligatory parameter') unless (defined $self->param('hmmLib_dir'));
    $self->throw('msa_dir is an obligatory parameter') unless (defined $self->param('msa_dir'));
    $self->throw('msa is an obligatory parameter') unless (defined $self->param('msa'));

    $self->check_directory($hmmLib_dir);
  
    my $input_file  = $msa;
    my $dir         = $1 if ($msa =~/(cluster.+)\_(output.msa)/);
    my $hmm_dir     = $hmmLib_dir.'/'.$dir;
 
    $self->check_directory($hmm_dir);
    
    my $hmmLib_file = $hmm_dir.'/hmmer.hmm'; 
    $self->compara_dba->dbc->disconnect_when_inactive(1);
    $self->compara_dba->dbc->disconnect_if_idle() if $self->compara_dba->dbc->connected();
    my $command     = "$hmmbuild_exe $hmmLib_file $input_file"; 
    #my $command     = "$hmmbuild_exe --informat afa $hmmLib_file $input_file"; 
    system($command);
    
return;
}


sub write_output {
    my $self = shift @_;

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
