#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::RFAMLoadModels

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $rfamloadmodels = Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::RFAMLoadModels->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$rfamloadmodels->fetch_input(); #reads from DB
$rfamloadmodels->run();
$rfamloadmodels->output();
$rfamloadmodels->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

This Analysis/RunnableDB is designed to fetch the Infernal models from
the RFAM ftp site and load them into the database to be used in the
alignment process.

=cut


=head1 CONTACT

  Contact Albert Vilella on module implementation/design detail: avilella@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::RFAMLoadModels;

use strict;
use IO::File;
use File::Basename;
use Time::HiRes qw(time gettimeofday tv_interval);
use LWP::Simple;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'type'  => 'infernal',
    };
}


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
    my $self = shift @_;

}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs hmmbuild
    Returns :   none
    Args    :   none

=cut


sub run {
    my $self = shift @_;

    $self->download_rfam_models;
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores nctree
    Returns :   none
    Args    :   none

=cut


sub write_output {
    my $self = shift @_;

    $self->store_hmmprofile;
}


##########################################
#
# internal methods
#
##########################################

sub download_rfam_models {
  my $self = shift;

  my $starttime = time();

  my $worker_temp_directory = $self->worker_temp_directory;
  my $url = 'ftp://ftp.sanger.ac.uk/pub/databases/Rfam/10.0/'; my $file = 'Rfam.cm.gz';
#  my $url  = 'ftp://ftp.sanger.ac.uk/pub/databases/Rfam/CURRENT/'; my $file = 'infernal-latest.tar.gz';
  my $expanded_file = $worker_temp_directory . $file; $expanded_file =~ s/\.gz$//;

  unlink($expanded_file); # retry safe
  my $ftp_file = $url . $file;
  my $tmp_file = $worker_temp_directory . $file;
  my $status = getstore($ftp_file, $tmp_file);
  die "Error $status on $ftp_file" unless is_success($status);
  my $cmd = "gunzip $tmp_file";
  # my $cmd = "tar xzf $tmp_file";

  unless(system("cd $worker_temp_directory; $cmd") == 0) {
    print("$cmd\n");
    $self->throw("error expanding RFAMLoadModels $!\n");
  }
  printf("time for RFAMLoadModels fetch : %1.3f secs\n" , time()-$starttime);

  $self->param('multicm_file', $expanded_file);

  return 1;
}


sub store_hmmprofile {
  my $self = shift;

  my $multicm_file = $self->param('multicm_file');
  open MULTICM,$multicm_file or die "$!\n";
  my $name; my $model_id;
  my $profile_content = undef;
  while (<MULTICM>) {
    $profile_content .= $_;
    if ($_ =~ /NAME/) { 
      my ($tag,$this_name) = split(" ",$_);
      $name = $this_name;
    } elsif ($_ =~ /ACCESSION/) { 
      my ($tag,$accession) = split(" ",$_);
      $model_id = $accession;
    } elsif ($_ =~ /\/\//) {
      # End of profile, let's store it
      $self->throw("Error loading cm profile [$model_id]\n") unless (defined($model_id) && defined($profile_content));
      $self->load_cmprofile($profile_content,$model_id,$name);
      $model_id = undef;
      $profile_content = undef;
    }
  }

  return 1;
}


sub load_cmprofile {
  my $self = shift;
  my $cm_profile = shift;
  my $model_id = shift;
  my $name = shift;

  print("load profile $model_id\n") if($self->debug);

  my $table_name = 'nc_profile';
  my $sth = $self->compara_dba->dbc->prepare("INSERT IGNORE INTO $table_name VALUES (?,?,?,?)");
  $sth->execute($model_id, $name, $self->param('type'), $cm_profile);
  $sth->finish;

  return undef;
}

1;
