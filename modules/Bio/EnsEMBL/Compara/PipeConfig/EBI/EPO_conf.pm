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

Bio::EnsEMBL::Compara::PipeConfig::EBI::EPO_conf

=head1 SYNOPSIS

    EBI-specific configuration of EPO pipeline (anchor mapping). Options that
    may need to be checked include:

       'species_set_name'  - used in the naming of the database
       'compara_anchor_db' - database containing the anchor sequences (entered in the anchor_sequence table)
       'mlss_id'       - mlss_id for the epo alignment (in master)

    #4. Run init_pipeline.pl script:
        Using command line arguments:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::EPO_conf -mlss_id <> -species_set_name <>

    #5. Run the "beekeeper.pl ... -sync" and then " -loop" command suggested by init_pipeline.pl

    #6. Fix the code when it crashes

=head1 DESCRIPTION

    This configuaration file gives defaults for mapping (using exonerate at the moment) anchors to a set of target genomes (dumped text files)

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::EPO_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use base ('Bio::EnsEMBL::Compara::PipeConfig::EPO_conf');

sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},

        # 'species_set_name' => 'fish',
        #'rel_suffix' => 'b',

        # Where the pipeline lives
        'host' => 'mysql-ens-compara-prod-2.ebi.ac.uk',
        'port' => 4522,

        'division' => 'ensembl',

        # Capacities
        'low_capacity'                  => 10,
        'map_anchors_batch_size'        => 20,
        'map_anchors_capacity'          => 2000,
        'trim_anchor_align_batch_size'  => 20,
        'trim_anchor_align_capacity'    => 500,

        'work_dir'  => $self->o('pipeline_dir'),

        # Databases
        'compara_master' => 'compara_master',
        # database containing the anchors for mapping
        'compara_anchor_db' => $self->o('species_set_name').'_epo_anchors',
        # the previous database to reuse the anchor mappings
        'reuse_db' => $self->o('species_set_name').'_epo_prev',

        # The ancestral_db is created on the same server as the pipeline_db
        'ancestral_db' => { # core ancestral db
            -driver   => $self->o('pipeline_db', '-driver'),
            -host     => $self->o('pipeline_db', '-host'),
            -port     => $self->o('pipeline_db', '-port'),
            -species  => $self->o('ancestral_sequences_name'),
            -user     => $self->o('pipeline_db', '-user'),
            -pass     => $self->o('pipeline_db', '-pass'),
            -dbname   => $self->o('ENV', 'USER').'_'.$self->o('species_set_name').'_ancestral_core_'.$self->o('rel_with_suffix'),
        },
    };
}

sub resource_classes {
    my ($self) = @_;
    my $reg_requirement = '--reg_conf '.$self->o('reg_conf');
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
        'default'   => {'LSF' => ['-C0 -M2500  -R"select[mem>2500]  rusage[mem=2500]"',  $reg_requirement] },
        'mem3500'   => {'LSF' => ['-C0 -M3500  -R"select[mem>3500]  rusage[mem=3500]"',  $reg_requirement] },
        '3.5Gb'     => {'LSF' => ['-C0 -M3500  -R"select[mem>3500]  rusage[mem=3500]"',  $reg_requirement] },
        'mem7500'   => {'LSF' => ['-C0 -M7500  -R"select[mem>7500]  rusage[mem=7500]"',  $reg_requirement] },
        'mem14000'  => {'LSF' => ['-C0 -M14000 -R"select[mem>14000] rusage[mem=14000]"', $reg_requirement] },
        '30Gb_job'  => {'LSF' => ['-C0 -M30000 -R"select[mem>30000] rusage[mem=30000]"', $reg_requirement] },

    };
}

1;
