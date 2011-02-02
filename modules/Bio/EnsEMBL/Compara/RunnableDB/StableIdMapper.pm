package Bio::EnsEMBL::Compara::RunnableDB::StableIdMapper;

use strict;
use warnings;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::StableId::Adaptor;
use Bio::EnsEMBL::Compara::StableId::NamedClusterSetLink;
use Bio::EnsEMBL::Hive::AnalysisJob;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref check_ref);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

=pod

=head2 new_without_hive()
  
  Arg [DB_ADAPTOR] : DBAdaptor pointing to current Compara DB 
  Arg [TYPE] : The type of mapping to perform (f and t only supported)
  Arg [RELEASE] : The release of the current database
  Arg [PREV_RELEASE] : The release we are mapping IDs from
  Arg [PREV_RELEASE_DB] : DBAdaptor or HASH of the connection details 
                          to the prevous release database
  Arg [MASTER_DB] : DBAdaptor or HASH of the connection details to the 
                    master database instance
  Returntype  : An instance of this class
  Description : Builds an instance of this runnable to be used outside of a 
                hive process 
  Exceptions  : If DBAdaptor is not a Compara DBAdaptor
  Status      : Beta  
 
=cut

sub new_without_hive {
  my ($class, @args) = @_;
  my ($db_adaptor, $type, $release, $prev_release, $prev_release_db, $master_db) = 
    rearrange([qw(db_adaptor type release prev_release prev_release_db master_db)], @args);
  
  assert_ref($db_adaptor, 'Bio::EnsEMBL::Compara::DBSQL::DBAdaptor'); 
  
  my $self = bless {}, $class;
  #Put in so we can have access to $self->param()
  my $job = Bio::EnsEMBL::Hive::AnalysisJob->new();
  $self->input_job($job);
  
  $self->compara_dba($db_adaptor);
  $self->param('type', $type);
  $self->param('release', $release);
  $self->param('prev_release', $prev_release);
  $self->param('prev_rel_db', $self->_dba_to_hash($prev_release_db));
  $self->param('master_db', $self->_dba_to_hash($master_db));
  
  return $self;
}

=pod

=head2 run_without_hive()
  
  Returntype  : None
  Description : Runs the three stages of the hive process in one continous
                call.
  Exceptions  : Lots possible from bad identifier mappings
  Status      : Beta  
 
=cut

sub run_without_hive {
  my ($self) = @_;
  $self->fetch_input();
  $self->run();
  $self->write_output();
  return;
}

sub fetch_input {
    my $self = shift @_;

    my $type         = $self->param('type')         || die "'type' is an obligatory parameter, please set it in the input_id hashref to 'f' or 't'";
    my $curr_release = $self->param('release')      || die "'release' is an obligatory numeric parameter, please set it in the input_id hashref";
    my $prev_release = $self->param('prev_release') || $curr_release - 1;
    my $prev_rel_db  = $self->param('prev_rel_db');

    my $prev_rel_dbc = $prev_rel_db && Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(%$prev_rel_db)->dbc();

    my $adaptor = Bio::EnsEMBL::Compara::StableId::Adaptor->new();

    my $from_ncs = $adaptor->fetch_ncs($prev_release, $type, $prev_rel_dbc);
    my $to_ncs   = $adaptor->fetch_ncs($curr_release, $type, $self->compara_dba->dbc());
    my $ncsl     = Bio::EnsEMBL::Compara::StableId::NamedClusterSetLink->new(-FROM => $from_ncs, -TO => $to_ncs);

    $self->compara_dba()->dbc()->disconnect_when_inactive(1);

    $self->param('adaptor', $adaptor);
    $self->param('ncsl', $ncsl);

    return 1;
}

sub run {
    my $self = shift @_;

    my $type         = $self->param('type')         || die "'type' is an obligatory parameter, please set it in the input_id hashref to 'f' or 't'";
    my $curr_release = $self->param('release')      || die "'release' is an obligatory numeric parameter, please set it in the input_id hashref";
    my $prev_release = $self->param('prev_release') || $curr_release - 1;

    my $ncsl = $self->param('ncsl');
    my $postmap = $ncsl->maximum_name_reuse();
    $ncsl->to->apply_map($postmap);

    return 1;
}

sub write_output {
    my $self = shift @_;

    my $adaptor   = $self->param('adaptor');
    my $ncsl      = $self->param('ncsl');
    my $master_db = $self->param('master_db');

    my $time_when_started_storing = time();

    $adaptor->store_map($ncsl->to, $self->compara_dba()->dbc());

    my $master_dbc = $master_db && Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(%$master_db)->dbc();
    $adaptor->store_history($ncsl, $self->compara_dba()->dbc(), $time_when_started_storing, $master_dbc);

    return 1;
}

sub _dba_to_hash {
  my ($self, $dba) = @_;
  if(check_ref($dba, 'Bio::EnsEMBL::DBSQL::DBAdaptor')) {
    return {
      -SPECIES => $dba->species(),
      -SPECIES_ID => $dba->species_id(),
      -MULTISPECIES_DB => $dba->is_multispecies(),
      -DBCONN => $dba->dbc(),
      -GROUP => $dba->group()
    };
  }
  #Probably a HASH anyway
  return $dba;
}

1;

