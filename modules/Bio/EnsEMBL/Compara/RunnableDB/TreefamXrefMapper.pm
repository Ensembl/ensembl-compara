package Bio::EnsEMBL::Compara::RunnableDB::TreefamXrefMapper;

use strict;
use Bio::EnsEMBL::Compara::StableId::Adaptor;
use Bio::EnsEMBL::Compara::StableId::NamedClusterSetLink;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift @_;

    my $release    = $self->param('release')    || die "'release' is an obligatory numeric parameter, please set it in the input_id hashref";
    my $tf_release = $self->param('tf_release') || die "'tf_release' is an obligatory numeric parameter, please set it in the input_id hashref";
    my $tf_type    = $self->param('tf_type')    || 'c';     # 'c' means 'CLEAN', 'w' means 'FULL'

    unless(defined($self->param('tag_prefix'))) {  # we prefer to check this parameter now, not after everything has been computed.
        die "'tag_prefix' is an obligatory parameter, even if set to empty string; plase set it in the input_id hashref";
    }

    my $adaptor = Bio::EnsEMBL::Compara::StableId::Adaptor->new();

    my $from_ncs = $adaptor->fetch_ncs($tf_release, $tf_type);
    my $to_ncs   = $adaptor->fetch_ncs($release,    't',     $self->db->dbc());
    my $ncsl     = Bio::EnsEMBL::Compara::StableId::NamedClusterSetLink->new(-FROM => $from_ncs, -TO => $to_ncs);

    $self->dbc->disconnect_when_inactive(1);

    $self->param('adaptor', $adaptor);
    $self->param('ncsl', $ncsl);

    return 1;
}

sub run {
    my $self = shift @_;

    my $ncsl = $self->param('ncsl');
    my $accu = $ncsl->mnr_lite();

    $self->param('accu', $accu);

    return 1;
}

sub write_output {
    my $self = shift @_;

    my $adaptor    = $self->param('adaptor');
    my $accu       = $self->param('accu');
    my $tag_prefix = $self->param('tag_prefix');

    $adaptor->store_tags($accu, $self->db->dbc(), $tag_prefix);

    return 1;
}

1;

