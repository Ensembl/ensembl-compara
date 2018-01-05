=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::TreefamXrefMapper

=cut

=head1 SYNOPSIS

        # compute and store the mapping between TreeFam v.7 and ProteinTrees of rel.64:

    time standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::TreefamXrefMapper \
        -compara_db "mysql://ensadmin:${ENSADMIN_PSW}@compara3/mm14_compara_homology_64" -tf_release 7 -tag_prefix ''


        # compute and store the mapping between TreeFam v.8 and ProteinTrees of rel.64:

    time standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::TreefamXrefMapper \
        -compara_db "mysql://ensadmin:${ENSADMIN_PSW}@compara3/mm14_compara_homology_64" -tf_release 8 -tag_prefix 'dev_'

=cut

=head1 DESCRIPTION

This RunnableDB computes and stores mapping between TreeFams and ProteinTrees in ProteinTree tags.

=cut

=head1 CONTACT

Contact anybody in Compara.

=cut


package Bio::EnsEMBL::Compara::RunnableDB::TreefamXrefMapper;

use strict;
use warnings;
use Bio::EnsEMBL::Compara::StableId::Adaptor;
use Bio::EnsEMBL::Compara::StableId::NamedClusterSetLink;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift @_;

    my $release    = $self->compara_dba->get_MetaContainer->get_schema_version;
    my $tf_release = $self->param_required('tf_release');

    $self->param_required('tag_prefix');

    my $adaptor = Bio::EnsEMBL::Compara::StableId::Adaptor->new();

    my $from_ncs = $adaptor->fetch_ncs($tf_release, 'tf');
    my $to_ncs   = $adaptor->fetch_ncs($release,    't',     $self->compara_dba->dbc);
    my $ncsl     = Bio::EnsEMBL::Compara::StableId::NamedClusterSetLink->new(-FROM => $from_ncs, -TO => $to_ncs);

    $self->param('adaptor', $adaptor);
    $self->param('ncsl', $ncsl);

    return 1;
}

sub run {
    my $self = shift @_;

    $self->compara_dba->dbc->disconnect_if_idle();

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

