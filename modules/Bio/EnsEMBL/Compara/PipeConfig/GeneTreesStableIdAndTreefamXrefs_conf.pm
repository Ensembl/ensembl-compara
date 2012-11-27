## Configuration file for mapping protein_tree_stable_ids and treefam cross-references in GeneTrees pipeline

#
## Please remember that mapping_session, stable_id_history, member and sequence tables will have to be MERGED in an intelligent way, and not just written over.
#

package Bio::EnsEMBL::Compara::PipeConfig::GeneTreesStableIdAndTreefamXrefs_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'release'           => '70',
        'rel_suffix'        => 'c',    # an empty string by default, a letter otherwise
        'rel_with_suffix'   => $self->o('release').$self->o('rel_suffix'),

        'pipeline_name' => 'STID_'.$self->o('rel_with_suffix'),

            # family database connection parameters (our main database):
        'pipeline_db' => {
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => 'mm14_compara_homology_'.$self->o('rel_with_suffix'),
        },

        'prev_rel_db' => {     # used by the StableIdMapper as the reference
            -host   => 'ens-livemirror',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -dbname => 'ensembl_compara_69',
        },

        'master_db' => {     # used by the StableIdMapper as the location of the master 'mapping_session' table
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => 'sf5_ensembl_compara_master',
        },

        'idmap_gigs'  => 8,  # only 1 for ensembl-compara
    };
}


sub pipeline_create_commands {
    my ($self) = @_;

    return [ ]; # force this to be a top-up config
}


sub resource_classes {
    my ($self) = @_;
    return {
        'idmap_himem' => {'LSF' => '-C0 -M'.$self->o('idmap_gigs').'000000 -R"select[mem>'.$self->o('idmap_gigs').'000] rusage[mem='.$self->o('idmap_gigs').'000]"' },
    };
}


sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name    => 'genetrees_idmap',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::StableIdMapper',
            -parameters    => {
                'master_db'   => $self->o('master_db'),
                'prev_rel_db' => $self->o('prev_rel_db'),
                'release'     => $self->o('release'),
            },
            -input_ids     => [
                { 'type' => 't' },
            ],
            -rc_name => 'idmap_himem',
        },
        
        {   -logic_name    => 'treefam_xref_idmap',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::TreefamXrefMapper',
            -parameters    => {
                'release'     => $self->o('release'),
            },
            -input_ids     => [
                { 'tf_release' => 7, 'tag_prefix' => '', },
                { 'tf_release' => 8, 'tag_prefix' => 'dev_', },
            ],
            -rc_name => 'idmap_himem',
        },
        
        #
        ## Please remember that the stable_id_history will have to be MERGED in an intelligent way, and not just written over.
        #
    ];
}

1;

