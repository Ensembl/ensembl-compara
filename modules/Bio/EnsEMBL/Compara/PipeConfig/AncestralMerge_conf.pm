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


=pod

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::AncestralMerge_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::AncestralMerge_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV

=head1 DESCRIPTION

    A pipeline to create the EnsEMBL core database with ancestral sequences merged from different sources.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::AncestralMerge_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;
    return {
         %{$self->SUPER::default_options},

         # The production database itself (will be created). That's where the ancestral sequences will be
        'pipeline_name' => 'ensembl_ancestral_'.$self->o('rel_with_suffix'),

        'merge_script'  => $self->check_file_in_ensembl('ensembl-compara/scripts/pipeline/copy_ancestral_core.pl'),

        'compara_db'        => 'compara_curr',
        'prev_ancestral_db' => 'ancestral_prev',

        # Redefined so that the database name is *not* prefixed with the user name
        'pipeline_db'   => {
            -driver => $self->o('hive_driver'),
            -host   => $self->o('host'),
            -port   => $self->o('port'),
            -user   => $self->o('user'),
            -pass   => $self->o('password'),
            -dbname => $self->o('pipeline_name'),
        },
    };
}

sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database


sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},

        'ensembl_release'       => $self->o('ensembl_release'),
        'prev_ancestral_db'     => $self->o('prev_ancestral_db'),
    };
}


sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},    # inherit database and Hive tables' creation

        $self->db_cmd().' <'.$self->o('core_schema_sql'),      # add Core tables
    ];
}


sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'copy_coord_system',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => '#prev_ancestral_db#',
                'table'         => 'coord_system',
                'mode'          => 'insertignore',
            },
            -input_ids  => [ {} ],
            -flow_into  => {
                1 => [ 'generate_merge_jobs' ],
            },
        },

        {   -logic_name => 'generate_merge_jobs',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                # Get each EPO mlss id and its corresponding database alias from
                # ensembl_compara_${CURR_ENSEMBL_RELEASE}
                'db_conn'      => $self->o('compara_db'),
                'inputquery'   => 'SELECT mlss.method_link_species_set_id, CONCAT(ssh.name, "_ancestral") FROM method_link_species_set mlss JOIN species_set_header ssh USING (species_set_id) WHERE mlss.method_link_id = 13 AND mlss.first_release IS NOT NULL AND mlss.last_release IS NULL',
                'column_names' => [ 'mlss_id', 'from_alias' ],
            },
            -flow_into => {
                2 => [ 'merge_an_ancestor' ],
            },
        },

        {   -logic_name    => 'merge_an_ancestor',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'to_url' => $self->pipeline_url(),
                'cmd'    => [ 'perl', $self->o('merge_script'), '--reg_conf', $self->o('reg_conf'), qw(--from #from_alias# --to_url #to_url# --mlss_id #mlss_id#) ],
            },
            -hive_capacity  => 1,   # do them one-by-one
            -rc_name => '8Gb_job',
        },
    ];
}

1;
