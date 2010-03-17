package Bio::EnsEMBL::Compara::RunnableDB::StableIdMapper;

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::StableId::Adaptor;
use Bio::EnsEMBL::Compara::StableId::NamedClusterSetLink;

use base ('Bio::EnsEMBL::Hive::ProcessWithParams');

sub fetch_input {
    my $self = shift @_;

    my $type         = $self->param('type')         || die "'type' is an obligatory parameter, please set it in the input_id hashref to 'f' or 't'";
    my $curr_release = $self->param('release')      || die "'release' is an obligatory numeric parameter, please set it in the input_id hashref";
    my $prev_release = $self->param('prev_release') || $curr_release - 1;
    my $prev_rel_db  = $self->param('prev_rel_db');

    my $prev_rel_dbc = $prev_rel_db && Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(%$prev_rel_db)->dbc();

    my $adaptor = Bio::EnsEMBL::Compara::StableId::Adaptor->new();

    my $from_ncs = $adaptor->fetch_ncs($prev_release, $type, $prev_rel_dbc);
    my $to_ncs   = $adaptor->fetch_ncs($curr_release, $type, $self->db->dbc());
    my $ncsl     = Bio::EnsEMBL::Compara::StableId::NamedClusterSetLink->new(-FROM => $from_ncs, -TO => $to_ncs);

    $self->dbc->disconnect_when_inactive(1);

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

    $adaptor->store_map($ncsl->to, $self->db->dbc());

    my $master_dbc = $master_db && Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(%$master_db)->dbc();
    $adaptor->store_history($ncsl, $self->db->dbc(), $time_when_started_storing, $master_dbc);

    return 1;
}

1;

