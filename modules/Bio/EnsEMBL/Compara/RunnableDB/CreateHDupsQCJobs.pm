#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::CreateHDupsQCJobs

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('CreateHDupsQCJobs');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::CreateHDupsQCJobs();
$rdb->fetch_input;
$rdb->run;

=cut

=head1 DESCRIPTION

This is a compara specific runnableDB, that fetches all
ENSEMBL_ORTHOLOGUES and ENSEMBL_PARALOGUES mlsses and creates HDupsQC
jobs in the hive analysis_job table.

=cut

=head1 CONTACT

avilella@ebi.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::CreateHDupsQCJobs;

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive;

use Bio::EnsEMBL::Hive::Process;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);

sub fetch_input {
  my( $self) = @_;

  $self->throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the pipeline DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->{mlssDBA} = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor;

  $self->get_params($self->parameters);

  foreach my $mlss (@{$self->{mlssDBA}->fetch_all_by_method_link_type('ENSEMBL_ORTHOLOGUES')}) {
    $self->{mlssids_ortho}{$mlss->dbID} = 1;
  }
  foreach my $mlss (@{$self->{mlssDBA}->fetch_all_by_method_link_type('ENSEMBL_PARALOGUES')}) {
    $self->{mlssids_para}{$mlss->dbID} = 1;
  }

  return 1;
}

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n");

  my $params = eval($param_string);
  return unless($params);

  foreach my $key (keys %$params) {
    print("  $key : ", $params->{$key}, "\n");
  }

  return;
}

sub run
{
  my $self = shift;

  $self->create_analysis_jobs();

  return 1;
}

sub write_output {
  my $self = shift;
  return 1;
}

##########################################
#
# internal methods
#
##########################################

sub create_analysis_jobs {
  my $self = shift;

  my $aa = $self->db->get_AnalysisAdaptor;
  my $store_seq_cds_analysis = $aa->fetch_by_logic_name('HDupsQC');
  my $analysis_id = $store_seq_cds_analysis->dbID;

  my $sth;
  foreach my $mlss_id (keys %{$self->{mlssids_ortho}}) {
    my $input_string = "{type=>'orthologues',mlss=>$mlss_id}";
    my $sql = "insert ignore into analysis_job (analysis_id,input_id,status) VALUES ($analysis_id,\"$input_string\",'READY')";
    $sth = $self->dbc->prepare($sql);
    $sth->execute;
    if (defined($sth)) {    $sth->finish;}
  }
  foreach my $mlss_id (keys %{$self->{mlssids_para}}) {
    my $input_string = "{type=>'paralogues',mlss=>$mlss_id}";
    my $sql = "insert ignore into analysis_job (analysis_id,input_id,status) VALUES ($analysis_id,\"$input_string\",'READY')";
    $sth = $self->dbc->prepare($sql);
    $sth->execute;
    if (defined($sth)) {    $sth->finish;}
  }
}

1;
