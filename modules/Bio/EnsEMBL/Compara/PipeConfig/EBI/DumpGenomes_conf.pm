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

Bio::EnsEMBL::Compara::PipeConfig::EBI::DumpGenomes_conf

=head1 SYNOPSIS

    # Typical invocation
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::DumpGenomes_conf $(mysql-ens-compara-prod-2-ensadmin details hive)

    # Different registry file and species-set
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::DumpGenomes_conf -reg_conf path/to/reg_conf -collection_name '' -mlss_id 1234

=head1 DESCRIPTION

EBI version of DumpGenomes_conf, a pipeline to dump the genomic sequences
of a given species-set.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::DumpGenomes_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::DumpGenomes_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},

        # Which species-set to dump
        'species_set_id'    => undef,
        'species_set_name'  => undef,
        'collection_name'   => $self->o('division'),
        'mlss_id'           => undef,
        'all_current'       => undef,

        # the production database itself (will be created)
        # it inherits most of the properties from HiveGeneric, we usually only need to redefine the host, but you may want to also redefine 'port'
        'host'              => 'mysql-ens-compara-prod-2.ebi.ac.uk',
        'port'              => 4522,

        # Which user has access to this directory
        'shared_user'       => 'compara_ensembl',

        # the master database to get the genome_dbs
        'master_db'         => 'compara_master',
        # the pipeline won't redump genomes unless their size is different, or listed here
        'force_redump'      => [],

        # Capacities
        'dump_capacity'     => 10,
    };
}


1;
