=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::EpoExtended::DeleteEPO

=cut

package Bio::EnsEMBL::Compara::RunnableDB::EpoExtended::DeleteEPO;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift;

    my $gaba  = $self->compara_dba->get_GenomicAlignBlockAdaptor;
    my $mlssa = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;

    my $mlss = $mlssa->fetch_by_dbID($self->param_required('base_epo_mlss_id'));
    my $gabs = $gaba->fetch_all_by_MethodLinkSpeciesSet($mlss);
    $self->param('genomic_align_blocks', $gabs);
}

sub run {
    my $self = shift;

    my $gaba = $self->compara_dba->get_GenomicAlignBlockAdaptor;
    my $gata = $self->compara_dba->get_GenomicAlignTreeAdaptor;
    my $gabs = $self->param('genomic_align_blocks');
    foreach my $gab ( @$gabs ) {
        # first, delete the genomic_align_tree
        my $gat = $gata->fetch_by_genomic_align_block_id($gab->dbID);
        $gata->delete($gat) if $gat;

        # then delete the genomic_aligns and genomic_align_blocks
        $gaba->delete_by_dbID($gab->dbID);
    }
}

1;
