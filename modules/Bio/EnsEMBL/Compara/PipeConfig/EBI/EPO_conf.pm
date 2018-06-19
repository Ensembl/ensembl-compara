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
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EPO_conf.pm

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

        'species_set_name' => 'mammals',
        #'rel_suffix' => 'b',

        # Where the pipeline lives
        'host' => 'mysql-ens-compara-prod-1.ebi.ac.uk',
        'port' => 4485,

        'reg_conf' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/production_reg_ebi_conf.pl',


        # Capacities
        'low_capacity'                  => 10,
        'map_anchors_batch_size'        => 20,
        'map_anchors_capacity'          => 1000,
        'trim_anchor_align_batch_size'  => 20,
        'trim_anchor_align_capacity'    => 150,

        'work_dir'  => '/hps/nobackup/production/ensembl/' . $ENV{USER} . '/' . $self->o('pipeline_name') . '/',

        'species_tree_file' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/species_tree.ensembl.branch_len.nw',

        'bl2seq_exe'        => undef,   # We use blastn instead
        'blastn'            => $self->check_exe_in_cellar('blast/2.2.30/bin/blastn'),
        'enredo_exe'        => $self->check_exe_in_cellar('enredo/0.5.0/bin/enredo'),
        'exonerate_exe'     => $self->check_exe_in_cellar('exonerate24/2.4.0/bin/exonerate'),
        'server_exe'        => $self->check_exe_in_cellar('exonerate24/2.4.0/bin/exonerate-server'),
        'fasta2esd_exe'     => $self->check_exe_in_cellar('exonerate24/2.4.0/bin/fasta2esd'),
        'esd2esi_exe'       => $self->check_exe_in_cellar('exonerate24/2.4.0/bin/esd2esi'),
        'samtools_exe'      => $self->check_exe_in_cellar('samtools/1.6/bin/samtools'),
        'gerp_exe_dir'      => $self->check_dir_in_cellar('gerp/20080211/bin'),
        'java_exe'          => $self->check_exe_in_linuxbrew_opt('jdk@8/bin/java'),
        'ortheus_bin_dir'   => $self->check_dir_in_cellar('ortheus/0.5.0_1/bin'),
        'ortheus_c_exe'     => $self->check_exe_in_cellar('ortheus/0.5.0_1/bin/ortheus_core'),
        'ortheus_lib_dir'   => $self->check_dir_in_cellar('ortheus/0.5.0_1'),
        'pecan_exe_dir'     => $self->check_dir_in_cellar('pecan/0.8.0/libexec'),
        'semphy_exe'        => $self->check_exe_in_cellar('semphy/2.0b3/bin/semphy'),

        'gerp_version' => '2.1', #gerp program version

        'epo_stats_report_email' => $ENV{'USER'} . '@ebi.ac.uk',

        # Databases
        'compara_master' => 'mysql://ensro@mysql-ens-compara-prod-1.ebi.ac.uk:4485/ensembl_compara_master',
        # database containing the anchors for mapping
        'compara_anchor_db' => 'mysql://ensro@mysql-ens-compara-prod-3.ebi.ac.uk:4523/sf5_TEST_gen_anchors_mammals_cat_100',
        # the previous database to reuse the anchor mappings
        'reuse_db' => 'mysql://ensro@mysql-ens-compara-prod-2.ebi.ac.uk:4522/waakanni_mammals_epo_anchor_mapping_93',
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
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
        'default'   => {'LSF' => '-C0 -M2500 -R"select[mem>2500] rusage[mem=2500]"' }, # farm3 lsf syntax
        'mem3500'   => {'LSF' => '-C0 -M3500 -R"select[mem>3500] rusage[mem=3500]"' },
        '3.5Gb'     => {'LSF' => '-C0 -M3500 -R"select[mem>3500] rusage[mem=3500]"' },
        'mem7500'   => {'LSF' => '-C0 -M7500 -R"select[mem>7500] rusage[mem=7500]"' },
        'mem14000'  => {'LSF' => '-C0 -M14000 -R"select[mem>14000] rusage[mem=14000]"' },
        'hugemem'   => {'LSF' => '-q hugemem -C0 -M30000 -R"select[mem>30000] rusage[mem=30000]"' },

    };
}

1;
