#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::RFAMLoadModels

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $rfamloadmodels = Bio::EnsEMBL::Compara::RunnableDB::RFAMLoadModels->new
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


package Bio::EnsEMBL::Compara::RunnableDB::RFAMLoadModels;

use strict;
use Getopt::Long;
use IO::File;
use File::Basename;
use Time::HiRes qw(time gettimeofday tv_interval);
use LWP::Simple;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use Bio::EnsEMBL::Hive;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut


sub fetch_input {
  my( $self) = @_;

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new
    (
     -DBCONN=>$self->db->dbc
    );

  $self->{type} = 'infernal';

  return 1;
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs hmmbuild
    Returns :   none
    Args    :   none

=cut


sub run {
  my $self = shift;

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
  my $self = shift;

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
  my $url  = 'ftp://ftp.sanger.ac.uk/pub/databases/Rfam/CURRENT/';
  my $file = 'infernal-latest.tar.gz';
  my $ftp_file = $url . $file;
  my $tmp_file = $worker_temp_directory . $file;
  my $status = getstore($ftp_file, $tmp_file);
  die "Error $status on $ftp_file" unless is_success($status);
  my $cmd = "tar xzf $tmp_file";

  unless(system("cd $worker_temp_directory; $cmd") == 0) {
    print("$cmd\n");
    throw("error expanding RFAMLoadModels $!\n");
  }
  printf("time for RFAMLoadModels fetch : %1.3f secs\n" , time()-$starttime);
}

sub store_hmmprofile {
  my $self = shift;

  my $worker_temp_directory = $self->worker_temp_directory;
  opendir DIR, $worker_temp_directory or die "couldnt find $worker_temp_directory:$!";
  my $cm_file;
  while (( defined($cm_file = readdir(DIR)) )) {
    #Look for the alignments in the dir
    my $model_id;
    if ($cm_file =~ /(\w+)\.cm$/) {
      $model_id = $1;
      throw("wrong file") unless ($model_id =~ /RF/);
      my $tmp_cm_file = $worker_temp_directory . $cm_file;
      $self->load_cmfile($tmp_cm_file,$model_id);
    }
  }
}

sub load_cmfile {
  my $self = shift;
  my $cm_file = shift;
  my $model_id = shift;

  print("load from file $cm_file\n") if($self->debug);

  open (FH, $cm_file) or throw("Couldnt open cm_file [$cm_file]");
  my $name;
  my $hmm_text;
  while (<FH>) {
    if ($_ =~ /NAME\s+(\S+)/) {
      $name = $1;
    }
    $hmm_text .= $_;
  }
  close(FH);

  my $table_name = 'nc_profile';
  my $sth = $self->{comparaDBA}->dbc->prepare("INSERT IGNORE INTO $table_name VALUES (?,?,?,?)");
  $sth->execute($model_id, $name, $self->{type},$hmm_text);
  $sth->finish;

  return undef;
}

1;
