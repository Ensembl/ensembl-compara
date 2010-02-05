#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::CreateStoreSeqCDSJobs

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('CreateStoreSeqCDSJobs');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::CreateStoreSeqCDSJobs();
$rdb->fetch_input;
$rdb->run;

=cut

=head1 DESCRIPTION

This is a compara specific runnableDB, that based on an input
of arrayrefs of genome_db_ids, creates StoreSeqCDS jobs in the hive 
analysis_job table.

=cut

=head1 CONTACT

avilella@ebi.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::CreateStoreSeqCDSJobs;

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
  $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
  $self->{gdbDBA} = $self->{'comparaDBA'}->get_GenomeDBAdaptor;

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
  my $store_seq_cds_analysis = $aa->fetch_by_logic_name('StoreSeqCDS');
  my $analysis_id = $store_seq_cds_analysis->dbID;

  foreach my $species (@{$self->{species_set}}) {
    my $genome_db = $self->{gdbDBA}->fetch_by_dbID($species);
    my @member_ids;
    foreach my $member (@{$self->{memberDBA}->fetch_all_by_source_taxon('ENSEMBLPEP',$genome_db->taxon_id)}) {
      my $member_id = $member->member_id;
      push @member_ids, $member_id;
    }

    my $job_size = int(((scalar @member_ids)/1000));
    $job_size = 1 if ($job_size < 1);
    $job_size = 20 if ($job_size > 20); # limit of 255 chars in input_id

    $DB::single=1;1;#??
    my $sth;
    while (@member_ids) {
      my @job_array = splice(@member_ids,0,$job_size);
      my $input_id = "[" . join(',',@job_array) . "]";
      my $input_string = "{'ids'=>" . $input_id . "}";
      my $sql = "insert ignore into analysis_job (analysis_id,input_id,status) VALUES ($analysis_id,\"$input_string\",'READY')";
      $sth = $self->dbc->prepare($sql);
      $sth->execute;
    }
    $sth->finish;
  }
}

1;
