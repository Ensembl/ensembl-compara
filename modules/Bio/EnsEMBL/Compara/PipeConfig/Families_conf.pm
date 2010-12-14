## Configuration file for the MCL family pipeline (development in progress)
#
# Don't forget to use '-lifespan 1200' on the beekeeper, otherwise the benefit of using the long queue will be lost.
# 
# rel.57+:  init_pipeline.pl execution took 8m45;   pipeline execution took 100hours (4.2 x days-and-nights) including queue waiting
# rel.58:   init_pipeline.pl execution took 5m (Albert's pipeline not working) or 50m (Albert's pipeline working);   pipeline execution took ...
# rel.58b:  init_pipeline.pl execution took 6m30, pipeline execution [with some debugging in between] took 5*24h. Should be 4*24h at most.
# rel.59:   init_pipeline.pl execution took 6m45, pipeline execution took 13.5 days [prob. because of MyISAM engine left there by mistake]
# rel.60:   init_pipeline.pl execution took 16m, pipeline execution took 6 full days (lost about one day on debugging an unusual case, code fixed)
# rel.61:   init_pipeline.pl doesn't take considerable time anymore, since table copying has moved into the pipeline proper.

#
## Please remember that mapping_session, stable_id_history, member and sequence tables will have to be MERGED in an intelligent way, and not just written over.
#


# Some rel60 stats:
#
#   2,725,421 sequences to cluster
# 484,837,915 distances computed by Blast with -seg masking off (default in C++ binary)
#
# mcxload step took 11.2h
# mcl     step took  3.1h


package Bio::EnsEMBL::Compara::PipeConfig::Families_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        release         => '61',
        rel_suffix      => '',    # an empty string by default, a letter otherwise
        rel_with_suffix => $self->o('release').$self->o('rel_suffix'),

        email           => $ENV{'USER'}.'@ebi.ac.uk',    # NB: your EBI address may differ from the Sanger one!

            # code directories:
        sec_root_dir    => '/software/ensembl/compara',
        blast_bin_dir   => $self->o('sec_root_dir') . '/ncbi-blast-2.2.23+/bin',
        mcl_bin_dir     => $self->o('sec_root_dir') . '/mcl-10-201/bin',
        mafft_root_dir  => $self->o('sec_root_dir') . '/mafft-6.522',
            
            # data directories:
        work_dir        => $ENV{'HOME'}.'/families_'.$self->o('rel_with_suffix'),
        blastdb_dir     => '/lustre/scratch101/ensembl/'.$ENV{'USER'}.'/families_'.$self->o('rel_with_suffix'),
        blastdb_name    => 'metazoa_'.$self->o('rel_with_suffix').'.pep',
        tcx_name        => 'families_'.$self->o('rel_with_suffix').'.tcx',
        itab_name       => 'families_'.$self->o('rel_with_suffix').'.itab',
        mcl_name        => 'families_'.$self->o('rel_with_suffix').'.mcl',

        blast_params    => '', # By default C++ binary has composition stats on and -seg masking off

            # resource requirements:
        mcxload_gigs    => 30,                                      # 13G RAM + 13G SWAP according to bacct -l in rel.60
        mcl_gigs        => 40,                                      # 15G RAM + 16G SWAP accorting to bacct -l in rel.60
        mcl_procs       =>  4,
        himafft_gigs    => 14,
        dbresource      => 'my'.$self->o('pipeline_db', '-host'),   # will work for compara1..compara3, but will have to be set manually otherwise
        blast_capacity  => 1000,                                    # work both as hive_capacity and resource-level throttle
        mafft_capacity  =>  400,
        cons_capacity   =>  400,

            # family database connection parameters (our main database):
        pipeline_db => {
            -host   => 'compara2',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => $ENV{'USER'}.'_compara_families_'.$self->o('rel_with_suffix'),
        },

            # homology database connection parameters (we inherit half of the members and sequences from there):
        homology_db  => {
            -host   => 'compara2',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => 'lg4_compara_homology_'.$self->o('release'),
        },

        prev_rel_db => {     # used by the StableIdMapper as the reference
            -host   => 'ens-livemirror',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -dbname => 'ensembl_compara_60',
        },

        master_db => {     # used by the StableIdMapper as the location of the master 'mapping_session' table
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => 'sf5_ensembl_compara_master',
        },
    };
}


sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables
        
        'mkdir -p '.$self->o('blastdb_dir'),
        'mkdir -p '.$self->o('work_dir'),
    ];
}


sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        'pipeline_name'     => 'FAM_'.$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes
        'email'             => $self->o('email'),                   # for automatic notifications (may be unsupported by your Meadows)

        'work_dir'          => $self->o('work_dir'),                # data directories and filenames

        'blast_bin_dir'     => $self->o('blast_bin_dir'),           # binary & script directories
        'mcl_bin_dir'       => $self->o('mcl_bin_dir'),
        'mafft_root_dir'    => $self->o('mafft_root_dir'),

        'idprefixed'        => 1,                                   # other options to sync different analyses
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



sub pipeline_analyses {
    my ($self) = @_;
    return [

        {   -logic_name => 'copy_table_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'   => $self->o('homology_db'),
                'inputlist' => [ 'genome_db', 'method_link', 'species_set', 'method_link_species_set', 'ncbi_taxa_name', 'ncbi_taxa_node', 'member', 'sequence' ],
                'input_id'  => { 'src_db_conn' => '#db_conn#', 'table' => '#_range_start#' },
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
                    'ALTER TABLE member         AUTO_INCREMENT=100000001',
                    'ALTER TABLE sequence       AUTO_INCREMENT=100000001',
                    'ALTER TABLE family         ENGINE=InnoDB',
                    'ALTER TABLE family_member  ENGINE=InnoDB',
                ],
            },
            -wait_for => [ 'copy_table_factory', 'copy_table' ],    # have to wait until the tables have been copied
        },

        {   -logic_name => 'load_uniprot_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'blastdb_dir'     => $self->o('blastdb_dir'),
                'blastdb_name'    => $self->o('blastdb_name'),
                'inputlist'       => ['FUN','HUM','MAM','ROD','VRT','INV'],
                'fan_branch_code' => 2,
            },
            -input_ids => [
                { 'input_id' => { 'srs' => 'SWISSPROT', 'tax_div' => '#_range_start#' } },
                { 'input_id' => { 'srs' => 'SPTREMBL',  'tax_div' => '#_range_start#' } },
            ],
            -wait_for => [ 'offset_and_innodbise_tables' ],
            -flow_into => {
                2 => [ 'load_uniprot' ],
                1 => { 'remove_members_with_unknown_taxa' => { 'fasta_name' => '#work_dir#/#blastdb_name#', 'blastdb_name' => '#blastdb_name#', 'blastdb_dir' => '#blastdb_dir#' } },
            },
            -rc_id => 1,
        },

        {   -logic_name    => 'load_uniprot',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::LoadUniProt',
            -hive_capacity => 20,
            -rc_id => 0,
        },
        
                # LoadUniProt.pm actually does its best to skip unknown taxa_ids, so the following check is needed very rarely:
                #
        {   -logic_name => 'remove_members_with_unknown_taxa',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => "DELETE member FROM member LEFT JOIN ncbi_taxa_name ON member.taxon_id = ncbi_taxa_name.taxon_id WHERE ncbi_taxa_name.taxon_id IS NULL",
            },
            -wait_for  => [ 'load_uniprot' ],   # act as a funnel
            -flow_into => {
                1 => [ 'dump_member_proteins' ],
            },
            -rc_id => 1,
        },

        {   -logic_name => 'dump_member_proteins',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMemberSequencesIntoFasta',
            -parameters => {
                'source_names' => [ 'ENSEMBLPEP','Uniprot/SWISSPROT','Uniprot/SPTREMBL' ],
            },
            -flow_into => {
                1 => [ 'make_blastdb' ],
            },
            -rc_id => 1,
        },

        {   -logic_name => 'make_blastdb',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd' => '#blast_bin_dir#/makeblastdb -dbtype prot -parse_seqids -logfile #work_dir#/make_blastdb.log -in #fasta_name#',
            },
            -flow_into => {
                1 => [ 'copy_blastdb_over' ],
            },
            -rc_id => 1,
        },

        {   -logic_name => 'copy_blastdb_over',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd' => 'cp #fasta_name#* #blastdb_dir#',
            },
            -flow_into => {
                1 => [ 'family_blast_factory' ],
            },
            -rc_id => 1,
        },

        {   -logic_name => 'family_blast_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'      => 'SELECT DISTINCT s.sequence_id FROM member m, sequence s WHERE m.sequence_id=s.sequence_id AND m.source_name IN ("Uniprot/SPTREMBL", "Uniprot/SWISSPROT", "ENSEMBLPEP") ',
                'input_id'        => { 'sequence_id' => '#_range_start#', 'minibatch' => '#_range_count#', 'blastdb_dir' => '#blastdb_dir#', 'blastdb_name' => '#blastdb_name#' },
                'step'            => 100,
                'fan_branch_code' => 2,
            },
            -flow_into => {
                2 => [ 'family_blast' ],
                1 => { 'mcxload_matrix' => { 'tcx_name' => $self->o('tcx_name'), 'itab_name' => $self->o('itab_name'), 'mcl_name' => $self->o('mcl_name') } },
            },
            -rc_id => 1,
        },

        {   -logic_name    => 'family_blast',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::FamilyBlast',
            -parameters    => {
                'blast_params' => $self->o('blast_params'),
            },
            -hive_capacity => $self->o('blast_capacity'),
            -rc_id => 2,
        },

        {   -logic_name => 'mcxload_matrix',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'db_conn'  => $self->dbconn_2_mysql('pipeline_db', 1), # to conserve the valuable input_id space
                'cmd'      => "mysql #db_conn# -N -q -e 'select * from mcl_sparse_matrix' | #mcl_bin_dir#/mcxload -abc - -ri max -o #work_dir#/#tcx_name# -write-tab #work_dir#/#itab_name#",
            },
            -wait_for => [ 'family_blast' ],    # act as a funnel
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
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FamilyParseMCL',
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
                'randomize'  => 1,
                'input_id'   => { 'family_id' => '#_range_start#' },
            },
            -hive_capacity => 20, # to enable parallel branches
            -input_ids  => [
                { 'fan_branch_code' => 2, 'inputlist'  => [ 1, 2 ],},
                { 'fan_branch_code' => 3, 'inputquery' => 'SELECT family_id FROM family_member WHERE family_id>2 GROUP BY family_id HAVING count(*)>1',},
            ],
            -wait_for => [ 'parse_mcl' ],
            -flow_into => {
                1 => { 'find_update_singleton_cigars' => { } },
                2 => [ 'family_mafft_big'  ],
                3 => [ 'family_mafft_main' ],
            },
            -rc_id => 1,
        },

        {   -logic_name    => 'family_mafft_big',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::FamilyMafft',
            -hive_capacity => 20,
            -batch_size    => 1,
            -rc_id => 5,
        },

        {   -logic_name    => 'family_mafft_main',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::FamilyMafft',
            -hive_capacity => $self->o('mafft_capacity'),
            -batch_size    =>  10,
            -rc_id => 6,
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
                'input_id'        => { 'family_id' => '#_range_start#', 'minibatch' => '#_range_count#'},
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
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::FamilyConsensifier',
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
