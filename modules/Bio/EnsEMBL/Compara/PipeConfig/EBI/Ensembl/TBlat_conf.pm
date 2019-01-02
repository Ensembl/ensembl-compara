=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::TBlat_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::TBlat_conf $(mysql-ens-compara-prod-6-ensadmin details hive) -division plants -mlss_id_list "[9769,9784,9754,9770,9785,9786,9771,9755,9767,9768,9782,9783,9756,9752,9753]"

=head1 DESCRIPTION

Version of the EBI TBlat pipeline used on Ensembl databases

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::TBlat_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::EBI::TBlat_conf');     # We are running TBlat at the EBI


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        # We connect to the databases via the Registry configuration file of the division
        'master_db'                 => 'compara_master',
        'curr_core_sources_locs'    => undef,
        'curr_core_dbs_locs'        => undef,

        # Capacities
        'pair_aligner_analysis_capacity'    => 100,
        'pair_aligner_batch_size'           => 3,
        'chain_hive_capacity'               => 50,
        'chain_batch_size'                  => 5,
        'net_hive_capacity'                 => 20,
        'net_batch_size'                    => 1,
        'filter_duplicates_hive_capacity'   => 200,
        'filter_duplicates_batch_size'      => 10,
    };
}


1;
