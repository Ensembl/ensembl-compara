#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::CreateHclusterPrepareJobs

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('CreateHclusterPrepareJobs');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::CreateHclusterPrepareJobs();
$rdb->fetch_input;
$rdb->run;

=cut

=head1 DESCRIPTION

This is a homology compara specific runnableDB, that based on an input
of arrayrefs of genome_db_ids, creates Homology_dNdS jobs in the hive 
analysis_job table.

=cut

=head1 CONTACT

avilella@ebi.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::CreateHclusterPrepareJobs;

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive;

use Bio::EnsEMBL::Hive::Process;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);

sub fetch_input {
  my( $self) = @_;

  $self->{'species_set'} = undef;
  $self->throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the pipeline DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);

  $self->get_params($self->parameters);
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

  if (defined $params->{'species_set'}) {
    $self->{'species_set'} = $params->{'species_set'};
  }

  print("parameters...\n");
  printf("  species_set    : (%s)\n", join(',', @{$self->{'species_set'}}));

  return;
}

sub run
{
  my $self = shift;
  return 1 unless($self->{'species_set'});

  $self->create_analysis_jobs($self->{'species_set'});

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
  my $hclusterprepare_analysis = $aa->fetch_by_logic_name('HclusterPrepare');

  foreach my $species (@{$self->{species_set}}) {
    my $analysis_id = $hclusterprepare_analysis->dbID;
    my $sql = "insert ignore into analysis_job (analysis_id,input_id,status) VALUES ($analysis_id,$species,'READY')";
    my $sth = $self->dbc->prepare($sql);
    $sth->execute;
    $sth->finish;
  }
}

1;
