=pod 

=head1 NAME

    Bio::EnsEMBL::Compara::RunnableDB::StableIdMapper

=cut

=head1 SYNOPSIS

        # compute and store the stable_id mapping between trees of rel.63 and trees of rel.64:

    time standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::StableIdMapper \
        -compara_db "mysql://ensadmin:${ENSADMIN_PSW}@compara3/mm14_compara_homology_64" \
        -master_db "mysql://ensadmin:${ENSADMIN_PSW}@compara1/sf5_ensembl_compara_master" \
        -prev_rel_db "mysql://ensro@compara1/lg4_ensembl_compara_63" -release 64 -type t

=cut

=head1 DESCRIPTION

This RunnableDB computes and stores stable_id mapping of either for ProteinTrees or Families between releases.

=cut

=head1 CONTACT

Contact anybody in Compara.

=cut


package Bio::EnsEMBL::Compara::RunnableDB::StableIdMapper;


use strict;
use warnings;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::StableId::Adaptor;
use Bio::EnsEMBL::Compara::StableId::NamedClusterSetLink;
use Bio::EnsEMBL::Hive::AnalysisJob;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref check_ref);
use Scalar::Util qw(looks_like_number);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


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
  throw 'Need a -TYPE' unless $type; 
  throw 'Need a -RELEASE' unless $release;
  throw 'Need a -PREV_RELEASE_DB' unless $prev_release_db;
  throw 'Need a -MASTER_DB' unless $master_db;
  
  my $self = bless {}, $class;
  #Put in so we can have access to $self->param()
  my $job = Bio::EnsEMBL::Hive::AnalysisJob->new();
  $self->input_job($job);
  
  $self->compara_dba($db_adaptor);
  $self->param('type',          $type);
  $self->param('release',       $release);
  $self->param('prev_release',  $prev_release);
  $self->param('prev_rel_db',   $prev_release_db);
  $self->param('master_db',     $master_db);
  
  return $self;
}


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
  
  my $prev_rel_db  = $self->param('prev_rel_db');
  if(! $prev_rel_db) {
    print q{Not running as 'prev_rel_db' not given in parameters}."\n" if $self->debug();
    return;
  }

  $self->param('master_db')                       || throw "'master_db' is a required parameter";
  my $type         = $self->param('type')         || throw "'type' is a required parameter, please set it in the input_id hashref to 'f' or 't'";
  my $curr_release = $self->param('release')      || throw "'release' is a required numeric parameter, please set it in the input_id hashref";
  looks_like_number($curr_release)                || throw "'release' is a numeric parameter. Check your input";
  my $prev_release = $self->param('prev_release') || $curr_release - 1;
  my $prev_rel_dbc = $prev_rel_db && $self->go_figure_compara_dba($prev_rel_db)->dbc();

  my $adaptor   = Bio::EnsEMBL::Compara::StableId::Adaptor->new();
  my $from_ncs  = $adaptor->fetch_ncs($prev_release, $type, $prev_rel_dbc);
  my $to_ncs    = $adaptor->fetch_ncs($curr_release, $type, $self->compara_dba->dbc());
  my $ncsl      = Bio::EnsEMBL::Compara::StableId::NamedClusterSetLink->new(-FROM => $from_ncs, -TO => $to_ncs);

  $self->compara_dba()->dbc()->disconnect_when_inactive(1);

  $self->param('adaptor', $adaptor);
  $self->param('ncsl', $ncsl);
  $self->param('prev_release', $prev_release); #replace it with whatever it is now
}


sub run {
  my $self = shift @_;
  
  return if ! $self->param('prev_rel_db'); #bail out early

  my $type         = $self->param('type');
  my $curr_release = $self->param('release');
  my $prev_release = $self->param('prev_release');

  my $ncsl = $self->param('ncsl');
  my $postmap = $ncsl->maximum_name_reuse();
  $ncsl->to->apply_map($postmap);
}


sub write_output {
  my $self = shift @_;

  return if ! $self->param('prev_rel_db'); #bail out early

  my $adaptor   = $self->param('adaptor');
  my $ncsl      = $self->param('ncsl');
  my $master_db = $self->param('master_db');

  my $master_dbc = $master_db && $self->go_figure_compara_dba($master_db)->dbc();
  my $time_when_started_storing = time();  
  eval {
    $adaptor->store_map($ncsl->to, $self->compara_dba()->dbc());
    $adaptor->store_history($ncsl, $self->compara_dba()->dbc(), $time_when_started_storing, $master_dbc);
  };
  if($@) {
    throw "Detected error during store. Check your database settings are correct for the master database (read/write): $@";
  }
}

1;

