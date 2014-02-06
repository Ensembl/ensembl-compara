=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::HmmCalibrateFactory

=cut

=head1 DESCRIPTION

 This module create jobs to calibrate hmmprofiles built from HMMer2 

=head1 MAINTAINER

$Author: ckong $

=cut
package Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::HmmCalibrateFactory;

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
  Function   : Retrieve list of msa output and create a single hmmbuild job
               per msa output file
  Returns    : 1 on successful completion
  Exceptions : dies if runnable throws an unexpected error

=cut

sub run {
    my $self = shift @_;

    my $hmmLib_dir     = $self->param('hmmLib_dir');
    $self->throw('hmmLib_dir is an obligatory parameter') unless (defined $self->param('hmmLib_dir'));

    opendir(DIR, $hmmLib_dir) or die "Error openining dir '$hmmLib_dir' : $!";
   
    while(my $sub_dir= readdir(DIR)){
    	if($sub_dir =~/cluster/){
           my $dir = $hmmLib_dir.'/'.$sub_dir;
           opendir(SUB_DIR, $dir) or die "Error openining dir '$dir' : $!";
	  
           while(my $hmmfile = readdir (SUB_DIR)){
	   	if($hmmfile =~/^hmmer/){
	       	   $hmmfile = $dir.'/'.$hmmfile;
                   $self->dataflow_output_id( { 'hmmprofile' => $hmmfile }, 2 );	    
	        }
	   }
           close SUB_DIR; 
       }  
    }
   closedir DIR;

return;
}

sub write_output {
    my $self = shift @_;

return;
}

1;
