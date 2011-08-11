
=pod 

=head1 NAME

    Bio::EnsEMBL::Compara::RunnableDB::TreefamXrefMapper

=cut

=head1 SYNOPSIS

        # compute and store the mapping between TreeFam v.7 and ProteinTrees of rel.64:

    time standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::TreefamXrefMapper \
        -compara_db "mysql://ensadmin:${ENSADMIN_PSW}@compara3/mm14_compara_homology_64" -release 64 -tf_release 7 -tag_prefix ''


        # compute and store the mapping between TreeFam v.8 and ProteinTrees of rel.64:

    time standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::TreefamXrefMapper \
        -compara_db "mysql://ensadmin:${ENSADMIN_PSW}@compara3/mm14_compara_homology_64" -release 64 -tf_release 8 -tag_prefix 'dev_'

=cut

=head1 DESCRIPTION

This RunnableDB computes and stores mapping between TreeFams and ProteinTrees in ProteinTree tags.

=cut

=head1 CONTACT

Contact anybody in Compara.

=cut


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
    my $to_ncs   = $adaptor->fetch_ncs($release,    't',     $self->compara_dba->dbc);
    my $ncsl     = Bio::EnsEMBL::Compara::StableId::NamedClusterSetLink->new(-FROM => $from_ncs, -TO => $to_ncs);

    $self->compara_dba->dbc->disconnect_when_inactive(1);

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

    $adaptor->store_tags($accu, $self->compara_dba->dbc, $tag_prefix);

    return 1;
}

1;

