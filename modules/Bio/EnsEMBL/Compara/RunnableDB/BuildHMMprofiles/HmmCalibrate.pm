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

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::HmmCalibrate;

=cut

=head1 DESCRIPTION

This module perform calibration on HMM profile

=cut
package Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::HmmCalibrate;

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
  Function   : 
  Returns    : 1 on successful completion
  Exceptions : dies if runnable throws an unexpected error

=cut
sub run {
    my $self = shift @_;

    $self->compara_dba->dbc->disconnect_when_inactive(1);
    $self->compara_dba->dbc->disconnect_if_idle() if $self->compara_dba->dbc->connected();

    my $hmmLib_dir   = $self->param('hmmLib_dir');
    my $hmmcalibrate = $self->param('hmmcalibrate');
    my $hmmprofile   = $self->param('hmmprofile');

    $self->throw('hmmLib_dir is an obligatory parameter') unless (defined $self->param('hmmLib_dir'));
    $self->throw('hmmcalibrate is an obligatory parameter') unless (defined $self->param('hmmcalibrate'));
    $self->throw('hmmprofile is an obligatory parameter') unless (defined $self->param('hmmprofile'));

    if($hmmprofile =~/(.*cluster.*)\_output/){
        my $hmmLib_subdir = $1;
        $hmmLib_dir    = $hmmLib_dir.'/'.$hmmLib_subdir;
    }

    if($hmmprofile =~/hmm$/){
	my $hmmprofile  = $hmmLib_dir.'/'.$hmmprofile;
	my $command     = "hmmcalibrate $hmmprofile"; 
    	my $result      = system($command);
    }
 
return;
}


sub write_output {
    my $self = shift @_;

return;
}


1;
