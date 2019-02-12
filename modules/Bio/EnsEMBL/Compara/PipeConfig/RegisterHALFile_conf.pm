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

Bio::EnsEMBL::Compara::PipeConfig::RegisterHALFile_conf
 ** Note
Alignments using the _method_ `CACTUS_HAL` or `CACTUS_HAL_PW` require extra
files to be downloaded from
<ftp://ftp.ensembl.org/pub/data_files/multi/hal_files/> in order to be fetched with the
API. The files must have the same name as on the FTP and must be placed
under `multi/hal_files/` within your directory of choice.
Finally, you need to define the environment variable `COMPARA_HAL_DIR` to
the latter.
export COMPARA_HAL_DIR="path_to_file/data_files/"

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::RegisterHALFile_conf -mlss_id <mlss_id> -species_name_mapping "{134 => 'C57B6J', ... }"

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::RegisterHALFile_conf -mlss_id 835 -species_name_mapping "{134 => 'C57B6J', 155 => 'rn6',160 => '129S1_SvImJ',161 => 'A_J',162 => 'BALB_cJ',163 => 'C3H_HeJ',164 => 'C57BL_6NJ',165 => 'CAST_EiJ',166 => 'CBA_J',167 => 'DBA_2J',168 => 'FVB_NJ',169 => 'LP_J',170 => 'NOD_ShiLtJ',171 => 'NZO_HlLtJ',172 => 'PWK_PhJ',173 => 'WSB_EiJ',174 => 'SPRET_EiJ', 178 => 'AKR_J'}" -master_db "mysql://ensro@mysql-ens-compara-prod-1.ebi.ac.uk:4485/ensembl_compara_master" -halStats_exe '/nfs/software/ensembl/RHEL7-JUL2017-core2/linuxbrew/bin/halStats' -host "mysql-ens-compara-prod-2.ebi.ac.uk:4522"

=head1 DESCRIPTION  

Mini-pipeline to load the species-tree and the chromosome-name mapping from a HAL file

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::RegisterHALFile_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For INPUT_PLUS

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;

    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class
        'master_db'     => $self->o('master_db'),
        'halStats_exe'  => $self->o('halStats_exe'),
    };
}


sub pipeline_analyses {
    my ($self) = @_;

    return [
        {   -logic_name => 'copy_mlss',
	    -module     => 'Bio::EnsEMBL::Compara::RunnableDB::CopyDataWithFK',
            -parameters => {
                'db_conn'                       => '#master_db#',
                'method_link_species_set_id'    => '#mlss_id#',
            },
            -flow_into => [ 'set_mlss_tag' ],
            -input_ids => [ {
                'mlss_id'   => $self->o('mlss_id'),
                'species_name_mapping'  => $self->o('species_name_mapping'),
            } ],
        },

        {   -logic_name => 'set_mlss_tag',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => [ 'INSERT IGNORE INTO method_link_species_set_tag (method_link_species_set_id, tag, value) VALUES (#mlss_id#, "HAL_mapping", "#species_name_mapping#")' ],
            },
            -flow_into  => [ 'load_species_tree', 'species_factory' ],
        },

        {   -logic_name => 'load_species_tree',
	    -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::LoadSpeciesTree',
        },

        {   -logic_name => 'species_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -flow_into  => {
                    2   => { "generate_coverage_stats" => INPUT_PLUS() },
                '2->A' => { 'get_synonyms' => INPUT_PLUS() },
		        'A->1' => [ 'aggregate_synonyms' ],
            },
	},

        {   -logic_name => 'get_synonyms',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::LoadSynonyms',
            -parameters => {
                'registry_conf_file' => $self->o('reg_conf'),
            },
            -flow_into  => {
                2 => [ '?accu_name=e2u_synonyms&accu_input_variable=synonym&accu_address={genome_db_id}{name}' ],
            },
	    -rc_name    => '1Gb_job',
        },

        {   -logic_name => 'aggregate_synonyms',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'e2u_synonyms'  => {},  # default value, in case the accu is empty
                'sql' => [ q/REPLACE INTO method_link_species_set_tag (method_link_species_set_id, tag, value) VALUES (#mlss_id#, "alt_synonyms", '#expr(stringify(#e2u_synonyms#))expr#')/ ],
            },
	    -rc_name    => '1Gb_job',
        },

        {
            -logic_name => 'generate_coverage_stats',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HAL::halCoverageStats',
            -rc_name    => '4Gb_job',
        }

     ];
}

1;
