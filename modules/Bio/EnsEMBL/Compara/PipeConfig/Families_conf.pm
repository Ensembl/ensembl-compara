
=pod 

=head1 NAME

    Bio::EnsEMBL::Compara::PipeConfig::Families_conf

=head1 SYNOPSIS

    #0. make sure that ProteinTree pipeline (whose EnsEMBL peptide members you want to incorporate) is already past member loading stage

    #1. update ensembl-hive, ensembl and ensembl-compara CVS repositories before each new release

    #2. you may need to update 'schema_version' in meta table to the current release number in ensembl-hive/sql/tables.sql

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Families_conf -password <your_password>

    #5. Run the "beekeeper.pl ... -loop" command suggested by init_pipeline.pl

    #6. Please remember that mapping_session, stable_id_history, member and sequence tables will have to be MERGED in an intelligent way, and not just written over.
        ReleaseCoordination.txt document explains how to do the merge correctly.

=head1 DESCRIPTION  

    The PipeConfig file for Families pipeline that should automate most of the tasks

=head1 CONTACT

  Please contact ehive-users@ebi.ac.uk mailing list with questions/suggestions.

=cut



package Bio::EnsEMBL::Compara::PipeConfig::Families_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

#       'mlss_id'         => 30035,   # it is very important to check that this value is current (commented out to make it obligatory to specify)
        'release'         => '65',
        'rel_suffix'      => '',    # an empty string by default, a letter otherwise
        'rel_with_suffix' => $self->o('release').$self->o('rel_suffix'),

        'pipeline_name'   => 'FAM_'.$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes

        'email'           => $self->o('ENV', 'USER').'@ebi.ac.uk',    # NB: your EBI address may differ from the Sanger one!

            # code directories:
        'blast_bin_dir'   => '/software/ensembl/compara/ncbi-blast-2.2.23+/bin',
        'mcl_bin_dir'     => '/software/ensembl/compara/mcl-10-201/bin',
        'mafft_root_dir'  => '/software/ensembl/compara/mafft-6.522',
            
            # data directories:
        'work_dir'        => '/lustre/scratch101/ensembl/'.$self->o('ENV', 'USER').'/families_'.$self->o('rel_with_suffix'),
        'blastdb_dir'     => $self->o('work_dir').'/blast_db',
        'blastdb_name'    => 'metazoa_'.$self->o('rel_with_suffix').'.pep',
        'tcx_name'        => 'families_'.$self->o('rel_with_suffix').'.tcx',
        'itab_name'       => 'families_'.$self->o('rel_with_suffix').'.itab',
        'mcl_name'        => 'families_'.$self->o('rel_with_suffix').'.mcl',

        'blast_params'    => '', # By default C++ binary has composition stats on and -seg masking off

        'first_n_big_families'  => 2,   # these are known to be big, so no point trying in small memory

            # resource requirements:
        'mcxload_gigs'    => 30,
        'mcl_gigs'        => 40,
        'mcl_procs'       =>  4,
        'himafft_gigs'    => 14,
        'dbresource'      => 'my'.$self->o('pipeline_db', '-host'),   # will work for compara1..compara4, but will have to be set manually otherwise
        'blast_capacity'  => 1000,                                    # work both as hive_capacity and resource-level throttle
        'mafft_capacity'  =>  400,
        'cons_capacity'   =>  400,

            # family database connection parameters (our main database):
        'pipeline_db' => {
            -host   => 'compara4',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => $self->o('ENV', 'USER').'_compara_families_'.$self->o('rel_with_suffix'),
        },

            # homology database connection parameters (we inherit half of the members and sequences from there):
        'homology_db'  => 'mysql://ensro@compara2/mm14_compara_homology_65',

            # used by the StableIdMapper as the reference:
        'prev_rel_db' => 'mysql://ensadmin:'.$self->o('password').'@compara4/lg4_ensembl_compara_64',

            # used by the StableIdMapper as the location of the master 'mapping_session' table:
        'master_db' => 'mysql://ensadmin:'.$self->o('password').'@compara1/sf5_ensembl_compara_master',    
    };
}


sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables
        
        'mkdir -p '.$self->o('work_dir'),
        'mkdir -p '.$self->o('blastdb_dir'),

            # perform "lfs setstripe" only if lfs is runnable and the directory is on lustre:
        'which lfs && lfs getstripe '.$self->o('blastdb_dir').' >/dev/null 2>/dev/null && lfs setstripe '.$self->o('blastdb_dir').' -c -1 || echo "Striping is not available on this system" ',
    ];
}


sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'email'             => $self->o('email'),                   # for automatic notifications (may be unsupported by your Meadows)

        'work_dir'          => $self->o('work_dir'),                # data directories and filenames

        'blast_bin_dir'     => $self->o('blast_bin_dir'),           # binary & script directories
        'mcl_bin_dir'       => $self->o('mcl_bin_dir'),
        'mafft_root_dir'    => $self->o('mafft_root_dir'),
    };
}


sub resource_classes {
    my ($self) = @_;
    return {
         0 => { -desc => 'default',          'LSF' => '' },
         1 => { -desc => 'urgent',           'LSF' => '-q yesterday' },
         2 => { -desc => 'long_blast',       'LSF' => '-q long -R"select['.$self->o('dbresource').'<'.$self->o('blast_capacity').'] rusage['.$self->o('dbresource').'=10:duration=10:decay=1]"' },
         3 => { -desc => 'mcxload',          'LSF' => '-C0 -M'.$self->o('mcxload_gigs').'000000 -q hugemem -R"select[mem>'.$self->o('mcxload_gigs').'000] rusage[mem='.$self->o('mcxload_gigs').'000]"' },
         4 => { -desc => 'mcl',              'LSF' => '-C0 -M'.$self->o('mcl_gigs').'000000 -n '.$self->o('mcl_procs').' -q hugemem -R"select[ncpus>='.$self->o('mcl_procs').' && mem>'.$self->o('mcl_gigs').'000] rusage[mem='.$self->o('mcl_gigs').'000] span[hosts=1]"' },
         5 => { -desc => 'himem_mafft_idmap',   'LSF' => '-C0 -M'.$self->o('himafft_gigs').'000000 -R"select['.$self->o('dbresource').'<'.$self->o('mafft_capacity').' && mem>'.$self->o('himafft_gigs').'000] rusage['.$self->o('dbresource').'=10:duration=10:decay=1:mem='.$self->o('himafft_gigs').'000]"' },
         6 => { -desc => 'lomem_mafft',      'LSF' => '-R"select['.$self->o('dbresource').'<'.$self->o('mafft_capacity').'] rusage['.$self->o('dbresource').'=10:duration=10:decay=1]"' },
    };
}


sub beekeeper_extra_cmdline_options {
    my ($self) = @_;

    return '-lifespan 1200';
}


sub pipeline_analyses {
    my ($self) = @_;
    return [

        {   -logic_name => 'copy_table_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'       => $self->o('homology_db'),
                'inputlist'     => [ 'genome_db', 'method_link', 'species_set', 'method_link_species_set', 'ncbi_taxa_node', 'ncbi_taxa_name', 'sequence', 'member' ],
                'column_names'  => [ 'table' ],
                'input_id'      => { 'src_db_conn' => '#db_conn#', 'table' => '#table#' },
                'fan_branch_code' => 2,
            },
            -input_ids => [
                {},
            ],
            -flow_into => {
                2 => [ 'copy_table'  ],
                1 => [ 'offset_and_innodbise_tables' ],  # backbone
            },
        },

        {   -logic_name    => 'copy_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'mode'          => 'overwrite',
            },
            -hive_capacity => 10,
        },

        {   -logic_name => 'offset_and_innodbise_tables',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql'   => [
                    'ALTER TABLE sequence       AUTO_INCREMENT=100000001',
                    'ALTER TABLE member         AUTO_INCREMENT=100000001',
                    'ALTER TABLE family         ENGINE=InnoDB',
                    'ALTER TABLE family_member  ENGINE=InnoDB',
                ],
            },
            -wait_for => [ 'copy_table_factory', 'copy_table' ],    # have to wait until the tables have been copied
            -flow_into => {
                    1 => [ 'genomedb_factory' ],
            },
        },

        {   -logic_name => 'genomedb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
            -parameters => {
                'mlss_id'               => $self->o('mlss_id'),

                'adaptor_name'          => 'MethodLinkSpeciesSetAdaptor',
                'adaptor_method'        => 'fetch_by_dbID',
                'method_param_list'     => [ '#mlss_id#' ],
                'object_method'         => 'species_set',

                'column_names2getters'  => { 'genome_db_id' => 'dbID' },

                'fan_branch_code'       => 2,
            },
            -flow_into => {
                2 => [ 'load_nonref_members' ],
            },
        },

        {   -logic_name => 'load_nonref_members',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMembers',
            -parameters => {
                'include_nonreference'  => 1,
                'include_reference'     => 0,
            },
            -hive_capacity => -1,
        },

        {   -logic_name => 'load_uniprot_superfactory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'       => ['FUN','HUM','MAM','ROD','VRT','INV'],
                'column_names'    => [ 'tax_div' ],
                'fan_branch_code' => 2,
            },
            -input_ids => [
                { 'input_id' => { 'uniprot_source' => 'SWISSPROT', 'tax_div' => '#tax_div#' } },
                { 'input_id' => { 'uniprot_source' => 'SPTREMBL',  'tax_div' => '#tax_div#' } },
            ],
            -wait_for => [ 'genomedb_factory', 'load_nonref_members' ],
            -flow_into => {
                2 => [ 'load_uniprot_factory' ],
                1 => [ 'snapshot_after_load_uniprot' ],
            },
            -rc_id => 1,
        },

        {   -logic_name    => 'load_uniprot_factory',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::Families::LoadUniProtIndex',
            -hive_capacity => 3,
            -flow_into => {
                2 => [ 'load_uniprot' ],
            },
            -rc_id => 1,
        },
        
        {   -logic_name    => 'load_uniprot',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::Families::LoadUniProtEntries',
            -parameters => {
                'seq_loader_name'   => 'pfetch', # {'pfetch' x 20} takes 1.3h; {'mfetch' x 7} takes 2.15h; {'pfetch' x 14} takes 3.5h; {'pfetch' x 30} takes 3h;
            },
            -hive_capacity => 20,
            -batch_size    => 100,
            -flow_into => {
                3 => [ ':////subset_member' ],
            },
            -rc_id => 0,
        },

        {   -logic_name => 'snapshot_after_load_uniprot',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'blastdb_dir'   => $self->o('blastdb_dir'),
                'blastdb_name'  => $self->o('blastdb_name'),
                'cmd'           => 'mysqldump '.$self->dbconn_2_mysql('pipeline_db', 0).' '.$self->o('pipeline_db','-dbname').' >#filename#',
                'filename'      => $self->o('work_dir').'/'.$self->o('pipeline_name').'_snapshot_after_load_uniprot.sql',
            },
            -wait_for  => [ 'load_uniprot_superfactory', 'load_uniprot_factory', 'load_uniprot' ],   # act as a funnel
            -flow_into => {
                1 => { 'dump_member_proteins' => { 'fasta_name' => '#blastdb_dir#/#blastdb_name#', 'blastdb_name' => '#blastdb_name#', 'blastdb_dir' => '#blastdb_dir#' } },
            },
        },
        
        {   -logic_name => 'dump_member_proteins',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMemberSequencesIntoFasta',
            -parameters => {
                'source_names' => [ 'ENSEMBLPEP','Uniprot/SWISSPROT','Uniprot/SPTREMBL' ],
                'idprefixed'   => 1,
            },
            -flow_into => {
                1 => [ 'make_blastdb' ],
            },
            -rc_id => 5,    # NB: now needs more memory than what is given by default (actually, 2G RAM & 2G SWAP). Does the code need checking for leaks?
        },

        {   -logic_name => 'make_blastdb',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd' => '#blast_bin_dir#/makeblastdb -dbtype prot -parse_seqids -logfile #blastdb_dir#/make_blastdb.log -in #fasta_name#',
            },
            -flow_into => {
                1 => [ 'family_blast_factory' ],
            },
            -rc_id => 1,
        },

        {   -logic_name => 'family_blast_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'      => 'SELECT DISTINCT s.sequence_id seqid FROM member m, sequence s WHERE m.sequence_id=s.sequence_id AND m.source_name IN ("Uniprot/SPTREMBL", "Uniprot/SWISSPROT", "ENSEMBLPEP") ',
                'input_id'        => { 'sequence_id' => '#_start_seqid#', 'minibatch' => '#_range_count#' },
                'step'            => 100,
                'fan_branch_code' => 2,
            },
            -flow_into => {
                2 => [ 'family_blast' ],
                1 => { 'snapshot_after_family_blast' => { 'tcx_name' => $self->o('tcx_name'), 'itab_name' => $self->o('itab_name'), 'mcl_name' => $self->o('mcl_name') } },
            },
            -rc_id => 1,
        },

        {   -logic_name    => 'family_blast',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::Families::BlastAndParseDistances',
            -parameters    => {
                'blastdb_dir'   => $self->o('blastdb_dir'),
                'blastdb_name'  => $self->o('blastdb_name'),
                'blast_params'  => $self->o('blast_params'),
                'idprefixed'    => 1,
            },
            -hive_capacity => $self->o('blast_capacity'),
            -flow_into => {
                3 => [ ':////mcl_sparse_matrix?insertion_method=REPLACE' ],
            },
            -rc_id => 2,
        },

        {   -logic_name => 'snapshot_after_family_blast',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd'       => 'mysqldump '.$self->dbconn_2_mysql('pipeline_db', 0).' '.$self->o('pipeline_db','-dbname').' >#filename#',
                'filename'  => $self->o('work_dir').'/'.$self->o('pipeline_name').'_snapshot_after_family_blast.sql',
            },
            -wait_for => [ 'family_blast' ],    # act as a funnel
            -flow_into => {
                1 => [ 'mcxload_matrix' ],
            },
        },

        {   -logic_name => 'mcxload_matrix',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'db_conn'  => $self->dbconn_2_mysql('pipeline_db', 1), # to conserve the valuable input_id space
                'cmd'      => "mysql #db_conn# -N -q -e 'select * from mcl_sparse_matrix' | #mcl_bin_dir#/mcxload -abc - -ri max -o #work_dir#/#tcx_name# -write-tab #work_dir#/#itab_name#",
            },
            -flow_into => {
                1 => [ 'mcl' ],
            },
            -rc_id => 3,
        },

        {   -logic_name => 'mcl',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd' => "#mcl_bin_dir#/mcl #work_dir#/#tcx_name# -I 2.1 -t 4 -tf 'gq(50)' -scheme 6 -use-tab #work_dir#/#itab_name# -o #work_dir#/#mcl_name#",
            },
            -flow_into => {
                1 => { 'archive_long_files' => { 'input_filenames' => '#work_dir#/#tcx_name# #work_dir#/#itab_name#' },
                       'parse_mcl'          => { 'mcl_name' => '#work_dir#/#mcl_name#' },
                },
            },
            -rc_id => 4,
        },

        {   -logic_name => 'parse_mcl',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::Families::ParseMCLintoFamilies',
            -parameters => {
                'family_prefix' => 'fam'.$self->o('rel_with_suffix'),
            },
            -hive_capacity => 20, # to enable parallel branches
            -flow_into => {
                1 => {
                    'archive_long_files'   => { 'input_filenames' => '#mcl_name#' },
                },
            },
            -rc_id => 1,
        },

# <Archiving flow-in sub-branch>
        {   -logic_name => 'archive_long_files',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd'   => 'gzip #input_filenames#',
            },
            -hive_capacity => 20, # to enable parallel branches
            -rc_id => 1,
        },
# </Archiving flow-in sub-branch>

# <Mafft sub-branch>
        {   -logic_name => 'family_mafft_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'randomize'             => 1,
                'first_n_big_families'  => $self->o('first_n_big_families'),
            },
            -hive_capacity => 20, # to enable parallel branches
            -input_ids  => [
                { 'fan_branch_code' => 2, 'inputlist'  => '#expr([1..$first_n_big_families])expr#', 'column_names' => [ 'family_id' ], },
                { 'fan_branch_code' => 3, 'inputquery' => 'SELECT family_id FROM family_member WHERE family_id>#first_n_big_families# GROUP BY family_id HAVING count(*)>1',},
            ],
            -wait_for => [ 'parse_mcl' ],
            -flow_into => {
                1 => { 'find_update_singleton_cigars' => { } },
                2 => [ 'family_mafft_big'  ],
                3 => [ 'family_mafft_main' ],
            },
            -rc_id => 1,
        },

        {   -logic_name    => 'family_mafft_main',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::Families::MafftAfamily',
            -hive_capacity => $self->o('mafft_capacity'),
            -batch_size    =>  10,
            -flow_into => {
                -1 => [ 'family_mafft_big' ],
            },
            -rc_id => 6,
        },

        {   -logic_name    => 'family_mafft_big',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::Families::MafftAfamily',
            -hive_capacity => 20,
            -batch_size    => 1,
            -rc_id => 5,
        },

        {   -logic_name => 'find_update_singleton_cigars',      # example of an SQL-session within a job (temporary table created, used and discarded)
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql'   => [
                        # find cigars:
                    "CREATE TEMPORARY TABLE singletons SELECT family_id, length(s.sequence) len, count(*) cnt FROM family_member fm, member m, sequence s WHERE fm.member_id=m.member_id AND m.sequence_id=s.sequence_id GROUP BY family_id HAVING cnt=1",
                        # update them:
                    "UPDATE family_member fm, member m, singletons st SET fm.cigar_line=concat(st.len, 'M') WHERE fm.family_id=st.family_id AND m.member_id=fm.member_id AND m.source_name<>'ENSEMBLGENE'",
                ],
            },
            -hive_capacity => 20, # to enable parallel branches
            -wait_for => [ 'family_mafft_big', 'family_mafft_main' ],    # act as a funnel
            -flow_into => {
                1 => [ 'insert_redundant_peptides' ],
            },
            -rc_id => 1,
        },

        {   -logic_name => 'insert_redundant_peptides',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => "INSERT INTO family_member SELECT family_id, m2.member_id, cigar_line FROM family_member fm, member m1, member m2 WHERE fm.member_id=m1.member_id AND m1.sequence_id=m2.sequence_id AND m1.member_id<>m2.member_id",
            },
            -hive_capacity => 20, # to enable parallel branches
            -flow_into => {
                1 => [ 'insert_ensembl_genes' ],
            },
            -rc_id => 1,
        },

        {   -logic_name => 'insert_ensembl_genes',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => "INSERT INTO family_member SELECT fm.family_id, m.gene_member_id, NULL FROM member m, family_member fm WHERE m.member_id=fm.member_id AND m.source_name='ENSEMBLPEP' GROUP BY family_id, gene_member_id",
            },
            -hive_capacity => 20, # to enable parallel branches
            -rc_id => 1,
        },
# </Mafft sub-branch>

# <Consensifier sub-branch>
        {   -logic_name => 'consensifier_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'input_id'        => { 'family_id' => '#_start_family_id#', 'minibatch' => '#_range_count#'},
                'fan_branch_code' => 2,
            },
            -hive_capacity => 20, # run the two in parallel and enable parallel branches
            -input_ids  => [
                { 'step' => 1,   'inputquery' => 'SELECT family_id FROM family WHERE family_id<=200',},
                { 'step' => 100, 'inputquery' => 'SELECT family_id FROM family WHERE family_id>200',},
            ],
            -wait_for => [ 'parse_mcl' ],
            -flow_into => {
                2 => [ 'consensifier' ],
            },
            -rc_id => 1,
        },

        {   -logic_name    => 'consensifier',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::Families::ConsensifyAfamily',
            -hive_capacity => $self->o('cons_capacity'),
            -rc_id => 0,
        },
# </Consensifier sub-branch>

# job funnel:
        {   -logic_name    => 'family_idmap',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::StableIdMapper',
            -parameters    => {
                'master_db'   => $self->o('master_db'),
                'prev_rel_db' => $self->o('prev_rel_db')
            },
            -input_ids     => [
                { 'type' => 'f', 'release' => $self->o('release'), },
            ],
            -wait_for => [ 'archive_long_files', 'insert_ensembl_genes', 'consensifier' ],
            -flow_into => {
                1 => { 'notify_pipeline_completed' => { } },
            },
            -rc_id => 5,    # NB: make sure you give it enough memory or it will crash
        },
        
        {   -logic_name => 'notify_pipeline_completed',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::NotifyByEmail',
            -parameters => {
                'subject' => "FamilyPipeline(".$self->o('rel_with_suffix').") has completed",
                'text' => "This is an automatic message.\nFamilyPipeline for release ".$self->o('rel_with_suffix')." has completed.",
            },
            -rc_id => 1,
        },

        #
        ## Please remember that the stable_id_history will have to be MERGED in an intelligent way, and not just written over.
        #
    ];
}

1;

=head1 STATS and TIMING

=head2 rel.65 stats

    sequences to cluster:       3,498,462           [ SELECT count(*) from sequence; ] - 2 min to count
    distances by Blast:         632,943,303         [ SELECT count(*) from mcl_sparse_matrix; ]

    non-reference genes:        1148                [ SELECT count(*) FROM member WHERE member_id>=100000001 AND source_name='ENSEMBLGENE'; ]
    non-reference peps:         4575                [ SELECT count(*) FROM member WHERE member_id>=100000001 AND source_name='ENSEMBLPEP'; ]

    total running time:         3.5 days            [with database congestion problems, but no bugs]
    uniprot_loading time:       2.5h                {20 x pfetch}
    blasting time:              1.9 days
    mcxload running time:       2.8h
    mcl running time:           6.4h

    memory used by mcxload:     17G RAM + 17G SWAP  [ bacct -l -f /usr/local/lsf/work/farm2/logdir/lsb.acct.2 [ SELECT max(process_id) FROM worker JOIN analysis USING(analysis_id) WHERE logic_name='mcxload_matrix' ] ]
    memory used by mcl:         21G RAM + 21G SWAP  [ bacct -l -f /usr/local/lsf/work/farm2/logdir/lsb.acct.2 [ SELECT max(process_id) FROM worker JOIN analysis USING(analysis_id) WHERE logic_name='mcl' ] ]

=head2 rel.64 stats

    sequences to cluster:       3,438,941           [ SELECT count(*) from sequence; ]
    distances by Blast:         620,587,342         [ SELECT count(*) from mcl_sparse_matrix; ]

    total running time:         5 days
    uniprot_loading time:       3h                  {20 x pfetch}
    blasting time:              1.9 days
    mcxload running time:       3.4h
    mcl running time:           7.1h

    memory used by mcxload:     17G RAM + 17G SWAP  [ bacct -l [ SELECT max(process_id) FROM worker JOIN analysis USING(analysis_id) WHERE logic_name='mcxload_matrix' ] ]
    memory used by mcl:         21G RAM + 21G SWAP  [ bacct -l [ SELECT max(process_id) FROM worker JOIN analysis USING(analysis_id) WHERE logic_name='mcl' ] ]

=head2 rel.63 stats

    sequences to cluster:       3,289,861           [ SELECT count(*) from sequence; ]
    distances by Blast:         591,086,511         [ SELECT count(*) from mcl_sparse_matrix; ]

    total running time:         3.5 days            
    uniprot_loading time:       4.3h                {20 x pfetch}
    blasting time:              2.2 days              
    mcxload running time:       2.8h                
    mcl running time:           4h                

    memory used by mcxload:     16G RAM + 16G SWAP  [ bacct -l [ SELECT max(process_id) FROM worker WHERE analysis_id=13; ] ]
    memory used by mcl:         20G RAM + 20G SWAP  [ bacct -l [ SELECT max(process_id) FROM worker WHERE analysis_id=14; ] ]

=head2 rel.62e stats

    sequences to cluster:       3,133,750           [ SELECT count(*) from sequence; ]
    uniprot_loading time:       1.6h                {20 x pfetch}
    dumping_after_loading:      1.3m
    blasting time:              2 days              
    dumping_after_blasting:     1h

=head2 rel.62d stats

    uniprot_loading time:       3.5h                {10 x pfetch}

=head2 rel.62c stats

    uniprot_loading time:       3.5h                {14 x pfetch}

=head2 rel.62b stats

    uniprot_loading time:       2.15h               {7 x mfetch}

=head2 rel.62a stats

    uniprot_loading time:       3h                  {30 x pfetch}

=head2 rel.62 stats

    sequences to cluster:       3,079,257           [ SELECT count(*) from sequence; ]
    distances by Blast:         550,334,750         [ SELECT count(*) from mcl_sparse_matrix; ]

    total running time:         4.5 days            
    uniprot_loading time:       5.1h
    blasting time:              3 days              
    mcxload running time:       1.5h                
    mcl running time:           3.7h                

    memory used by mcxload:     15G RAM + 15G SWAP  [ bacct -l [ SELECT max(process_id) FROM hive WHERE analysis_id=11; ] ]
    memory used by mcl:         18G RAM + 18G SWAP  [ bacct -l [ SELECT max(process_id) FROM hive WHERE analysis_id=12; ] ]

=head2 rel.61 stats

    sequences to cluster:       2,914,080           [ SELECT count(*) from sequence; ]
    distances by Blast:         523,104,710         [ SELECT count(*) from mcl_sparse_matrix; ]

    total running time:         3(!) days           
    uniprot_loading time:       4h                  
    blasting time:              1.7(!) days         
    mcxload running time:       8h                  
    mcl running time:           9.4h                

=head2 rel.60 stats

    sequences to cluster:       2,725,421           [ SELECT count(*) from sequence; ]
    distances by Blast:         484,837,915         [ SELECT count(*) from mcl_sparse_matrix; ]

    mcxload running time:       11.2h               
    mcl running time:           3.1h                

    memory used by mcxload:     13G RAM + 13G SWAP  
    memory used by mcl:         15G RAM + 16G SWAP  

=cut
