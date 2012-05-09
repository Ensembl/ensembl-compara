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

use Bio::EnsEMBL::Compara::StableId::Adaptor;
use Bio::EnsEMBL::Compara::StableId::NamedClusterSetLink;
use Scalar::Util qw(looks_like_number);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
  my $self = shift @_;
  
  my $prev_rel_db  = $self->param('prev_rel_db');
  if(! $prev_rel_db) {
    print q{Not running as 'prev_rel_db' not given in parameters}."\n" if $self->debug();
    return;
  }

  $self->param('master_db')                       || die "'master_db' is a required parameter";
  my $type         = $self->param('type')         || die "'type' is a required parameter, please set it in the input_id hashref to 'f' or 't'";
  my $curr_release = $self->param('release')      || die "'release' is a required numeric parameter, please set it in the input_id hashref";
  looks_like_number($curr_release)                || die "'release' is a numeric parameter. Check your input";
  my $prev_release = $self->param('prev_release') || $curr_release - 1;
  my $prev_rel_dbc = $prev_rel_db && Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($prev_rel_db)->dbc();

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

  my $master_dbc = $master_db && Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($master_db)->dbc();
  my $time_when_started_storing = time();  
  eval {
    $adaptor->store_map($ncsl->to, $self->compara_dba()->dbc());
    $adaptor->store_history($ncsl, $self->compara_dba()->dbc(), $time_when_started_storing, $master_dbc);
  };
  if($@) {
    die "Detected error during store. Check your database settings are correct for the master database (read/write): $@";
  }
}

1;

