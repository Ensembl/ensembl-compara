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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::MurinaeReindexMembers_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::MurinaeReindexMembers_conf -mlss_id <your_mlss_id> -member_type <protein|ncrna> -member_db <url_of_new_member_database> -prev_rel_db <last_production_database_of_this_mlss>

=head1 EXAMPLES

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::MurinaeReindexMembers_conf ...

e91 protein-trees

    -mlss_id 40111 -member_type protein -member_db $(mysql-ens-compara-prod-2 details url mateus_load_members_91) -prev_rel_db $(mysql-ens-compara-prod-3 details url carlac_murinae_protein_trees_90)

e91 ncRNA-trees

    -mlss_id 40112 -member_type ncrna -member_db $(mysql-ens-compara-prod-2 details url mateus_load_members_91) -prev_rel_db $(mysql-ens-compara-prod-4 details url mateus_murinae_nctrees_90)

=head1 DESCRIPTION

A specialized version of ReindexMembers_conf to use in Ensembl for
the mouse-strains, although "murinae" is only used to set up the
pipeline name.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::MurinaeReindexMembers_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ReindexMembers_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'pipeline_name' => 'murinae_' . $self->o('member_type') . '_trees_' . $self->o('rel_with_suffix'),

        # Main capacity for the pipeline
        'copy_capacity'                 => 4,

        # Params for healthchecks;
        'hc_capacity'                     => 40,
        'hc_batch_size'                   => 10,

        # Where to find the core databases
        'curr_core_sources_locs' => [
            {
                -host   => 'mysql-ens-vertannot-staging.ebi.ac.uk',
                -port   => '4573',
                -user   => 'ensro',
            },
        ],

        # The master database
        'master_db' => 'mysql://ensro@mysql-ens-compara-prod-1.ebi.ac.uk:4485/ensembl_compara_master',
    };
}



sub resource_classes {
    my ($self) = @_;
    return {
        %{ $self->SUPER::resource_classes() },
        'default'                 => { 'LSF' => '-C0 -M100   -R"select[mem>100]   rusage[mem=100]"' },
        '250Mb_job'               => { 'LSF' => '-C0 -M250   -R"select[mem>250]   rusage[mem=250]"' },
        '500Mb_job'               => { 'LSF' => '-C0 -M500   -R"select[mem>500]   rusage[mem=500]"' },
        '1Gb_job'                 => { 'LSF' => '-C0 -M1000  -R"select[mem>1000]  rusage[mem=1000]"' },
    };
}



1;

