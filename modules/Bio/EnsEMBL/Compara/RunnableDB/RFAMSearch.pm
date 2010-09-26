#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::RFAMSearch

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $ncrecoversearch = Bio::EnsEMBL::Compara::RunnableDB::RFAMSearch->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$ncrecoversearch->fetch_input(); #reads from DB
$ncrecoversearch->run();
$ncrecoversearch->output();
$ncrecoversearch->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

This Analysis will take the sequences from a cluster, the cm from
nc_profile and run a profiled alignment, storing the results as
cigar_lines for each sequence.

=cut


=head1 CONTACT

  Contact Albert Vilella on module implementation/design detail: avilella@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::RFAMSearch;

use strict;
use Getopt::Long;
use Time::HiRes qw(time gettimeofday tv_interval);
use Bio::EnsEMBL::Registry;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data from the database
    Returns :   none
    Args    :   none

=cut


sub fetch_input {
  my( $self) = @_;

  $self->{'clusterset_id'} = 1;
  $self->{context_size} = '120%';

  # Get the needed adaptors here
  $self->{gdbDBA} = $self->compara_dba->get_GenomeDBAdaptor;

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

# # For long parameters, look at analysis_data
#   if($self->{analysis_data_id}) {
#     my $analysis_data_id = $self->{analysis_data_id};
#     my $analysis_data_params = $self->db->get_AnalysisDataAdaptor->fetch_by_dbID($analysis_data_id);
#     $self->get_params($analysis_data_params);
#   }

  return 1;
}


sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n") if($self->debug);

  my $params = eval($param_string);
  return unless($params);

  if($self->debug) {
    foreach my $key (keys %$params) {
      print("  $key : ", $params->{$key}, "\n");
    }
  }

  foreach my $key (qw[param1 param2 param3 analysis_data_id]) {
    my $value = $params->{$key};
    $self->{$key} = $value if defined $value;
  }

  # Fetch nc_tree
  if(defined($params->{'nc_tree_id'})) {
    $self->{'nc_tree'} =  
         $self->compara_dba->get_NCTreeAdaptor->
         fetch_node_by_node_id($params->{'nc_tree_id'});
  }
  if(defined($params->{'clusterset_id'})) {
    $self->{'clusterset_id'} = $params->{'clusterset_id'};
  }

  $self->{model_id} = $self->{nc_tree}->get_tagvalue('clustering_id');

  return;
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs something
    Returns :   none
    Args    :   none

=cut

sub run {
  my $self = shift;

  ## Turn this off right now
  # $self->run_rfamsearch;
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores something
    Returns :   none
    Args    :   none

=cut


sub write_output {
  my $self = shift;

  # Autoflow here
  return 1;
}


##########################################
#
# internal methods
#
##########################################

sub run_rfamsearch {
  my $self = shift;

  next unless(defined($self->{recovered_members}));

  # Here we will use cmsearch to try and classify existing
  # gene+transcript models that come from a 3rd party (e.g. flybase)
  # using cmsearch

  return 1;
}


sub dump_model {
  my $self = shift;
  my $field = shift;
  my $model_id = shift;

  my $sql = 
    "SELECT hc_profile FROM nc_profile ".
      "WHERE $field=\"$model_id\"";
  my $sth = $self->compara_dba->dbc->prepare($sql);
  $sth->execute();
  my $nc_profile  = $sth->fetchrow;
  unless (defined($nc_profile)) {
    return 1;
  }
  my $profile_file = $self->worker_temp_directory . $model_id . "_profile.cm";
  open FILE, ">$profile_file" or die "$!";
  print FILE $nc_profile;
  close FILE;

  $self->{profile_file} = $profile_file;
  return 0;
}

sub fetch_orphan_member_entries {
  my $self = shift;
  my $root_id = shift;

  return 0;
}

1;

