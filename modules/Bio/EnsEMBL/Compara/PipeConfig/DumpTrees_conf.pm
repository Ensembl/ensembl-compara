
=pod 

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::DumpTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpTrees_conf -password <your_password> -member_type protein

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpTrees_conf -password <your_password> -member_type ncrna

=head1 DESCRIPTION  

    A pipeline to dump either protein_trees or ncrna_trees.

    In rel.60 protein_trees took 2h20m to dump.

    In rel.63 protein_trees took 51m to dump.
    In rel.63 ncrna_trees   took 06m to dump.

=head1 CONTACT

  Please contact ehive-users@ebi.ac.uk mailing list with questions/suggestions.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::DumpTrees_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');   # we don't need Compara tables in this particular case

=head2 default_options

    Description : Implements default_options() interface method of Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf that is used to initialize default options.
                
=cut

sub default_options {
    my ($self) = @_;
    return {
        %{ $self->SUPER::default_options() },               # inherit other stuff from the base class

        'rel_suffix'        => '',                                              # empty string by default
        'rel_with_suffix'   => $self->o('ensembl_release').$self->o('rel_suffix'),          # for convenience
        'rel_coord'         => $self->o('ENV', 'USER'),                         # by default, the release coordinator is doing the dumps
        # Commented out to make sure people define it on the command line
        'member_type'       => 'protein',                                       # either 'protein' or 'ncrna'

        'pipeline_name'     => $self->o('member_type').'_'.$self->o('rel_with_suffix').'_dumps', # name used by the beekeeper to prefix job names on the farm

        'rel_db'      => {
            -host         => 'compara2',
            -dbname       => sprintf('%s_ensembl_compara_%s', $self->o('rel_coord'), $self->o('ensembl_release')),
            -port         => 3306,
            -user         => 'ensro',
            -pass         => '',
            -driver       => 'mysql',
        },

        'capacity'    => 100,                                                       # how many trees can be dumped in parallel
        'batch_size'  => 25,                                                        # how may trees' dumping jobs can be batched together

        'name_root'   => 'Compara.'.$self->o('rel_with_suffix').'.'.$self->o('member_type'),                              # dump file name root
        'dump_script' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/dumps/dumpTreeMSA_id.pl',           # script to dump 1 tree
        'readme_dir'  => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/docs/pipelines/READMEs',                    # where the template README files are
        'target_dir'  => '/lustre/scratch110/ensembl/'.$self->o('ENV', 'USER').'/'.$self->o('pipeline_name'),           # where the final dumps will be stored
        'work_dir'    => $self->o('target_dir').'/dump_hash',                                                           # where directory hash is created and maintained
    };
}

=head2 pipeline_create_commands

    Description : Implements pipeline_create_commands() interface method of Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf that lists the commands that will create and set up the Hive database.
                  In addition to the standard creation of the database and populating it with Hive tables and procedures it also creates directories for storing the output.

=cut

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation

        'mkdir -p '.$self->o('target_dir'),
        'mkdir -p '.$self->o('target_dir').'/emf',
        'mkdir -p '.$self->o('target_dir').'/xml',
        'mkdir -p '.$self->o('work_dir'),
    ];
}


sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
         '500Mb_job'    => {'LSF' => '-C0 -M500   -R"select[mem>500]   rusage[mem=500]"' },
         '1Gb_job'      => {'LSF' => '-C0 -M1000  -R"select[mem>1000]  rusage[mem=1000]"' },
    };
}

=head2 pipeline_analyses

    Description : Implements pipeline_analyses() interface method of Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf that defines the structure of the pipeline: analyses, jobs, rules, etc.
                  Here it defines seven analyses:

                    * 'generate_tree_ids'   generates a list of tree_ids to be dumped

                    * 'dump_a_tree'         dumps one tree in multiple formats

                    * 'generate_collations' generates five jobs that will be merging the hashed single trees

                    * 'collate_dumps'       actually merge/collate single trees into long dumps

                    * 'remove_hash'         remove the temporary hash of directories

                    * 'archive_long_files'  zip the long dumps

                    * 'md5sum'              compute md5sum for compressed files


=cut

sub pipeline_analyses {
    my ($self) = @_;
    return [

        ($self->o('member_type') eq 'protein' ?
          { -logic_name => 'dump_for_uniprot',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'db_conn'       => $self->dbconn_2_mysql('rel_db', 1),
                'file_name'     => sprintf('ensembl.GeneTree_content.e%d.txt', $self->o('ensembl_release')),
                'target_dir'    => $self->o('target_dir'),
                'query'         => sprintf q|
                    SELECT 
                        gtr.stable_id AS GeneTreeStableID, 
                        pm.stable_id AS EnsPeptideStableID,
                        gm.stable_id AS EnsGeneStableID,
                        IF(m.member_id = pm.member_id, 'Y', 'N') as Canonical
                    FROM
                        gene_tree_root gtr
                        JOIN gene_tree_node gtn ON (gtn.root_id = gtr.root_id)
                        JOIN member m on (gtn.member_id = m.member_id)
                        JOIN member gm on (m.gene_member_id = gm.member_id)
                        JOIN member pm on (gm.member_id = pm.gene_member_id)
                    WHERE
                        gtr.member_type = '%s'
                        AND gtr.clusterset_id = '%s'
                |, $self->o('member_type'), 'default'
            },
            -input_ids => [
                {'cmd' => 'mysql #db_conn# -N -q -e "#query#" > #target_dir#/#file_name#',},
            ],
            -flow_into => {
                1 => { 'archive_long_files' => { 'full_name' => '#target_dir#/#file_name#' } },
            },
          }
        : () ),

        {   -logic_name => 'dump_all_homologies',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpAllHomologiesOrthoXML',
            -parameters => {
                'compara_db'            => $self->o('rel_db'),
                'name_root'             => $self->o('name_root'),
                'target_dir'            => $self->o('target_dir'),
                'protein_tree_range'    => '0-99999999',
                'ncrna_tree_range'      => '100000000-199999999',
            },
            -input_ids => [
                {'id_range' => '#'.$self->o('member_type').'_tree_range#', 'file' => '#target_dir#/xml/#name_root#.allhomologies.orthoxml.xml'},
            ],
            -flow_into => {
                1 => {
                    'archive_long_files' => { 'full_name' => '#target_dir#/xml/#name_root#.allhomologies.orthoxml.xml', },
                    }
            },
        },

        {   -logic_name => 'dump_all_trees',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpAllTreesOrthoXML',
            -parameters => {
                'compara_db'            => $self->o('rel_db'),
                'name_root'             => $self->o('name_root'),
                'target_dir'            => $self->o('target_dir'),
                'tree_type'             => 'tree',
                'member_type'           => $self->o('member_type'),
                'file'                  => '#target_dir#/xml/#name_root#.alltrees#filesuffix#.orthoxml.xml',
            },
            -input_ids => [
                {'filesuffix' => ''},
                {'filesuffix' => '_possorthol', 'possible_orth' => 1},
            ],
            -rc_name => '1Gb_job',
            -flow_into => {
                1 => {
                    'archive_long_files' => { 'full_name' => '#target_dir#/xml/#name_root#.alltrees#filesuffix#.orthoxml.xml' },
                    }
            },
        },

        {   -logic_name => 'generate_tree_ids',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'               => $self->o('rel_db'),
                'query'                 => sprintf 'SELECT root_id AS tree_id FROM gene_tree_root WHERE tree_type = "tree" AND clusterset_id = "default" AND member_type = "%s"', $self->o('member_type'),
            },
            -input_ids => [
                { 'inputquery' => '#query#', },
            ],
            -meadow_type => 'LOCAL',
            -flow_into => {
                1 => [ 'generate_collations', 'generate_tarjobs', 'remove_hash' ],
                2 => { 'dump_a_tree'  => { 'tree_id' => '#tree_id#', 'hash_dir' => '#expr(dir_revhash($tree_id))expr#' } },
            },
        },

        {   -logic_name    => 'dump_a_tree',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'db_url'            => $self->dbconn_2_url('rel_db'),
                'dump_script'       => $self->o('dump_script'),
                'work_dir'          => $self->o('work_dir'),
                'protein_tree_args' => '-nh 1 -a 1 -nhx 1 -f 1 -fc 1 -oxml 1 -oxmlp 1 -pxml 1',
                'ncrna_tree_args'   => '-nh 1 -a 1 -nhx 1 -f 1 -oxml 1 -oxmlp 1 -pxml 1',
                'cmd'               => '#dump_script# --url #db_url# --dirpath #work_dir#/#hash_dir# --tree_id #tree_id# #'.$self->o('member_type').'_tree_args#',
            },
            -hive_capacity => $self->o('capacity'),       # allow several workers to perform identical tasks in parallel
            -batch_size    => $self->o('batch_size'),
            -rc_name       => '500Mb_job',
        },

        {   -logic_name => 'generate_collations',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'name_root'         => $self->o('name_root'),
                'protein_tree_list' => [ 'aln.emf', 'nh.emf', 'nhx.emf', 'aa.fasta', 'cds.fasta' ],
                'ncrna_tree_list'   => [ 'aln.emf', 'nh.emf', 'nhx.emf', 'aa.fasta' ],
                'inputlist'         => '#'.$self->o('member_type').'_tree_list#',
                'column_names'      => [ 'extension' ],
            },
            -wait_for => [ 'dump_a_tree' ],
            -meadow_type => 'LOCAL',
            -flow_into => {
                2 => { 'collate_dumps'  => { 'extension' => '#extension#', 'dump_file_name' => '#name_root#.#extension#'} },
            },
        },

        {   -logic_name    => 'collate_dumps',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'work_dir'      => $self->o('work_dir'),
                'target_dir'    => $self->o('target_dir'),
                'cmd'           => 'find #work_dir# -name "tree.*.#extension#" | sort -t . -k2 -n | xargs cat > #target_dir#/emf/#dump_file_name#',
            },
            -hive_capacity => 2,
            -flow_into => {
                1 => { 'archive_long_files' => { 'full_name' => '#target_dir#/emf/#dump_file_name#' } },
            },
        },

        {   -logic_name => 'generate_tarjobs',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'name_root'         => $self->o('name_root'),
                'protein_tree_list' => [ 'orthoxml.xml', 'orthoxml_possorthol.xml', 'phyloxml.xml' ],
                'ncrna_tree_list'   => [ 'orthoxml.xml', 'orthoxml_possorthol.xml', 'phyloxml.xml' ],
                'inputlist'         => '#'.$self->o('member_type').'_tree_list#',
                'column_names'      => [ 'extension' ],
            },
            -wait_for => [ 'dump_a_tree' ],
            -meadow_type => 'LOCAL',
            -flow_into => {
                2 => { 'tar_dumps'  => { 'extension' => '#extension#', 'dump_file_name' => '#name_root#.tree.#extension#'} },
            },
        },

        {   -logic_name => 'tar_dumps',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'work_dir'      => $self->o('work_dir'),
                'target_dir'    => $self->o('target_dir'),
                'member_type'     => $self->o('member_type'),
                'cmd'           => 'find #work_dir# -name "tree.*.#extension#" | sed "s:#work_dir#/*::" | sort -t . -k2 -n | tar cf #target_dir#/xml/#dump_file_name#.tar -C #work_dir# -T /dev/stdin --transform "s:^.*/:#member_type#:"',
            },
            -hive_capacity => 2,
            -flow_into => {
                1 => { 'archive_long_files' => { 'full_name' => '#target_dir#/xml/#dump_file_name#.tar' } },
            },
        },

        {   -logic_name => 'remove_hash',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'work_dir'    => $self->o('work_dir'),
                'cmd'         => 'rm -rf #work_dir#',
            },
            -wait_for => [ 'collate_dumps', 'tar_dumps' ],
            -flow_into => {
                1 => [ 'generate_prepare_dir' ],
            },
        },

        {   -logic_name => 'archive_long_files',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd'         => 'gzip #full_name#',
            },
        },

        {   -logic_name => 'generate_prepare_dir',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'readme_dir'    => $self->o('readme_dir'),
                'work_dir'      => $self->o('work_dir'),
                'target_dir'    => $self->o('target_dir'),
                'member_type'     => $self->o('member_type'),
                'inputlist'     => [
                    ['cd #target_dir#/emf ; md5sum *.gz >MD5SUM.#member_type#_trees'],
                    ['cd #target_dir#/xml ; md5sum *.gz >MD5SUM.#member_type#_trees'],
                    ['cp #readme_dir#/#member_type#_trees.dumps.txt #target_dir#/emf/README.#member_type#_trees.dumps.txt'],
                    ['cp #readme_dir#/#member_type#_trees.xml_dumps.txt #target_dir#/xml/README.#member_type#_trees.xml_dumps.txt'],
                ],
                'column_names'      => [ 'cmd' ],
            },
            -wait_for => [ 'archive_long_files', 'dump_all_homologies', 'dump_all_trees'],
            -meadow_type => 'LOCAL',
            -flow_into => {
                2 => [ 'prepare_dir' ],
            },
        },

        {   -logic_name => 'prepare_dir',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
            },
            -meadow_type => 'LOCAL',
        },
    ];
}

1;

