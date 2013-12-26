=pod 

=head1 NAME

Bio::EnsEMBL::Hive::RunnableDB::BuildHMMprofiles::HmmCalibrate;
#Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HmmCalibrate;

=cut

=head1 DESCRIPTION

This module perform calibration on HMM profile

=cut
package Bio::EnsEMBL::Hive::RunnableDB::BuildHMMprofiles::HmmCalibrate;
#package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HmmCalibrate;

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
my $hmmprofile;my $hmmcalibrate;my $hmmLib_dir;
my $hmmLib_subdir;

sub fetch_input {
    my $self = shift @_;
    
     $hmmcalibrate = $self->param('hmmcalibrate'); 
     $hmmprofile   = $self->param('hmmprofile');
     $hmmLib_dir   = $self->param('hmmLib_dir');
     
     if($hmmprofile =~/(.*cluster.*)\_output/){
      	 $hmmLib_subdir = $1;
         $hmmLib_dir    = $hmmLib_dir.'/'.$hmmLib_subdir;   
     }

return;
}

=head2 run

  Arg[1]     : -none-
  Example    : $self->run;
XX  Function   : Retrieve msa alignment and for each create a single hmmbuild job
  Returns    : 1 on successful completion
  Exceptions : dies if runnable throws an unexpected error

=cut
sub run {
    my $self = shift @_;

    $self->compara_dba->dbc->disconnect_when_inactive(1);
    $self->compara_dba->dbc->disconnect_if_idle() if $self->compara_dba->dbc->connected();

    if($hmmprofile =~/hmm$/){
	my $hmmprofile  = $hmmLib_dir.'/'.$hmmprofile;
	my $command     = "hmmcalibrate $hmmprofile"; 
    	my $result      = system($command);
    }
    #$self->compara_dba->dbc->disconnect_when_inactive(0);
    #$self->compara_dba->dbc->reconnect_when_lost(1);  
 
return;
}


sub write_output {
    my $self = shift @_;

return;
}


1;
