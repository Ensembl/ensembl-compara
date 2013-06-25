=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HmmBuild;

=cut

=head1 DESCRIPTION

This module reads in a msa alignment file, creating HMM
profile for each of the alignment.

=cut
package Bio::EnsEMBL::BuildHMMprofiles::RunnableDB::HmmBuild;
#package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HmmBuild;

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
my $hmmLib_dir;my $msa;my $hmmbuild_exe;
my $msa_dir;my $division;

sub fetch_input {
    my $self = shift @_;
    
     $hmmbuild_exe = $self->param('hmmbuild_exe'); 
     $hmmLib_dir   = $self->param('hmmLib_dir');
     $msa_dir      = $self->param('msa_dir');
     $msa          = $self->param('msa');
     $division     = $self->param('division');

     unless (-e $hmmLib_dir) { ## Make sure the directory exists
      print STDERR "$hmmLib_dir doesn't exists. I will try to create it\n" if ($self->debug());
      print STDERR "mkdir $hmmLib_dir (0755)\n" if ($self->debug());
      die "Impossible create directory $hmmLib_dir\n" unless (mkdir($hmmLib_dir, 0755));
     }  

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
  
    my $input_file  = $msa;
    my $dir         = $1 if ($msa =~/(cluster.+)\_(output.msa)/);
    $dir  	    = $division.'_'.$dir;
    my $hmm_dir     = $hmmLib_dir.'/'.$dir;
 
    unless (-e $hmm_dir) { ## Make sure the directory exists
       print STDERR "$hmm_dir doesn't exists. I will try to create it\n" if ($self->debug());
       print STDERR "mkdir $hmm_dir (0755)\n" if ($self->debug());
       die "Impossible create directory $hmm_dir\n" unless (mkdir($hmm_dir, 0755));
    }

    my $hmmLib_file = $hmm_dir.'/'.$dir.'.hmm'; 
    $self->compara_dba->dbc->disconnect_when_inactive(1);
    $self->compara_dba->dbc->disconnect_if_idle() if $self->compara_dba->dbc->connected();
    my $command     = "$hmmbuild_exe $hmmLib_file $input_file"; 
    #my $command     = "$hmmbuild_exe --informat afa $hmmLib_file $input_file"; 
    system($command);
    #my $result      = system($command) or die $!;
    #$self->compara_dba->dbc->disconnect_when_inactive(0);
    #$self->compara_dba->dbc->reconnect_when_lost(1);
    #unlink $input_file if (defined $result);

return;
}


sub write_output {
    my $self = shift @_;

return;
}


1;
