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

Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::StoreLowCovSpeciesSet

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::StoreLowCovSpeciesSet;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::SpeciesSet;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift @_;

    my $epo_db_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $self->param_required('epo_db') );
    my $epo_hc_mlss = $epo_db_dba->get_MethodLinkSpeciesSetAdaptor->fetch_all_by_method_link_type('EPO')->[0]
        || die "Could not find an 'EPO' MLSS in ".$self->param('epo_db')."\n";
    my $epo_lc_mlss = $epo_db_dba->get_MethodLinkSpeciesSetAdaptor->fetch_all_by_method_link_type('EPO_LOW_COVERAGE')->[0]
        || die "Could not find an 'EPO_LOW_COVERAGE' MLSS in ".$self->param('epo_db')."\n";

    my %hc_gdb_id = (map {$_->dbID => 1} @{$epo_hc_mlss->species_set_obj->genome_dbs});
    my @lowcov_gdbs = grep {not exists $hc_gdb_id{$_->dbID}} @{$epo_lc_mlss->species_set_obj->genome_dbs};
    my $species_set     = Bio::EnsEMBL::Compara::SpeciesSet->new(
        -NAME => 'low-coverage-assembly',
        -GENOME_DBS => \@lowcov_gdbs,
    );
    $self->param('species_set', $species_set);
}


sub write_output {
    my $self = shift @_;

    $self->compara_dba->get_SpeciesSetAdaptor->store( $self->param('species_set') );
}

1;
