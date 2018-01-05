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


=pod 

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Families_conf

=head1 SYNOPSIS

    #0. make sure that ProteinTree pipeline (whose EnsEMBL peptide members you want to incorporate) is already past member loading stage

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

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

use Bio::EnsEMBL::Hive::Version 2.4;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        #'mlss_id'         => 30047,         # it is very important to check that this value is current (commented out to make it obligatory to specify)
        #'host'            => 'compara2',    # where the pipeline database will be created
        'file_basename'   => 'metazoa_families_'.$self->o('rel_with_suffix'),

        # HMM clustering
        #'hmm_clustering'  => 0,
        #'hmm_library_basedir'       => '/lustre/scratch109/sanger/fs9/treefam8_hmms',
        #'pantherScore_path'         => '/software/ensembl/compara/pantherScore1.03',
        #'hmmer2_home'               => '/software/ensembl/compara/hmmer-2.3.2/src/',

        # code directories:
        #'blast_bin_dir'   => '/software/ensembl/compara/ncbi-blast-2.2.30+/bin',
        #'mcl_bin_dir'     => '/software/ensembl/compara/mcl-14-137/bin',
        #'mafft_root_dir'  => '/software/ensembl/compara/mafft-7.221',

        # data directories:
        #'work_dir'        => '/lustre/scratch110/ensembl/'.$self->o('ENV', 'USER').'/'.$self->o('pipeline_name'),
        #'warehouse_dir'   => '/warehouse/ensembl05/lg4/families/',      # ToDo: move to a Compara-wide warehouse location
        'uniprot_dir'     => $self->o('work_dir').'/uniprot',
        'blastdb_dir'     => $self->o('work_dir').'/blast_db',
        'blastdb_name'    => $self->o('file_basename').'.pep',

        'uniprot_rel_url' => 'ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/taxonomic_divisions/reldate.txt',
        'uniprot_ftp_url' => 'ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/taxonomic_divisions/uniprot_#uniprot_source#_#tax_div#.dat.gz',

        #'blast_params'    => '', # By default C++ binary has composition stats on and -seg masking off

        #resource requirements:
        'blast_minibatch_size'  => 25,  # we want to reach the 1hr average runtime per minibatch
        'blast_gigs'      =>  4,
        'blast_hm_gigs'   =>  6,
        'mcl_gigs'        => 72,
        'mcl_threads'     => 12,
        'lomafft_gigs'    =>  4,
        'himafft_gigs'    => 14,
        'blast_capacity'  => 5000,                                  # work both as hive_capacity and resource-level throttle
        'mafft_capacity'  =>  400,
        'cons_capacity'   =>  100,
        'HMMer_classify_capacity' => 100,

    };
}


sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables
        
        'mkdir -p '.$self->o('work_dir'),
        'mkdir -p '.$self->o('blastdb_dir'),
        'mkdir -p '.$self->o('uniprot_dir'),

            # perform "lfs setstripe" only if lfs is runnable and the directory is on lustre:
        'which lfs && lfs getstripe '.$self->o('blastdb_dir').' >/dev/null 2>/dev/null && lfs setstripe '.$self->o('blastdb_dir').' -c -1 || echo "Striping is not available on this system" ',
    ];
}


sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'email'             => $self->o('email'),                   # for automatic notifications (may be unsupported by your Meadows)
        'mlss_id'           => $self->o('mlss_id'),
        'blast_params'      => $self->o('blast_params'),

        'work_dir'          => $self->o('work_dir'),                # data directories and filenames
        'warehouse_dir'     => $self->o('warehouse_dir'),
        'blastdb_dir'       => $self->o('blastdb_dir'),
        'uniprot_dir'       => $self->o('uniprot_dir'),
        'file_basename'     => $self->o('file_basename'),
        'blastdb_name'      => $self->o('blastdb_name'),

        'blast_bin_dir'     => $self->o('blast_bin_dir'),           # binary & script directories
        'mcl_bin_dir'       => $self->o('mcl_bin_dir'),
        'mafft_root_dir'    => $self->o('mafft_root_dir'),
        'mafft_threads'    => $self->o('mafft_threads'),

        'master_db'         => $self->o('master_db'),               # databases
        'member_db'         => $self->o('member_db'),

        'hmm_clustering'    => $self->o('hmm_clustering'),
    };
}

sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class
        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    }
}


sub pipeline_analyses {
    my ($self) = @_;
    return [

        {   -logic_name => 'copy_table_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -input_ids => [ {} ],
            -parameters => {
                'inputlist'     => [
                                        [ '#member_db#'     => 'genome_db' ],       # we need them in "located" state
                                        [ '#master_db#'     => 'ncbi_taxa_node' ],
                                        [ '#master_db#'     => 'ncbi_taxa_name' ],
                                        [ '#master_db#'     => 'method_link' ],
                                        [ '#master_db#'     => 'species_set_header' ],
                                        [ '#master_db#'     => 'species_set' ],
                                        [ '#master_db#'     => 'method_link_species_set' ],
                                    ],
                'column_names'  => [ 'src_db_conn', 'table' ],
            },
            -flow_into => {
                '2->A' => [ 'copy_table' ],
                'A->1' => [ 'offset_tables' ],  # backbone
            },
        },

        {   -logic_name    => 'copy_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'mode'          => 'overwrite',
                'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
            },
            -analysis_capacity => 10,
        },

        {   -logic_name => 'offset_tables',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql'   => [
                    'ALTER TABLE sequence                   AUTO_INCREMENT=900000001',
                    'ALTER TABLE seq_member                 AUTO_INCREMENT=900000001',
                    'ALTER TABLE gene_member                AUTO_INCREMENT=900000001',
                ],
            },
            -flow_into => [ 'genomedb_factory' ],
        },

        {   -logic_name => 'genomedb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'extra_parameters'  => ['name'],
            },
            -flow_into => {
                '2->A' => [ 'genome_member_copy' ],
                'A->1' => [ 'hc_nonref_members' ],
            },
        },

        {   -logic_name        => 'genome_member_copy',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::Families::CopyMembersByGenomeDB',
            -parameters        => {
                'reuse_db'              => '#member_db#',
                'biotype_filter'        => 'biotype_group IN ("coding","LRG")',
            },
            -analysis_capacity => 10,
            -rc_name           => '250Mb_job',
            -flow_into         => WHEN('#name# eq "homo_sapiens"' => 'load_lrgs'),
        },

        {   -logic_name => 'load_lrgs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::Families::LoadLRGs',
        },

        {   -logic_name         => 'hc_nonref_members',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::Families::SqlHealthChecks',
            -parameters         => {
                mode            => 'nonref_members',
            },
            -flow_into  => [ 'save_uniprot_release_date' ],
        },

        {   -logic_name => 'save_uniprot_release_date',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::Families::LoadUniProtReleaseVersion',
            -parameters => {
                'uniprot_rel_url'   => $self->o('uniprot_rel_url'),
            },
            -flow_into  => [ 'download_uniprot_factory' ],
        },

        {   -logic_name => 'download_uniprot_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'column_names'    => [ 'uniprot_source', 'tax_div' ],
                'inputlist'       => [
                    [ 'sprot', 'fungi' ],
                    [ 'sprot', 'human' ],
                    [ 'sprot', 'mammals' ],
                    [ 'sprot', 'rodents' ],
                    [ 'sprot', 'vertebrates' ],
                    [ 'sprot', 'invertebrates' ],

                    [ 'trembl',  'fungi' ],
                    [ 'trembl',  'human' ],
                    [ 'trembl',  'mammals' ],
                    [ 'trembl',  'rodents' ],
                    [ 'trembl',  'vertebrates' ],
                    [ 'trembl',  'invertebrates' ],
                ],
            },
            -flow_into => {
                '2->A' => [ 'download_and_chunk_uniprot' ],
                'A->1' => [ 'snapshot_after_load_uniprot' ],
            },
            -rc_name => 'urgent',
        },

        {   -logic_name    => 'download_and_chunk_uniprot',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::Families::DownloadAndChunkUniProtFile',
            -parameters => {
                'uniprot_ftp_url'   => $self->o('uniprot_ftp_url'),
            },
            -flow_into => {
                2 => [ 'load_uniprot' ],
            },
            -rc_name => 'urgent',
        },
        
        {   -logic_name    => 'load_uniprot',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::Families::LoadUniProtEntries',
            -parameters => {
                'seq_loader_name'   => 'file', # {'pfetch' x 20} takes 1.3h; {'mfetch' x 7} takes 2.15h; {'pfetch' x 14} takes 3.5h; {'pfetch' x 30} takes 3h;
            },
            -analysis_capacity => 5,
            -batch_size    => 100,
            -rc_name => '2GigMem',
        },

        {   -logic_name => 'snapshot_after_load_uniprot',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'output_file'      => '#work_dir#/snapshot_after_load_uniprot.sql.gz',
            },
            -flow_into => {
                1 => WHEN (
                    '#hmm_clustering#' => 'reuse_hmm_annot',
                    ELSE { 'dump_member_proteins' => { 'fasta_name' => '#blastdb_dir#/#blastdb_name#', 'blastdb_name' => '#blastdb_name#' } },
                )
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
                'step'            => $self->o('blast_minibatch_size'),
            },
            -flow_into => {
                '2->A' => { 'blast' => { 'start_seq_id' => '#_start_seqid#', 'end_seq_id' => '#_end_seqid#', 'minibatch' => '#_range_count#' } },
                'A->1' => [ 'snapshot_after_blast' ],
            },
            -rc_name => 'LoMafft',
        },

        {   -logic_name    => 'blast',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::Families::BlastAndParseDistances',
            -parameters    => {
                'idprefixed'    => 1,
            },
            -hive_capacity => $self->o('blast_capacity'),
            -max_retry_count => 6,
            -flow_into => {
                3 => [ '?table_name=mcl_sparse_matrix&insertion_method=REPLACE' ],
                -1 => 'blast_himem',
                -2 => 'break_batch',
            },
            -rc_name => 'RegBlast',
        },

        {   -logic_name    => 'blast_himem',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::Families::BlastAndParseDistances',
            -parameters    => {
                'idprefixed'    => 1,
            },
            -hive_capacity => $self->o('blast_capacity'),
            -flow_into => {
                3 => [ '?table_name=mcl_sparse_matrix&insertion_method=REPLACE' ],
            },
            -rc_name => 'LongBlastHM',
        },

        {   -logic_name    => 'break_batch',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'      => 'SELECT DISTINCT sm.sequence_id AS seqid FROM seq_member sm WHERE sm.sequence_id BETWEEN #start_seq_id# AND #end_seq_id#',
                'step'            => 1,
            },
            -flow_into => {
                2 => { 'blast' => { 'start_seq_id' => '#_start_seqid#', 'end_seq_id' => '#_end_seqid#', 'minibatch' => '#_range_count#' } },
            },
        },

        {   -logic_name => 'snapshot_after_blast',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'output_file'  => '#work_dir#/snapshot_after_blast.sql.gz',
            },
            -flow_into => {
                1 => [ 'mcxload_matrix' ],
            },
        },

        {
            -logic_name     => 'reuse_hmm_annot',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::Families::ReuseHMMAnnot',
            -parameters     => {
                'reuse_db'      => $self->o('prev_rel_db'),
            },
            -flow_into      => [ 'HMMer_classifyCurated' ],
        },

        {
            -logic_name     => 'HMMer_classifyCurated',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters     => {
                'sql'   => 'INSERT IGNORE INTO hmm_annot SELECT seq_member_id, model_id, NULL FROM hmm_curated_annot hca JOIN seq_member sm ON sm.stable_id = hca.seq_member_stable_id',
            },
            -flow_into      => [ 'HMMer_classifyInterpro' ],
        },

        {
            -logic_name     => 'HMMer_classifyInterpro',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters     => {
                'sql'   => 'INSERT IGNORE INTO hmm_annot SELECT seq_member_id, panther_family_id, evalue FROM panther_annot pa JOIN seq_member sm ON sm.stable_id = pa.ensembl_id',
            },
            -flow_into      => [ 'HMMer_classify_factory' ],
        },


        {   -logic_name => 'HMMer_classify_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::FactoryUnannotatedMembers',
            -rc_name       => '8GigMem',
            -flow_into => {
                '2->A'  => [ 'HMMer_classifyPantherScore' ],
                'A->1'  => [ 'HMM_clusterize' ],
            },
        },


            {
             -logic_name => 'HMMer_classifyPantherScore',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClassifyPantherScore',
             -parameters => {
                             'blast_bin_dir'       => $self->o('blast_bin_dir'),
                             'pantherScore_path'   => $self->o('pantherScore_path'),
                             'hmmer_path'          => $self->o('hmmer2_home'),
                             'hmm_library_basedir' => $self->o('hmm_library_basedir'),
                            },
             -hive_capacity => $self->o('HMMer_classify_capacity'),
            -batch_size     => 2,
             -rc_name => '500MegMem',
             -flow_into => {
                 -1 => 'HMMer_classifyPantherScore_himem',
             },
            },

            {
             -logic_name => 'HMMer_classifyPantherScore_himem',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClassifyPantherScore',
             -parameters => {
                             'blast_bin_dir'       => $self->o('blast_bin_dir'),
                             'pantherScore_path'   => $self->o('pantherScore_path'),
                             'hmmer_path'          => $self->o('hmmer2_home'),
                             'hmm_library_basedir' => $self->o('hmm_library_basedir'),
                            },
             -hive_capacity => $self->o('HMMer_classify_capacity'),
             -rc_name => '4GigMem',
            },

            {
             -logic_name => 'HMM_clusterize',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::Families::HMMClusterize',
             -rc_name => 'LoMafft',
             -flow_into  => 'fire_family_building',
            },



        {   -logic_name => 'mcxload_matrix',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
            -parameters => {
                'append'        => [qw(-N -q)],
                'input_query'   => 'select * from mcl_sparse_matrix',
                # This long string is to run the actual mcxload command and then test that the file finishes with a closing round bracket
                'command_out'   => '#mcl_bin_dir#/mcxload -abc - -ri max -o #work_dir#/#file_basename#.tcx -write-tab #work_dir#/#file_basename#.itab; tail -n 1 #work_dir#/#file_basename#.tcx | grep ")"',
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
                1 => { 'archive_long_files' => { 'input_filenames' => '#work_dir#/#file_basename#.tcx #work_dir#/#file_basename#.itab' },
                            'parse_mcl'          => { 'mcl_name' => '#work_dir#/#file_basename#.mcl' },
                },
            },
            -rc_name => 'BigMcl',
        },

        {   -logic_name => 'parse_mcl',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::Families::ParseMCLintoFamilies',
            -parameters => {
                'family_prefix'         => 'fam'.$self->o('rel_with_suffix'),
            },
             -flow_into => {
                 1 => {
                    'archive_long_files'    => { 'input_filenames' => '#work_dir#/#file_basename#.mcl' },
                    'fire_family_building'  => { },
                 },
            },
            -rc_name => 'urgent',
        },

        {   -logic_name => 'fire_family_building',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'randomize'             => 1,
                'inputquery'            => 'SELECT family_id, COUNT(*) AS fam_gene_count FROM family_member GROUP BY family_id HAVING count(*)>1',
                'max_genes_lowmem_mafft'        => $self->o('max_genes_lowmem_mafft'),
                'max_genes_singlethread_mafft'  => $self->o('max_genes_singlethread_mafft'),
                'max_genes_computable_mafft'    => $self->o('max_genes_computable_mafft'),
            },
            -hive_capacity => 20, # to enable parallel branches
            -flow_into => {
                '2->A' => WHEN(
                    '#fam_gene_count# <= #max_genes_lowmem_mafft#' => 'mafft_main',
                    '(#fam_gene_count# > #max_genes_singlethread_mafft#) && (#fam_gene_count# <= #max_genes_computable_mafft#)' => 'mafft_huge',
                    '#fam_gene_count# > #max_genes_computable_mafft#' => 'trim_family',
                    ELSE 'mafft_big',
                ),
                'A->1' => {
                    'find_update_singleton_cigars' => { },
                },
            },
            -rc_name => 'LoMafft',
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

        {   -logic_name         => 'mafft_main',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::Families::MafftAfamily',
            -hive_capacity      => $self->o('mafft_capacity'),
            -batch_size         => 10,
            -max_retry_count    => 6,
            -flow_into => {
                1  => [ 'consensifier' ],
                -1 => [ 'mafft_big' ],
            },
            -rc_name => 'LoMafft',
        },

        {   -logic_name    => 'mafft_big',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::Families::MafftAfamily',
            -hive_capacity => $self->o('mafft_capacity'),
            -rc_name       => 'BigMafft',
            -flow_into     => {
                1  => [ 'consensifier_himem' ],
                -1 => [ 'mafft_huge' ],
            },
        },

        {   -logic_name    => 'mafft_huge',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::Families::MafftAfamily',
            -hive_capacity => $self->o('mafft_capacity'),
            -parameters    => {
                'mafft_threads'     => 8,
            },
            -flow_into     => {
                1  => [ 'consensifier_himem' ],
            },
            -rc_name => 'HugeMafft_multi_core',
        },

        {   -logic_name         => 'trim_family',
            -module             => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'member_sources_to_delete'  => '"Uniprot/SPTREMBL"',
                'trim_to_this_taxon_id'     => 7711,    # Chordates
                'sql'   => [
                    'DELETE family_member
                    FROM
                        family_member
                            JOIN
                        seq_member sm USING (seq_member_id)
                            JOIN
                        ncbi_taxa_node ntn1 USING (taxon_id)
                            JOIN
                        ncbi_taxa_node ntn2
                    WHERE
                        family_id = #family_id# AND ntn2.taxon_id = #trim_to_this_taxon_id#
                            AND NOT (ntn2.left_index <= ntn1.left_index AND ntn2.right_index >= ntn1.left_index)
                            AND source_name IN (#member_sources_to_delete#);'
                ],
            },
            -flow_into => {
                1  => [ 'mafft_huge' ],
            },
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
                1 => WHEN (
                    '#hmm_clustering#' => 'warehouse_working_directory',
                    ELSE 'insert_redundant_peptides',
                )
            },
            -rc_name => 'urgent',
        },

        {   -logic_name => 'insert_redundant_peptides',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => "INSERT INTO family_member SELECT family_id, m2.seq_member_id, cigar_line FROM family_member fm, seq_member m1, seq_member m2 WHERE fm.seq_member_id=m1.seq_member_id AND m1.sequence_id=m2.sequence_id AND m1.seq_member_id<>m2.seq_member_id",
            },
            -hive_capacity => 20, # to enable parallel branches
            -flow_into  => 'stable_id_map',
            -rc_name => 'urgent',
        },

# </Mafft sub-branch>

# <Consensifier sub-branch>
        {   -logic_name    => 'consensifier',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::Families::ConsensifyAfamily',
            -hive_capacity => $self->o('cons_capacity'),
            -batch_size    => 20,
            -flow_into     => {
                -1 => 'consensifier_himem',
            },
        },

        {   -logic_name    => 'consensifier_himem',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::Families::ConsensifyAfamily',
            -hive_capacity => $self->o('cons_capacity'),
            -rc_name       => '500MegMem',
        },
# </Consensifier sub-branch>

# job funnel:
        {   -logic_name    => 'stable_id_map',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::StableIdMapper',
            -parameters    => {
                'prev_rel_db' => $self->o('prev_rel_db'),
                'type'        => 'f',
                'release'     => $self->o('ensembl_release'),
            },
            -flow_into => {
                1 => [ 'warehouse_working_directory' ],
            },
            -rc_name => '16GigMem',    # NB: make sure you give it enough memory or it will crash
        },

        {   -logic_name => 'warehouse_working_directory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd'   => 'become -- compara_ensembl cp -r #work_dir# #warehouse_dir#',
            },
            -rc_name => 'urgent',
            -flow_into => [ 'notify_pipeline_completed' ],
        },

        {   -logic_name => 'notify_pipeline_completed',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::NotifyByEmail',
            -parameters => {
                'subject' => "Family Pipeline(".$self->o('pipeline_name').") has completed",
                'text' => "This is an automatic message.\n Family Pipeline for release #expr(\$self->hive_pipeline->display_name)expr# has completed.",
            },
            -rc_name => 'urgent',
            -flow_into => [ 'register_pipeline_url' ],
        },

        {   -logic_name => 'register_pipeline_url',
            -module      => 'Bio::EnsEMBL::Compara::RunnableDB::RegisterMLSS',
            -parameters => { 
                'test_mode' => $self->o('test_mode'),
                }
        },

        #
        ## Please remember that the stable_id_history will have to be MERGED in an intelligent way, and not just written over.
        #
    ];
}

1;

=head1 STATS and TIMING

=head2 rel.82 stats

    sequences to cluster:           7,936,461       [ SELECT count(*) from sequence; ] -- took 1m12s to run
    distances by Blast:         1,561,866,354       [ SELECT count(*) from mcl_sparse_matrix; ] -- took 43m to run

    LRG dnafrags:                 610               [ SELECT count(*) FROM dnafrag WHERE coord_system_name='lrg'; ]
    LRG gene members:             608               [ SELECT count(*) FROM gene_member WHERE stable_id LIKE 'LRG_%'; ]
    non-reference genes:         3176               [ SELECT count(*) FROM gene_member WHERE gene_member_id>=200000001 AND source_name='ENSEMBLGENE'; ]
    non-reference peps:          9337               [ SELECT count(*) FROM seq_member WHERE seq_member_id>=200000001 AND source_name='ENSEMBLPEP'; ]

    uniprot loading method:     { 20 x pfetch }

    total running time:         11.3d              [ call time_analysis('%'); ]    -- could have been shorter by 1-2 days (mcxload was run while quota was exceeded, which caused a silent format error in the tcx file)
    uniprot_loading time:       18.5h               [ call time_analysis('load_uniprot%'); ]
    blasting time:               5.8d               [ call time_analysis('blast%'); ]
    mcxload running time:       22.3h               [ select (UNIX_TIMESTAMP(when_finished)-UNIX_TIMESTAMP(when_started))/3600 hours from role join analysis_base using(analysis_id) where done_jobs=1 and logic_name='mcxload_matrix' order by role_id DESC limit 1; ]
    mcl running time:           13.7h               [ select (UNIX_TIMESTAMP(when_finished)-UNIX_TIMESTAMP(when_started))/3600 hours from role join analysis_base using(analysis_id) where done_jobs=1 and logic_name='mcl' order by role_id DESC limit 1; ]

    memory used by mcxload:     41.6G               [ SELECT mem_megs, swap_megs FROM analysis_base JOIN role USING(analysis_id) JOIN worker_resource_usage USING(worker_id) WHERE logic_name='mcxload_matrix'; ]
    memory used by mcl:         63.2G               [ SELECT mem_megs, swap_megs FROM analysis_base JOIN role USING(analysis_id) JOIN worker_resource_usage USING(worker_id) WHERE logic_name='mcl'; ]


=head2 rel.81 stats

    sequences to cluster:           7,936,228       [ SELECT count(*) from sequence; ] -- took 1m12s to run
    distances by Blast:         1,561,834,584       [ SELECT count(*) from mcl_sparse_matrix; ] -- took 43m to run

    LRG dnafrags:                 575               [ SELECT count(*) FROM dnafrag WHERE coord_system_name='lrg'; ]
    LRG gene members:             573               [ SELECT count(*) FROM gene_member WHERE stable_id LIKE 'LRG_%'; ]
    non-reference genes:         3120               [ SELECT count(*) FROM gene_member WHERE gene_member_id>=200000001 AND source_name='ENSEMBLGENE'; ]
    non-reference peps:          9260               [ SELECT count(*) FROM seq_member WHERE seq_member_id>=200000001 AND source_name='ENSEMBLPEP'; ]

    uniprot loading method:     { 20 x pfetch }

    total running time:         10.7d               [ call time_analysis('%'); ]    -- could have been shorter by 1-2 days (mcxload had a syntax error in the command line, which was an attempt to introduce a healthcheck)
    uniprot_loading time:        6.7h               [ call time_analysis('load_uniprot%'); ]
    blasting time:               6.8d               [ call time_analysis('blast%'); ]
    mcxload running time:       21.8h               [ select (UNIX_TIMESTAMP(when_finished)-UNIX_TIMESTAMP(when_started))/3600 hours from role join analysis_base using(analysis_id) where done_jobs=1 and logic_name='mcxload_matrix' order by role_id DESC limit 1; ]
    mcl running time:           13.1h               [ select (UNIX_TIMESTAMP(when_finished)-UNIX_TIMESTAMP(when_started))/3600 hours from role join analysis_base using(analysis_id) where done_jobs=1 and logic_name='mcl' order by role_id DESC limit 1; ]

    memory used by mcxload:     41.6G               [ SELECT mem_megs, swap_megs FROM analysis_base JOIN role USING(analysis_id) JOIN worker_resource_usage USING(worker_id) WHERE logic_name='mcxload_matrix'; ]
    memory used by mcl:         63.1G               [ SELECT mem_megs, swap_megs FROM analysis_base JOIN role USING(analysis_id) JOIN worker_resource_usage USING(worker_id) WHERE logic_name='mcl'; ]


=head2 rel.80 stats

    sequences to cluster:           7,501,655       [ SELECT count(*) from sequence; ] -- took 3 seconds to run
    distances by Blast:         1,466,437,751       [ SELECT count(*) from mcl_sparse_matrix; ] -- took 37m20 to run

    non-reference genes:         2848               [ SELECT count(*) FROM gene_member WHERE gene_member_id>=200000001 AND source_name='ENSEMBLGENE'; ]
    non-reference peps:          8069               [ SELECT count(*) FROM seq_member WHERE seq_member_id>=200000001 AND source_name='ENSEMBLPEP'; ]

    uniprot loading method:     { 20 x pfetch }

    total running time:         14.0d               [ call time_analysis('%'); ]    -- could have been shorter by 2-3 days (due to the mcxload initial misconfig and scratch109 instability/quota/limit issues)
    uniprot_loading time:       14.0h               [ call time_analysis('load_uniprot%'); ]
    blasting time:               5.9d               [ call time_analysis('blast%'); ]
    mcxload running time:        2.8h               [ select (UNIX_TIMESTAMP(when_finished)-UNIX_TIMESTAMP(when_started))/3600 hours from role join analysis_base using(analysis_id) where done_jobs=1 and logic_name='mcxload_matrix' order by role_id DESC limit 1; ]
    mcl running time:           42.3h               [ select (UNIX_TIMESTAMP(when_finished)-UNIX_TIMESTAMP(when_started))/3600 hours from role join analysis_base using(analysis_id) where done_jobs=1 and logic_name='mcl' order by role_id DESC limit 1; ]

    memory used by mcxload:     38.9G               [ SELECT mem_megs, swap_megs FROM analysis_base JOIN role USING(analysis_id) JOIN worker_resource_usage USING(worker_id) WHERE logic_name='mcxload_matrix'; ]
    memory used by mcl:         58.6G               [ SELECT mem_megs, swap_megs FROM analysis_base JOIN role USING(analysis_id) JOIN worker_resource_usage USING(worker_id) WHERE logic_name='mcl'; ]


=head2 rel.79 stats

    sequences to cluster:           6,968,981       [ SELECT count(*) from sequence; ] -- took 1.5m to run
    distances by Blast:         1,338,935,992       [ SELECT count(*) from mcl_sparse_matrix; ] -- took 37m20 to run

    non-reference genes:         2851               [ SELECT count(*) FROM gene_member WHERE gene_member_id>=200000001 AND source_name='ENSEMBLGENE'; ]
    non-reference peps:          8074               [ SELECT count(*) FROM seq_member WHERE seq_member_id>=200000001 AND source_name='ENSEMBLPEP'; ]

    uniprot loading method:     { 20 x pfetch }

    total running time:          ?                  [ call time_analysis('%'); ]
    uniprot_loading time:        5.6h               [ call time_analysis('load_uniprot%'); ]    # Sun-Mon overnight
    blasting time:               6.8d +++           [ call time_analysis('blast%'); ]           # Estimate is wrong. Had to be stopped, topped-up and restarted.
    mcxload running time:       31.7h               [ call time_analysis('mcxload_matrix'); ]
    mcl running time:           32.4h               [ call time_analysis('mcl'); ]

    memory used by mcxload:     35.5G               [ SELECT mem_megs, swap_megs FROM analysis_base JOIN role USING(analysis_id) JOIN worker_resource_usage USING(worker_id) WHERE logic_name='mcxload_matrix'; ]
    memory used by mcl:         53.3G               [ SELECT mem_megs, swap_megs FROM analysis_base JOIN role USING(analysis_id) JOIN worker_resource_usage USING(worker_id) WHERE logic_name='mcl'; ]

=head2 rel.78 stats

    sequences to cluster:           6,801,213       [ SELECT count(*) from sequence; ] -- took a few seconds to run
    distances by Blast:         1,303,980,213       [ SELECT count(*) from mcl_sparse_matrix; ] -- took 38m to run

    non-reference genes:         2718               [ SELECT count(*) FROM gene_member WHERE gene_member_id>=200000001 AND source_name='ENSEMBLGENE'; ]
    non-reference peps:          7075               [ SELECT count(*) FROM seq_member WHERE seq_member_id>=200000001 AND source_name='ENSEMBLPEP'; ]

    uniprot loading method:     { 20 x pfetch }

    total running time:          7.7d               [ call time_analysis('%'); ]
    uniprot_loading time:        9.0h               [ call time_analysis('load_uniprot%'); ]
    blasting time:               4.9d               [ call time_analysis('blast%'); ]
    mcxload running time:        5.1h               [ call time_analysis('mcxload_matrix'); ]
    mcl running time:           11.7h               [ call time_analysis('mcl'); ]

    memory used by mcxload:     34.6G               [ SELECT mem_megs, swap_megs FROM analysis_base JOIN role USING(analysis_id) JOIN worker_resource_usage USING(worker_id) WHERE logic_name='mcxload_matrix'; ]
    memory used by mcl:         52.0G               [ SELECT mem_megs, swap_megs FROM analysis_base JOIN role USING(analysis_id) JOIN worker_resource_usage USING(worker_id) WHERE logic_name='mcl'; ]

=head2 rel.77 stats

    sequences to cluster:       6,546,543           [ SELECT count(*) from sequence; ] -- took 1.5m to run
    distances by Blast:         1,251,923,987       [ SELECT count(*) from mcl_sparse_matrix; ] -- took 34m to run

    non-reference genes:         2699               [ SELECT count(*) FROM gene_member WHERE gene_member_id>=200000001 AND source_name='ENSEMBLGENE'; ]
    non-reference peps:          7021               [ SELECT count(*) FROM seq_member WHERE seq_member_id>=200000001 AND source_name='ENSEMBLPEP'; ]

    uniprot loading method:     { 20 x pfetch }

    total running time:         12.9d               [ call time_analysis('%'); ]
    uniprot_loading time:       11.0h               [ call time_analysis('load_uniprot%'); ]
    blasting time:               4.5d               [ call time_analysis('blast%'); ]
    mcxload running time:        2.6h               [ call time_analysis('mcxload_matrix'); ]
    mcl running time:           10.9h               [ call time_analysis('mcl'); ]

    memory used by mcxload:     33.2G               [ SELECT mem_megs, swap_megs FROM analysis_base JOIN role USING(analysis_id) JOIN worker_resource_usage USING(worker_id) WHERE logic_name='mcxload_matrix'; ]
    memory used by mcl:         50.0G               [ SELECT mem_megs, swap_megs FROM analysis_base JOIN role USING(analysis_id) JOIN worker_resource_usage USING(worker_id) WHERE logic_name='mcl'; ]

=head2 rel.76 stats

    sequences to cluster:       6,293,923           [ SELECT count(*) from sequence; ] -- took 2 minutes to run
    distances by Blast:         1,204,402,584       [ SELECT count(*) from mcl_sparse_matrix; ] -- took 1h18m to run

    non-reference genes:         2182               [ SELECT count(*) FROM gene_member WHERE gene_member_id>=200000001 AND source_name='ENSEMBLGENE'; ]
    non-reference peps:          6394               [ SELECT count(*) FROM seq_member WHERE seq_member_id>=200000001 AND source_name='ENSEMBLPEP'; ]

    uniprot loading method:     { 20 x pfetch }

    total running time:         10.8d               [ call time_analysis('%'); ]
    uniprot_loading time:        3.8h               [ call time_analysis('load_uniprot%'); ]
    blasting time:               6.0d               [ call time_analysis('blast%'); ]
    mcxload running time:        3.0h               [ call time_analysis('mcxload_matrix'); ]
    mcl running time:           15.8h               [ call time_analysis('mcl'); ]

    memory used by mcxload:     32.5G               [ SELECT mem_megs, swap_megs FROM analysis_base JOIN role USING(analysis_id) JOIN worker_resource_usage USING(worker_id) WHERE logic_name='mcxload_matrix'; ]
    memory used by mcl:         48.2G               [ SELECT mem_megs, swap_megs FROM analysis_base JOIN role USING(analysis_id) JOIN worker_resource_usage USING(worker_id) WHERE logic_name='mcl'; ]

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
