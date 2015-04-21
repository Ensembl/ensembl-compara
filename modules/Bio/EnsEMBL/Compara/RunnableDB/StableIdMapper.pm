=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::StableIdMapper

=cut

=head1 SYNOPSIS

        # compute and store the stable_id mapping between trees of rel.63 and trees of rel.64:

    time standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::StableIdMapper \
        -compara_db "mysql://ensadmin:${ENSADMIN_PSW}@compara3/mm14_compara_homology_64" \
        -master_db "mysql://ensadmin:${ENSADMIN_PSW}@compara1/sf5_ensembl_compara_master" \
        -prev_rel_db "mysql://ensro@compara1/lg4_ensembl_compara_63" -type t

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

  $self->param_required('master_db');
  my $type         = $self->param_required('type');     # must be 't' or 'f'
  my $curr_release = $self->param('release')      || $self->compara_dba->get_MetaContainer->get_schema_version;
  my $prev_rel_dba = $prev_rel_db && Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($prev_rel_db);
  my $prev_release = $self->param('prev_release') || $prev_rel_dba->get_MetaContainer->get_schema_version;

  my $adaptor   = Bio::EnsEMBL::Compara::StableId::Adaptor->new();
  my $from_ncs  = $adaptor->fetch_ncs($prev_release, $type, $prev_rel_dba->dbc());
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

