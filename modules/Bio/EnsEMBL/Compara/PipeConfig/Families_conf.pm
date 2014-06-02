=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::Families_conf

=head1 SYNOPSIS

    #0. make sure that ProteinTree pipeline (whose EnsEMBL peptide members you want to incorporate) is already past member loading stage

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

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

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut



package Bio::EnsEMBL::Compara::PipeConfig::Families_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

#       'mlss_id'         => 30043,         # it is very important to check that this value is current (commented out to make it obligatory to specify)
        'host'            => 'compara2',    # where the pipeline database will be created
        'rel_suffix'      => '',            # an empty string by default, a letter otherwise
        'rel_with_suffix' => $self->o('ensembl_release').$self->o('rel_suffix'),
        'file_basename'   => 'metazoa_families_'.$self->o('rel_with_suffix'),

        'pipeline_name'   => 'compara_families_'.$self->o('rel_with_suffix'),   # also used to differentiate submitted processes

        'email'           => $self->o('ENV', 'USER').'@ebi.ac.uk',    # NB: your EBI address may differ from the Sanger one!

            # code directories:
        'blast_bin_dir'   => '/software/ensembl/compara/ncbi-blast-2.2.28+/bin',
        'mcl_bin_dir'     => '/software/ensembl/compara/mcl-12-135/bin',
        'mafft_root_dir'  => '/software/ensembl/compara/mafft-7.113',
            
            # data directories:
        'work_dir'        => '/lustre/scratch109/ensembl/'.$self->o('ENV', 'USER').'/'.$self->o('pipeline_name'),
        'blastdb_dir'     => $self->o('work_dir').'/blast_db',
        'blastdb_name'    => $self->o('file_basename').'.pep',

        'uniprot_version' => 'uniprot',

        'blast_params'    => '', # By default C++ binary has composition stats on and -seg masking off

        'first_n_big_families'  => 2,   # these are known to be big, so no point trying in small memory

            # resource requirements:
        'blast_gigs'      =>  2,
        'blast_hm_gigs'   =>  4,
        'mcl_gigs'        => 50,
        'mcl_procs'       =>  4,
        'lomafft_gigs'    =>  4,
        'himafft_gigs'    => 14,
        'dbresource'      => 'my'.$self->o('host'),                 # will work for compara1..compara4, but will have to be set manually otherwise
        'blast_capacity'  => 2000,                                  # work both as hive_capacity and resource-level throttle
        'mafft_capacity'  =>  400,
        'cons_capacity'   =>  400,
        'reservation_sfx' => '',    # set to '000' for farm2, to '' for farm3 and EBI

            # homology database connection parameters (we inherit half of the members and sequences from there):
#        'protein_trees_db'  => 'mysql://ensro@compara1/mm14_protein_trees_'.$self->o('ensembl_release'),
        'protein_trees_db'  => 'mysql://ensro@compara1/mm14_protein_trees_'.$self->o('rel_with_suffix'),

            # used by the StableIdMapper as the reference:
        'prev_rel_db' => 'mysql://ensadmin:'.$self->o('password').'@compara3/mp12_ensembl_compara_74',

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
        'blastdb_dir'       => $self->o('blastdb_dir'),
        'file_basename'     => $self->o('file_basename'),

        'blast_bin_dir'     => $self->o('blast_bin_dir'),           # binary & script directories
        'mcl_bin_dir'       => $self->o('mcl_bin_dir'),
        'mafft_root_dir'    => $self->o('mafft_root_dir'),
    };
}


sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

        'urgent'       => { 'LSF' => '-q yesterday' },
        'LongBlast'    => { 'LSF' => [ '-C0 -M'.$self->o('blast_gigs').$self->o('reservation_sfx').'000 -q long -R"select['.$self->o('dbresource').'<'.$self->o('blast_capacity').' && mem>'.$self->o('blast_gigs').'000] rusage['.$self->o('dbresource').'=10:duration=10:decay=1, mem='.$self->o('blast_gigs').'000]"', '-lifespan 1440' ]  },
        'LongBlastHM'  => { 'LSF' => [ '-C0 -M'.$self->o('blast_hm_gigs').$self->o('reservation_sfx').'000 -q long -R"select['.$self->o('dbresource').'<'.$self->o('blast_capacity').' && mem>'.$self->o('blast_hm_gigs').'000] rusage['.$self->o('dbresource').'=10:duration=10:decay=1, mem='.$self->o('blast_hm_gigs').'000]"', '-lifespan 1440' ]  },
        'BigMcxload'   => { 'LSF' => '-C0 -M'.$self->o('mcl_gigs').$self->o('reservation_sfx').'000 -q hugemem -R"select[mem>'.$self->o('mcl_gigs').'000] rusage[mem='.$self->o('mcl_gigs').'000]"' },
        'BigMcl'       => { 'LSF' => '-C0 -M'.$self->o('mcl_gigs').$self->o('reservation_sfx').'000 -n '.$self->o('mcl_procs').' -q hugemem -R"select[ncpus>='.$self->o('mcl_procs').' && mem>'.$self->o('mcl_gigs').'000] rusage[mem='.$self->o('mcl_gigs').'000] span[hosts=1]"' },
        'BigMafft'     => { 'LSF' => '-C0 -M'.$self->o('himafft_gigs').$self->o('reservation_sfx').'000 -q long -R"select['.$self->o('dbresource').'<'.$self->o('mafft_capacity').' && mem>'.$self->o('himafft_gigs').'000] rusage['.$self->o('dbresource').'=10:duration=10:decay=1, mem='.$self->o('himafft_gigs').'000]"' },
        '4GigMem'      => { 'LSF' => '-C0 -M'.$self->o('lomafft_gigs').$self->o('reservation_sfx').'000 -R"select['.$self->o('dbresource').'<'.$self->o('mafft_capacity').' && mem>'.$self->o('lomafft_gigs').'000] rusage['.$self->o('dbresource').'=10:duration=10:decay=1, mem='.$self->o('lomafft_gigs').'000]"' },
        '2GigMem'      => { 'LSF' => '-C0 -M2'.$self->o('reservation_sfx').'000 -R"select[mem>2000] rusage[mem=2000]"' },
    };
}


sub pipeline_analyses {
    my ($self) = @_;
    return [

        {   -logic_name => 'copy_table_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'     => [
                                        [ $self->o('protein_trees_db')   => 'genome_db' ],       # we need them in "located" state
                                        [ $self->o('protein_trees_db')   => 'sequence' ],
                                        [ $self->o('protein_trees_db')   => 'seq_member' ],
                                        [ $self->o('protein_trees_db')   => 'gene_member' ],
                                        [ $self->o('master_db')     => 'ncbi_taxa_node' ],
                                        [ $self->o('master_db')     => 'ncbi_taxa_name' ],
                                        [ $self->o('master_db')     => 'method_link' ],
                                        [ $self->o('master_db')     => 'species_set' ],
                                        [ $self->o('master_db')     => 'method_link_species_set' ],
                                        [ $self->o('master_db')     => 'dnafrag' ],
                                    ],
                'column_names'  => [ 'src_db_conn', 'table' ],
            },
            -input_ids => [ { }, ],
            -flow_into => {
                '2->A' => [ 'copy_table' ],
                'A->1' => [ 'offset_and_innodbise_tables' ],  # backbone
            },
        },

        {   -logic_name    => 'copy_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'mode'          => 'overwrite',
            },
            -analysis_capacity => 10,
        },

        {   -logic_name => 'offset_and_innodbise_tables',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql'   => [
                    'ALTER TABLE sequence                   AUTO_INCREMENT=200000001',
                    'ALTER TABLE gene_member                AUTO_INCREMENT=200000001',
                    'ALTER TABLE seq_member                 AUTO_INCREMENT=200000001',
                    'ALTER TABLE method_link                ENGINE=InnoDB',
                    'ALTER TABLE ncbi_taxa_node             ENGINE=InnoDB',
                    'ALTER TABLE ncbi_taxa_name             ENGINE=InnoDB',
                    'ALTER TABLE species_set                ENGINE=InnoDB',
                    'ALTER TABLE method_link_species_set    ENGINE=InnoDB',
                    'ALTER TABLE dnafrag                    ENGINE=InnoDB',
                    'ALTER TABLE dnafrag                    AUTO_INCREMENT=200000000000001',
                ],
            },
            -flow_into => {
                    1 => [ 'genomedb_factory' ],
            },
        },

        {   -logic_name => 'genomedb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
            -parameters => {
                'mlss_id'               => $self->o('mlss_id'),
                'call_list'             => [ 'compara_dba', 'get_MethodLinkSpeciesSetAdaptor', [ 'fetch_by_dbID', '#mlss_id#'], 'species_set_obj', 'genome_dbs' ],
                'column_names2getters'  => { 'genome_db_id' => 'dbID' },
            },
            -flow_into => {
                '2->A' => [ 'load_nonref_members' ],
                'A->1' => [ 'load_uniprot_superfactory' ],
            },
        },

        {   -logic_name => 'load_nonref_members',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMembers',
            -parameters => {
                'include_nonreference'  => 1,
                'include_patches'       => 1,
                'include_reference'     => 0,
                'store_missing_dnafrags'=> 1,
            },
            -rc_name => '2GigMem',
        },

        {   -logic_name => 'load_uniprot_superfactory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'column_names'    => [ 'uniprot_source', 'tax_div' ],
                'inputlist'       => [
                    [ 'SWISSPROT', 'FUN' ],
                    [ 'SWISSPROT', 'HUM' ],
                    [ 'SWISSPROT', 'MAM' ],
                    [ 'SWISSPROT', 'ROD' ],
                    [ 'SWISSPROT', 'VRT' ],
                    [ 'SWISSPROT', 'INV' ],

                    [ 'SPTREMBL',  'FUN' ],
                    [ 'SPTREMBL',  'HUM' ],
                    [ 'SPTREMBL',  'MAM' ],
                    [ 'SPTREMBL',  'ROD' ],
                    [ 'SPTREMBL',  'VRT' ],
                    [ 'SPTREMBL',  'INV' ],
                ],
            },
            -flow_into => {
                '2->A' => [ 'load_uniprot_factory' ],
                'A->1' => [ 'snapshot_after_load_uniprot' ],
            },
            -rc_name => 'urgent',
        },

        {   -logic_name    => 'load_uniprot_factory',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::Families::LoadUniProtIndex',
            -parameters => {
                'uniprot_version'   => $self->o('uniprot_version'),
            },
            -analysis_capacity => 3,
            -flow_into => {
                2 => [ 'load_uniprot' ],
            },
            -rc_name => '2GigMem',
        },
        
        {   -logic_name    => 'load_uniprot',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::Families::LoadUniProtEntries',
            -parameters => {
                'seq_loader_name'   => 'pfetch', # {'pfetch' x 20} takes 1.3h; {'mfetch' x 7} takes 2.15h; {'pfetch' x 14} takes 3.5h; {'pfetch' x 30} takes 3h;
            },
            -analysis_capacity => 20,
            -batch_size    => 100,
            -rc_name => '2GigMem',
        },

        {   -logic_name => 'snapshot_after_load_uniprot',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'output_file'      => '#work_dir#/snapshot_after_load_uniprot.sql',
                'blastdb_name'  => $self->o('blastdb_name'),
            },
            -flow_into => {
                1 => { 'dump_member_proteins' => { 'fasta_name' => '#blastdb_dir#/#blastdb_name#', 'blastdb_name' => '#blastdb_name#' } },
            },
        },
        
        {   -logic_name => 'dump_member_proteins',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMemberSequencesIntoFasta',
            -parameters => {
                'idprefixed'   => 1,
            },
            -flow_into => {
                1 => [ 'make_blastdb' ],
            },
            -rc_name => '4GigMem',    # NB: now needs more memory than what is given by default (actually, 2G RAM & 2G SWAP). Does the code need checking for leaks?
        },

        {   -logic_name => 'make_blastdb',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd' => '#blast_bin_dir#/makeblastdb -dbtype prot -parse_seqids -logfile #blastdb_dir#/make_blastdb.log -in #fasta_name#',
            },
            -flow_into => {
                1 => [ 'blast_factory' ],
            },
            -rc_name => '2GigMem',
        },

        {   -logic_name => 'blast_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'      => 'SELECT DISTINCT m.sequence_id seqid FROM seq_member m',
                'step'            => 100,
            },
            -flow_into => {
                '2->A' => { 'blast' => { 'sequence_id' => '#_start_seqid#', 'minibatch' => '#_range_count#' } },
                'A->1' => [ 'snapshot_after_blast' ],
            },
            -rc_name => '2GigMem',
        },

        {   -logic_name    => 'blast',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::Families::BlastAndParseDistances',
            -parameters    => {
                'blastdb_name'  => $self->o('blastdb_name'),
                'blast_params'  => $self->o('blast_params'),
                'idprefixed'    => 1,
            },
            -hive_capacity => $self->o('blast_capacity'),
            -max_retry_count => 6,
            -flow_into => {
                3 => [ ':////mcl_sparse_matrix?insertion_method=REPLACE' ],
                -1 => 'blast_himem',
            },
            -rc_name => 'LongBlast',
        },

        {   -logic_name    => 'blast_himem',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::Families::BlastAndParseDistances',
            -parameters    => {
                'blastdb_name'  => $self->o('blastdb_name'),
                'blast_params'  => $self->o('blast_params'),
                'idprefixed'    => 1,
            },
            -hive_capacity => $self->o('blast_capacity'),
            -flow_into => {
                3 => [ ':////mcl_sparse_matrix?insertion_method=REPLACE' ],
            },
            -rc_name => 'LongBlastHM',
        },

        {   -logic_name => 'snapshot_after_blast',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'output_file'  => '#work_dir#/snapshot_after_blast.sql',
            },
            -flow_into => {
                1 => [ 'mcxload_matrix' ],
            },
        },

        {   -logic_name => 'mcxload_matrix',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'db_conn'  => $self->dbconn_2_mysql('pipeline_db', 1), # to conserve the valuable input_id space
                'cmd'      => "mysql #db_conn# -N -q -e 'select * from mcl_sparse_matrix' | #mcl_bin_dir#/mcxload -abc - -ri max -o #work_dir#/#file_basename#.tcx -write-tab #work_dir#/#file_basename#.itab",
            },
            -flow_into => {
                1 => [ 'mcl' ],
            },
            -rc_name => 'BigMcxload',
        },

        {   -logic_name => 'mcl',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd' => "#mcl_bin_dir#/mcl #work_dir#/#file_basename#.tcx -I 2.1 -t 4 -tf 'gq(50)' -scheme 6 -use-tab #work_dir#/#file_basename#.itab -o #work_dir#/#file_basename#.mcl",
            },
            -flow_into => {
                '1->A' => { 'archive_long_files' => { 'input_filenames' => '#work_dir#/#file_basename#.tcx #work_dir#/#file_basename#.itab' },
                            'parse_mcl'          => { 'mcl_name' => '#work_dir#/#file_basename#.mcl' },
                },
                'A->1'  => [ 'stable_id_map' ],
            },
            -rc_name => 'BigMcl',
        },

        {   -logic_name => 'parse_mcl',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::Families::ParseMCLintoFamilies',
            -parameters => {
                'family_prefix'         => 'fam'.$self->o('rel_with_suffix'),
                'first_n_big_families'  => $self->o('first_n_big_families'),
            },
            -hive_capacity => 20, # to enable parallel branches
            -flow_into => {
                1 => {
                    'archive_long_files'    => { 'input_filenames' => '#work_dir#/#file_basename#.mcl' },
                    'consensifier_factory'  => [
                        { 'step' => 1,   'inputquery' => 'SELECT family_id FROM family WHERE family_id<=200',},
                        { 'step' => 100, 'inputquery' => 'SELECT family_id FROM family WHERE family_id>200',},
                    ],
                },
                '1->A' => {
                    'mafft_factory' => [
                        { 'fan_branch_code' => 2, 'inputquery' => 'SELECT family_id FROM family_member WHERE family_id<=#first_n_big_families# GROUP BY family_id HAVING count(*)>1', },
                        { 'fan_branch_code' => 3, 'inputquery' => 'SELECT family_id FROM family_member WHERE family_id >#first_n_big_families# GROUP BY family_id HAVING count(*)>1', },
                    ],
                },
                'A->1' => {
                    'find_update_singleton_cigars' => { },
                }
            },
            -rc_name => 'urgent',
        },

# <Archiving flow-in sub-branch>
        {   -logic_name => 'archive_long_files',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd'   => 'gzip #input_filenames#',
            },
            -hive_capacity => 20, # to enable parallel branches
            -rc_name => 'urgent',
        },
# </Archiving flow-in sub-branch>

# <Mafft sub-branch>
        {   -logic_name => 'mafft_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'randomize'             => 1,
            },
            -hive_capacity => 20, # to enable parallel branches
            -flow_into => {
                2 => [ 'mafft_big'  ],
                3 => [ 'mafft_main' ],
            },
            -rc_name => '4GigMem',
        },

        {   -logic_name         => 'mafft_main',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::Families::MafftAfamily',
            -hive_capacity      => $self->o('mafft_capacity'),
            -batch_size         => 10,
            -max_retry_count    => 6,
            -flow_into => {
                -1 => [ 'mafft_big' ],
            },
            -rc_name => '2GigMem',
        },

        {   -logic_name    => 'mafft_big',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::Families::MafftAfamily',
            -hive_capacity => 20,
            -batch_size    => 1,
            -rc_name => 'BigMafft',
        },

        {   -logic_name => 'find_update_singleton_cigars',      # example of an SQL-session within a job (temporary table created, used and discarded)
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql'   => [
                        # find cigars:
                    "CREATE TEMPORARY TABLE singletons SELECT family_id, length(s.sequence) len, count(*) cnt FROM family_member fm, seq_member m, sequence s WHERE fm.seq_member_id=m.seq_member_id AND m.sequence_id=s.sequence_id GROUP BY family_id HAVING cnt=1",
                        # update them:
                    "UPDATE family_member fm, seq_member m, singletons st SET fm.cigar_line=concat(st.len, 'M') WHERE fm.family_id=st.family_id AND m.seq_member_id=fm.seq_member_id",
                ],
            },
            -hive_capacity => 20, # to enable parallel branches
            -flow_into => {
                1 => [ 'insert_redundant_peptides' ],
            },
            -rc_name => 'urgent',
        },

        {   -logic_name => 'insert_redundant_peptides',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => "INSERT INTO family_member SELECT family_id, m2.seq_member_id, cigar_line FROM family_member fm, seq_member m1, seq_member m2 WHERE fm.seq_member_id=m1.seq_member_id AND m1.sequence_id=m2.sequence_id AND m1.seq_member_id<>m2.seq_member_id",
            },
            -hive_capacity => 20, # to enable parallel branches
            -rc_name => 'urgent',
        },

# </Mafft sub-branch>

# <Consensifier sub-branch>
        {   -logic_name => 'consensifier_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => { },
            -hive_capacity => 20, # run the two in parallel and enable parallel branches
            -flow_into => {
                2 => { 'consensifier' => { 'family_id' => '#_start_family_id#', 'minibatch' => '#_range_count#'} },
            },
            -rc_name => '2GigMem',
        },

        {   -logic_name    => 'consensifier',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::Families::ConsensifyAfamily',
            -hive_capacity => $self->o('cons_capacity'),
        },
# </Consensifier sub-branch>

# job funnel:
        {   -logic_name    => 'stable_id_map',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::StableIdMapper',
            -parameters    => {
                'master_db'   => $self->o('master_db'),
                'prev_rel_db' => $self->o('prev_rel_db'),
                'type'        => 'f',
                'release'     => $self->o('ensembl_release'),
            },
            -flow_into => {
                1 => [ 'notify_pipeline_completed' ],
            },
            -rc_name => '4GigMem',    # NB: make sure you give it enough memory or it will crash
        },
        
        {   -logic_name => 'notify_pipeline_completed',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::NotifyByEmail',
            -parameters => {
                'subject' => "FamilyPipeline(".$self->o('pipeline_name').") has completed",
                'text' => "This is an automatic message.\nFamilyPipeline for release ".$self->o('pipeline_name')." has completed.",
            },
            -rc_name => 'urgent',
        },

        #
        ## Please remember that the stable_id_history will have to be MERGED in an intelligent way, and not just written over.
        #
    ];
}

1;

=head1 STATS and TIMING

=head2 rel.75 stats

    sequences to cluster:       5,611,558           [ SELECT count(*) from sequence; ]
    distances by Blast:         1,063,102,033       [ SELECT count(*) from mcl_sparse_matrix; ] -- took 27 minutes to run

    non-reference genes:         3090               [ SELECT count(*) FROM member WHERE member_id>=200000001 AND source_name='ENSEMBLGENE'; ]
    non-reference peps:         10006               [ SELECT count(*) FROM member WHERE member_id>=200000001 AND source_name='ENSEMBLPEP'; ]

    uniprot loading method:     { 20 x pfetch }

    total running time:         17.0d               [ call time_analysis('%'); ]
    uniprot_loading time:        2.8h               [ call time_analysis('load_uniprot%'); ]
    blasting time:               4.7d               [ call time_analysis('blast%'); ]
    mcxload running time:        0.9d               [ call time_analysis('mcxload_matrix'); ]
    mcl running time:            1.1d               [ call time_analysis('mcl'); ]

    memory used by mcxload:     28.5G               [ SELECT mem_megs, swap_megs FROM analysis_base JOIN worker USING(analysis_id) JOIN lsf_report USING(process_id) WHERE logic_name='mcxload_matrix'; ]
    memory used by mcl:         42.5G               [ SELECT mem_megs, swap_megs FROM analysis_base JOIN worker USING(analysis_id) JOIN lsf_report USING(process_id) WHERE logic_name='mcl'; ]

=head2 rel.74 stats

    sequences to cluster:       5,293,375           [ SELECT count(*) from sequence; ]
    distances by Blast:         1,000,667,203       [ SELECT count(*) from mcl_sparse_matrix; ] -- took 27 minutes to run

    non-reference genes:         3090               [ SELECT count(*) FROM member WHERE member_id>=200000001 AND source_name='ENSEMBLGENE'; ]
    non-reference peps:         10006               [ SELECT count(*) FROM member WHERE member_id>=200000001 AND source_name='ENSEMBLPEP'; ]

    uniprot loading method:     { 20 x pfetch }

    total running time:          9.3d               [ call time_analysis('%'); ]
    uniprot_loading time:        2.8h               [ call time_analysis('load_uniprot%'); ]
    blasting time:               5.2d               [ call time_analysis('blast%'); ]
    mcxload running time:        1.5d               [ call time_analysis('mcxload_matrix'); ]
    mcl running time:            1.8d               [ call time_analysis('mcl'); ]

    memory used by mcxload:     25.5G               [ SELECT mem_megs, swap_megs FROM analysis_base JOIN worker USING(analysis_id) JOIN lsf_report USING(process_id) WHERE logic_name='mcxload_matrix'; ]
    memory used by mcl:         ?G                  [ SELECT mem_megs, swap_megs FROM analysis_base JOIN worker USING(analysis_id) JOIN lsf_report USING(process_id) WHERE logic_name='mcl'; ]

=head2 rel.73 stats

    sequences to cluster:       5,157,846           [ SELECT count(*) from sequence; ]
    distances by Blast:         970,366,718         [ SELECT count(*) from mcl_sparse_matrix; ]

    non-reference genes:        2965                [ SELECT count(*) FROM member WHERE member_id>=200000001 AND source_name='ENSEMBLGENE'; ]
    non-reference peps:         9711                [ SELECT count(*) FROM member WHERE member_id>=200000001 AND source_name='ENSEMBLPEP'; ]

    uniprot loading method:     { 20 x pfetch }

    total running time:          9.5d               [ call time_analysis('%'); ]
    uniprot_loading time:       10.6h               [ call time_analysis('load_uniprot%'); ]
    blasting time:               7.2d               [ call time_analysis('blast%'); ]
    mcxload running time:        2.4h               [ call time_analysis('mcxload_matrix'); ]
    mcl running time:            7.8h               [ call time_analysis('mcl'); ]

    memory used by mcxload:     25.8G               [ SELECT mem, swap FROM analysis_base JOIN worker USING(analysis_id) JOIN lsf_report USING(process_id) WHERE logic_name='mcxload_matrix'; ]
    memory used by mcl:         32.9G               [ SELECT mem, swap FROM analysis_base JOIN worker USING(analysis_id) JOIN lsf_report USING(process_id) WHERE logic_name='mcl'; ]

=head2 rel.72 stats

    sequences to cluster:       4,810,252           [ SELECT count(*) from sequence; ]
    distances by Blast:         1,550,752,997       [ SELECT count(*) from mcl_sparse_matrix; ]

    non-reference genes:        2524                [ SELECT count(*) FROM member WHERE member_id>=200000001 AND source_name='ENSEMBLGENE'; ]
    non-reference peps:         9058                [ SELECT count(*) FROM member WHERE member_id>=200000001 AND source_name='ENSEMBLPEP'; ]

    uniprot loading method:     { 20 x pfetch }

    total running time:         14.5 days           [ call time_analysis('%'); ]
    uniprot_loading time:       5.3d                [ call time_analysis('load_uniprot%'); ]
    blasting time:              5.2d                [ call time_analysis('blast%'); ]
    mcxload running time:       4h                  [ call time_analysis('mcxload_matrix'); ]
    mcl running time:           1.9d                [ call time_analysis('mcl'); ]

    memory used by mcxload:     41G                 [ SELECT mem, swap FROM analysis_base JOIN worker USING(analysis_id) JOIN lsf_report USING(process_id) WHERE logic_name='mcxload_matrix'; ]
    memory used by mcl:         41G                 [ SELECT mem, swap FROM analysis_base JOIN worker USING(analysis_id) JOIN lsf_report USING(process_id) WHERE logic_name='mcl'; ]

=head2 rel.71 stats

    sequences to cluster:       4,652,269           [ SELECT count(*) from sequence; ]
    distances by Blast:         1,487,577,335       [ SELECT count(*) from mcl_sparse_matrix; ]

    non-reference genes:        2414                [ SELECT count(*) FROM member WHERE member_id>=200000001 AND source_name='ENSEMBLGENE'; ]
    non-reference peps:         8729                [ SELECT count(*) FROM member WHERE member_id>=200000001 AND source_name='ENSEMBLPEP'; ]

    uniprot loading method:     { 20 x pfetch }

    total running time:         10.6 days           [ call time_analysis('%'); ]
    uniprot_loading time:       10.2h               [ call time_analysis('load_uniprot%'); ]
    blasting time:              4.5 days            [ call time_analysis('family_blast%'); ]
    mcxload running time:       4.1h                [ call time_analysis('mcxload_matrix'); ]
    mcl running time:           10.4h               [ call time_analysis('mcl'); ]

    memory used by mcxload:     40G                 [ SELECT mem, swap FROM analysis_base JOIN worker USING(analysis_id) JOIN lsf_report USING(process_id) WHERE logic_name='mcxload_matrix'; ]
    memory used by mcl:         39G                 [ SELECT mem, swap FROM analysis_base JOIN worker USING(analysis_id) JOIN lsf_report USING(process_id) WHERE logic_name='mcl'; ]

=head2 rel.67 stats

    sequences to cluster:       4,035,467           [ SELECT count(*) from sequence; ]
    distances by Blast:         749,490,988         [ SELECT count(*) from mcl_sparse_matrix; ]

    non-reference genes:        1893                [ SELECT count(*) FROM member WHERE member_id>=100000001 AND source_name='ENSEMBLGENE'; ]
    non-reference peps:         7198                [ SELECT count(*) FROM member WHERE member_id>=100000001 AND source_name='ENSEMBLPEP'; ]

    uniprot loading method:     { 20 x pfetch }

    total running time:         8.2 days            [ call time_analysis('%'); ]
    uniprot_loading time:       1.1 days            [ call time_analysis('load_uniprot%'); ]
    blasting time:              4.3 days            [ call time_analysis('family_blast%'); ]
    mcxload running time:       1.7h                [ call time_analysis('mcxload_matrix'); ]
    mcl running time:           7.6h                [ call time_analysis('mcl'); ]

    memory used by mcxload:     20G mem + 20G swap  [ SELECT mem, swap FROM analysis JOIN worker USING(analysis_id) JOIN lsf_report USING(process_id) WHERE logic_name='mcxload_matrix'; ]
    memory used by mcl:         25G mem + 26G swap  [ SELECT mem, swap FROM analysis JOIN worker USING(analysis_id) JOIN lsf_report USING(process_id) WHERE logic_name='mcl'; ]

=head2 rel.66 stats

    sequences to cluster:       3,800,669           [ SELECT count(*) from sequence; ] - 2 min to count
    distances by Blast:         693,505,406         [ SELECT count(*) from mcl_sparse_matrix; ]

    non-reference genes:        1293                [ SELECT count(*) FROM member WHERE member_id>=100000001 AND source_name='ENSEMBLGENE'; ]
    non-reference peps:         5041                [ SELECT count(*) FROM member WHERE member_id>=100000001 AND source_name='ENSEMBLPEP'; ]

    total running time:         4.3 days
    uniprot_loading time:       4.6h                {20 x pfetch}
    blasting time:              2.4 days
    mcxload running time:       3.4h
    mcl running time:           4.8h

    memory used by mcxload:     19G mem + 19G swap  [ SELECT mem, swap FROM analysis JOIN worker USING(analysis_id) JOIN lsf_report USING(process_id) WHERE logic_name='mcxload_matrix'; ]
    memory used by mcl:         23G mem + 23G swap  [ SELECT mem, swap FROM analysis JOIN worker USING(analysis_id) JOIN lsf_report USING(process_id) WHERE logic_name='mcl'; ]

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
