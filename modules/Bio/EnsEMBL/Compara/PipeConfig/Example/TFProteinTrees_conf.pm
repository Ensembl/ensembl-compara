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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::Example::TFProteinTrees_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #2. you may need to update 'schema_version' in meta table to the current release number in ensembl-hive/sql/tables.sql

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Example::TFProteinTrees_conf \
        -password <your_password> -mlss_id <your_current_PT_mlss_id>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output


=head1 DESCRIPTION

    The PipeConfig example file for Treefam's version of ProteinTrees pipeline.

=head1 CONTACT

  Please contact Compara or TreeFam with questions/suggestions

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Example::TFProteinTrees_conf;

use strict;
use warnings;


use base ('Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # parameters that are likely to change from execution to another:
        #mlss_id => 40043,
        #'do_not_reuse_list' => ['guillardia_theta'], # set this to empty or to the genome db names we should ignore
        'release'               => 10,
        'release_suffix'        => '', # set it to '' for the actual release
        'rel_with_suffix'       => $self->o('release').$self->o('release_suffix'),

    # custom pipeline name, in case you don't like the default one
        'division'               => 'treefam',
        'pipeline_name'          => $self->o('division').$self->o('rel_with_suffix').'_hom_eg'.$self->o('eg_release').'_e'.$self->o('ensembl_release'),

    # dependent parameters: updating 'work_dir' should be enough
        'work_dir'              =>  '/nfs/nobackup2/xfam/treefam/ensembl/'.$self->o('ENV', 'USER').'/compara/'.$self->o('pipeline_name'),
        'exe_dir'               =>  '/nfs/panda/ensemblgenomes/production/compara/binaries',

    # "Member" parameters:
        'allow_ambiguity_codes'     => 1,
        'allow_pyrrolysine'         => 1,

    # blast parameters:

    # clustering parameters:
        'outgroups'                     => {},      # affects 'hcluster_dump_input_per_genome'

    # tree building parameters:
        'use_raxml'                 => 1,
        'treebreak_gene_count'      => 100000,     # affects msa_chooser
        'mafft_gene_count'          => 200,     # affects msa_chooser
        'mafft_runtime'             => 172800,    # affects msa_chooser

    # species tree reconciliation
        # you can define your own species_tree for 'treebest'. It can contain multifurcations
        'species_tree_input_file'   => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/tf10_347_species',
        # you can define your own species_tree for 'notung'. It *has* to be binary

    # homology_dnds parameters:
        'codeml_parameters_file'    => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/homology/codeml.ctl.hash',
        'taxlevels'                 => [],
        'filter_high_coverage'      => 0,   # affects 'group_genomes_under_taxa'

    # mapping parameters:

    # executable locations:
        hcluster_exe    =>  $self->o('exe_dir').'/hcluster_sg',
        mcoffee_home    => '/nfs/panda/ensemblgenomes/external/t-coffee',
        mafft_home      =>  '/nfs/panda/ensemblgenomes/external/mafft',
        treebest_exe    =>  $self->o('exe_dir').'/treebest',
        trimal_exe    =>  '/nfs/production/xfam/treefam/software/trimal/source/trimal',
        raxml_exe    =>  '/nfs/production/xfam/treefam/software/RAxML/raxmlHPC-SSE3',
        quicktree_exe   =>  $self->o('exe_dir').'/quicktree',
        buildhmm_exe    =>  $self->o('exe_dir').'/hmmbuild',
        notung_jar    =>  '/nfs/production/xfam/treefam/software/Notung/Notung-2.6/Notung-2.6.jar',
        codeml_exe      =>  $self->o('exe_dir').'/codeml',
        ktreedist_exe   =>  $self->o('exe_dir').'/ktreedist',
        'blast_bin_dir'  => '/nfs/panda/ensemblgenomes/external/ncbi-blast-2+/bin/',

    # HMM specific parameters (set to 0 or undef if not in use)
        'hmm_clustering'            => 1, ## by default run blastp clustering
        'cm_file_or_directory'      => '/nfs/nobackup2/xfam/treefam/datasets/panhmms/current_release/',
        'hmm_library_basedir'       => '/nfs/nobackup2/xfam/treefam/datasets/panhmms/current_release/',
        'pantherScore_path'         => '/nfs/production/xfam/treefam/software/pantherScore1.03/',
        'hmmer_path'                => '/nfs/production/xfam/treefam/software/hmmer-2.3.2/bin/',


    # hive_capacity values for some analyses:
        'reuse_capacity'            =>   4,
        'blast_factory_capacity'    =>  50,
        'blastp_capacity'           => 200,
        'mcoffee_capacity'          => 200,
        'split_genes_capacity'      => 150,
        'filtering_capacity'         => 100,
        'treebest_capacity'         => 200,
        'raxml_capacity'         => 200,
        'ortho_tree_capacity'       => 200,
        'ortho_tree_annot_capacity' => 300,
        'quick_tree_break_capacity' => 100,
        'build_hmm_capacity'        => 200,
        'ktreedist_capacity'        => 150,
        'merge_supertrees_capacity' => 100,
        'other_paralogs_capacity'   => 100,
        'homology_dNdS_capacity'    => 200,
        'qc_capacity'               =>   4,
        'hc_capacity'               =>   4,
        'HMMer_classify_capacity'   => 400,
        'loadmembers_capacity'      =>  30,

    # hive priority for non-LOCAL health_check analysis:

    # connection parameters to various databases:

        # Uncomment and update the database locations

        # the production database itself (will be created)
        # it inherits most of the properties from HiveGeneric, we usually only need to redefine the host, but you may want to also redefine 'port'

        # the master database for synchronization of various ids (use undef if you don't have a master database)
        #'master_db' => 'mysql://ensro@mysql-eg-pan-1.ebi.ac.uk:4276/ensembl_compara_master',
		#'master_db' => 'mysql://admin:00ABuSzd@mysql-treefam-prod:4401/treefam_master10',

    ######## THESE ARE PASSED INTO LOAD_REGISTRY_FROM_DB SO PASS IN DB_VERSION
    ######## ALSO RAISE THE POINT ABOUT LOAD_FROM_MULTIPLE_DBs

    pipeline_db => {
      -host   => 'mysql-treefam-prod',
      -port   => 4401,
      -user   => 'admin',
      -pass   => $self->o('password'),
      -dbname => 'TreeFam'.$self->o('release').$self->o('release_suffix'),
	  -driver => 'mysql',
      #-db_version => $self->o('ensembl_release')
    },
    eg_mirror => {       
            -host => 'mysql-eg-mirror.ebi.ac.uk',
            -port => 4205,
            -user => 'ensro',
            #-verbose => 1,
            -db_version => 75, 
   },
    ensembl_mirror => {
            -host => 'mysql-ensembl-mirror.ebi.ac.uk',
            -user => 'anonymous',
            -port => '4240',
            #-verbose => 1,
            -db_version => 75
    },
    master_db=> {
            -host => 'mysql-treefam-prod',
            -user => 'admin',
            -port => '4401',
			-pass => $self->o('password'),
            #-verbose => 1,
      		-dbname => 'treefam_master10',
	  		-driver => 'mysql',
			#-db_version => 75
    },

	#Used to fetch:
		#triticum_aestivum_a
		#triticum_aestivum_b
		#triticum_aestivum_d
	eg_prod=> {
            -host => 'mysql-eg-prod-1.ebi.ac.uk',
            -port => 4238,
            -user => 'ensro',
            -verbose => 1,
            -db_version => 75,
   },

    #ncbi_eg=> {
            #-host => 'mysql-eg-mirror.ebi.ac.uk',
            #-user => 'anonymous',
            #-port => '4157',
            #-verbose => 1,
      		#-dbname => 'ensembl_compara_plants_22_75',
	  		#-driver => 'mysql',
			#-db_version => 75
    #},

    #staging_1 => {
    #  -host   => 'mysql-eg-staging-1.ebi.ac.uk',
    #  -port   => 4160,
    #  -user   => 'ensro',
    #  -db_version => $self->o('ensembl_release')
    #},

    #staging_2 => {
    #  -host   => 'mysql-eg-staging-2.ebi.ac.uk',
    #  -port   => 4275,
    #  -user   => 'ensro',
    #  -db_version => $self->o('ensembl_release')
    #},

        # NOTE: The databases referenced in the following arrays have to be hashes (not URLs)
        # Add the database entries for the current core databases and link 'curr_core_sources_locs' to them
        'curr_core_sources_locs' => [ $self->o('master_db'), $self->o('eg_mirror'), $self->o('ensembl_mirror'), $self->o('eg_prod') ],
        # Add the database entries for the core databases of the previous release
        'prev_core_sources_locs'   => [ $self->o('master_db'), $self->o('eg_mirror'), $self->o('ensembl_mirror'), $self->o('eg_prod') ],

        # Add the database location of the previous Compara release. Use "undef" if running the pipeline without reuse
        #'prev_rel_db' => 'mysql://ensro@mysql-eg-staging-1.ebi.ac.uk:4160/ensembl_compara_fungi_19_72',
        'prev_rel_db' => 'mysql://treefam_ro:treefam_ro@mysql-treefam-prod:4401/treefam_production_9_69',

    };
}



sub resource_classes {
  my ($self) = @_;
  return {
         'default'      => {'LSF' => '-q production-rh6' },
         '250Mb_job'    => {'LSF' => '-q production-rh6 -M250   -R"select[mem>250]   rusage[mem=250]"' },
         '500Mb_job'    => {'LSF' => '-q production-rh6 -M500   -R"select[mem>500]   rusage[mem=500]"' },
         '1Gb_job'      => {'LSF' => '-q production-rh6 -M1000  -R"select[mem>1000]  rusage[mem=1000]"' },
         '4Gb_job'      => {'LSF' => '-q production-rh6 -M4000  -R"select[mem>4000]  rusage[mem=4000]"' },
         '2Gb_job'      => {'LSF' => '-q production-rh6 -M2000  -R"select[mem>2000]  rusage[mem=2000]"' },
         '2.5Gb_job'    => {'LSF' => '-q production-rh6 -M2500  -R"select[mem>2500]  rusage[mem=2500]"' },
         '8Gb_job'      => {'LSF' => '-q production-rh6 -M8000  -R"select[mem>8000]  rusage[mem=8000]"' },
         '16Gb_job'     => {'LSF' => '-q production-rh6 -M16000 -R"select[mem>16000] rusage[mem=16000]"' },
         '32Gb_job'     => {'LSF' => '-q production-rh6 -M32000 -R"select[mem>32000] rusage[mem=32000]"' },
         '64Gb_job'     => {'LSF' => '-q production-rh6 -M64000 -R"select[mem>64000] rusage[mem=64000]"' },
         'urgent_hcluster'     => {'LSF' => '-q production-rh6 -M32000 -R"select[mem>32000] rusage[mem=32000]"' },
         'msa'      => {'LSF' => '-q production-rh6' },
         'msa_himem'    => {'LSF' => '-q production-rh6 -M 32768 -R"select[mem>32768] rusage[mem=32768]"' },
  };
}

sub pipeline_analyses {
    my $self = shift;
    my $all_analyses = $self->SUPER::pipeline_analyses(@_);
    my %analyses_by_name = map {$_->{'-logic_name'} => $_} @$all_analyses;

    ## Extend this section to redefine the resource names of some analysis
    $analyses_by_name{'split_genes'}->{'-rc_name'} = '8Gb_job';
    $analyses_by_name{'trimal'}->{'-rc_name'} = '4Gb_job';
    $analyses_by_name{'notung'}->{'-rc_name'} = '8Gb_job';

    ## We add some more analyses
    push @$all_analyses, @{$self->extra_analyses(@_)};

    ## And stich them to the previous ones
    $analyses_by_name{'split_genes'}->{'-flow_into'}->{-1} = [ 'split_genes_himem' ];
    $analyses_by_name{'build_HMM_aa'}->{'-flow_into'} = {
        -1 => [ 'build_HMM_aa_himem' ],  # MEMLIMIT
    };
    $analyses_by_name{'build_HMM_cds'}->{'-flow_into'} = {
        -1 => [ 'build_HMM_cds_himem' ],  # MEMLIMIT
    };

    return $all_analyses;
}

sub extra_analyses {
    my $self = shift;
    return [

        {   -logic_name     => 'split_genes_himem',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::FindContiguousSplitGenes',
            -hive_capacity  => $self->o('split_genes_capacity'),
            -rc_name        => '32Gb_job',
            -flow_into      => {
                1   => [ 'build_HMM_aa_himem', 'build_HMM_cds_himem' ],
                '1->A'   => [ $self->o('use_raxml') ? 'trimal' : 'treebest' ],
                '999->A' => [ $self->o('use_raxml') ? 'treebest' : 'trimal' ],
                'A->1'   => 'notung'
            }
        },

        {   -logic_name     => 'build_HMM_aa_himem',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM',
            -parameters     => {
                'buildhmm_exe'  => $self->o('buildhmm_exe'),
            },
            -hive_capacity  => $self->o('build_hmm_capacity'),
            -batch_size     => 5,
            -priority       => -10,
            -rc_name        => '16Gb_job',
        },

        {   -logic_name     => 'build_HMM_cds_himem',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM',
            -parameters     => {
                'cdna'          => 1,
                'buildhmm_exe'  => $self->o('buildhmm_exe'),
            },
            -hive_capacity  => $self->o('build_hmm_capacity'),
            -batch_size     => 5,
            -priority       => -10,
            -rc_name        => '32Gb_job',
        },
    ];
}


1;
