
=pod 

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::DumpGeneTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpGeneTrees_conf -password <your_password>

=head1 DESCRIPTION  

    A pipeline to dump the GeneTrees

=head1 CONTACT

  Please contact ehive-users@ebi.ac.uk mailing list with questions/suggestions.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::DumpGeneTrees_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

=head2 default_options

    Description : Implements default_options() interface method of Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf that is used to initialize default options.
                  In addition to the standard things it defines four options:
                    o('capacity')       defines how many trees can be dumped in parallel
                
                  There are rules dependent on two options that do not have defaults (this makes them mandatory):
                    o('password')       your read-write password for creation and maintenance of the hive database

=cut

sub default_options {
    my ($self) = @_;
    return {
        'ensembl_cvs_root_dir' => $ENV{'HOME'}.'/work',                 # some Compara developers might prefer $ENV{'HOME'}.'/ensembl_main'

        'rel'         => 59,                                                  # current release number
        'tree_type'   => 'gene_trees',                                        # currently this is the only option, but it may become a proper parameter once 'ncrna_trees' are also supported

        'pipeline_name' => 'compara_dump_'.$self->o('tree_type').'_'.$self->o('rel'),    # name used by the beekeeper to prefix job names on the farm

        'pipeline_db' => {
            -host   => 'compara2',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => $ENV{'USER'}.'_'.$self->o('pipeline_name'),
        },

        'rel_db' => {
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -dbname => 'kb3_ensembl_compara_'.$self->o('rel'),
        },

        'capacity'    => 100,                                                       # how many trees can be dumped in parallel
        'batch_size'  => 25,                                                        # how may trees' dumping jobs can be batched together
        'work_dir'    => $ENV{'HOME'}.'/'.$self->o('tree_type').'_'.$self->o('rel').'/dump_hash',  # where to create the dirhash and store intermediate results of merger
        'name_root'   => 'Compara.'.$self->o('rel').'.'.$self->o('tree_type'),      # dump file name root
        'dump_script' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/dumps/dumpTreeMSA_id.pl',
        'target_dir'  => '/lustre/scratch101/ensembl/'.$ENV{'USER'}.'/'.$self->o('tree_type').'_'.$self->o('rel').'_dumps',   # target directory where the results will be stored
    };
}

=head2 pipeline_create_commands

    Description : Implements pipeline_create_commands() interface method of Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf that lists the commands that will create and set up the Hive database.
                  In addition to the standard creation of the database and populating it with Hive tables and procedures it also creates a directory for storing the output.

=cut

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation

        'mkdir -p '.$self->o('work_dir'),
        'mkdir -p '.$self->o('target_dir'),
    ];
}

=head2 pipeline_analyses

    Description : Implements pipeline_analyses() interface method of Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf that defines the structure of the pipeline: analyses, jobs, rules, etc.
                  Here it defines six analyses:

                    * 'generate_tree_ids'   generates a list of tree_ids to be dumped

                    * 'dump_a_tree'         dumps one tree in multiple formats

                    * 'generate_collations' generates five jobs that will be merging the hashed single trees

                    * 'collate_dumps'       actually merge/collate single trees into long dumps

                    * 'archive_long_files'  zip the long dumps

                    * 'move_to_target_dir'  move the long dumps into their final destination

=cut

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'generate_tree_ids',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'               => $self->o('rel_db'),
                'inputquery'            => "SELECT DISTINCT ptm.root_id FROM protein_tree_member ptm, protein_tree_tag ptt WHERE ptt.node_id=ptm.root_id AND ptt.tag='gene_count' AND ptt.value>1",
                'hashed_column_number'  => 0,
                'input_id'              => { 'tree_id' => '#_start_0#', 'hash_dir' => '#_start_1#' },
                'fan_branch_code'       => 2,
            },
            -input_ids => [
                { },
            ],
            -flow_into => {
                1 => [ 'generate_collations' ],
                2 => [ 'dump_a_tree'  ],
            },
        },

        {   -logic_name    => 'dump_a_tree',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'dump_script' => $self->o('dump_script'),
                'work_dir'    => $self->o('work_dir'),
                'db_url'      => $self->dbconn_2_url('rel_db'),
                'cmd'         => '#dump_script# --url #db_url# --dirpath #work_dir#/#hash_dir# --tree_id #tree_id# -nh 1 -a 1 -nhx 1 -f 1 -fc 1 -nc 0',
            },
            -hive_capacity => $self->o('capacity'),       # allow several workers to perform identical tasks in parallel
            -batch_size    => $self->o('batch_size'),
        },

        {   -logic_name => 'generate_collations',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'       => [ 'aln.emf', 'nh.emf', 'nhx.emf', 'aa.fasta', 'cds.fasta' ],
                'fan_branch_code' => 2,
                'name_root'       => $self->o('name_root'),
                'input_id'        => { 'extension' => '#_range_start#', 'dump_file_name' => '#name_root#.#_range_start#'},
            },
            -wait_for => [ 'dump_a_tree' ],
            -flow_into => {
                2 => [ 'collate_dumps'  ],
            },
        },

        {   -logic_name    => 'collate_dumps',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'work_dir'       => $self->o('work_dir'),
                'cmd'            => 'find #work_dir# -name "*.#extension#" | grep -v #dump_file_name# | sort -t . -k2 -n | xargs cat > #work_dir#/#dump_file_name#',
            },
            -hive_capacity => 10,
            -flow_into => {
                1 => { 'archive_long_files' => { 'full_name' => '#work_dir#/#dump_file_name#' } },
            },
        },

        {   -logic_name => 'archive_long_files',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd'   => 'gzip #full_name#',
            },
            -hive_capacity => 10,
            -flow_into => {
                1 => { 'move_to_target_dir' => { 'full_name' => '#full_name#.gz' } },
            }
        },

        {   -logic_name => 'move_to_target_dir',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'target_dir'    => $self->o('target_dir'),
                'cmd'           => 'mv #full_name# #target_dir#',
            },
            -hive_capacity => 10,
        },
    ];
}

1;

