=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::Example::EGProteinTrees_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara CVS repositories before each new release

    #2. you may need to update 'schema_version' in meta table to the current release number in ensembl-hive/sql/tables.sql

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Example::EGProteinTrees_conf \
        -password <your_password> -mlss_id <your_current_PT_mlss_id> \
        -division <eg_division> -eg_release <egrelease>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output


=head1 DESCRIPTION

    The PipeConfig example file for Ensembl Genomes group's version of
    ProteinTrees pipeline. This file is inherited from & customised further
    within the Ensembl Genomes infrastructure but this file serves as
    an example of the type of configuration we perform.

=head1 CONTACT

  Please contact Compara or Ensembl Genomes with questions/suggestions

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Example::EGProteinTrees_conf;

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

    # custom pipeline name, in case you don't like the default one
        dbowner => 'ensembl_compara',       # Used to prefix the database name (in HiveGeneric_conf)
        pipeline_name => $self->o('division').'_hom_'.$self->o('eg_release').'_'.$self->o('ensembl_release'),

    # dependent parameters: updating 'work_dir' should be enough
        'work_dir'              =>  $self->o('base_dir').'/ensembl_compara_'.$self->o('pipeline_name'),
        'base_dir'              =>  '/nfs/nobackup2/ensemblgenomes/'.$self->o('ENV', 'USER').'/compara',
        'exe_dir'               =>  '/nfs/panda/ensemblgenomes/production/compara/binaries',

    # blast parameters:

    # clustering parameters:
        'outgroups'                     => {},      # affects 'hcluster_dump_input_per_genome'

    # tree building parameters:
        'tree_dir'                  =>  $self->o('ensembl_cvs_root_dir').'/ensembl_genomes/EGCompara/config/prod/trees/Version'.$self->o('eg_release').'Trees',
        'species_tree_input_file'   =>  $self->o('tree_dir').'/'.$self->o('division').'.peptide.nh',

    # homology_dnds parameters:
        'codeml_parameters_file'    => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/homology/codeml.ctl.hash',
        'taxlevels'                 => ['cellular organisms'],
        'filter_high_coverage'      => 0,   # affects 'group_genomes_under_taxa'

    # mapping parameters:
        'tf_release'                => '9_69',

    # executable locations:
        hcluster_exe    =>  $self->o('exe_dir').'/hcluster_sg',
        mcoffee_home    => '/nfs/panda/ensemblgenomes/external/t-coffee',
        mafft_home      =>  '/nfs/panda/ensemblgenomes/external/mafft',
        treebest_exe    =>  $self->o('exe_dir').'/treebest',
        quicktree_exe   =>  $self->o('exe_dir').'/quicktree',
        buildhmm_exe    =>  $self->o('exe_dir').'/hmmbuild',
        codeml_exe      =>  $self->o('exe_dir').'/codeml',
        ktreedist_exe   =>  $self->o('exe_dir').'/ktreedist',
        'blast_bin_dir'  => '/nfs/panda/ensemblgenomes/external/ncbi-blast-2+/bin/',

    # HMM specific parameters (set to 0 or undef if not in use)
        'hmm_clustering'            => 0, ## by default run blastp clustering
        'cm_file_or_directory'      => undef,
        'hmm_library_basedir'       => undef,
        'pantherScore_path'         => undef,
        'hmmer_path'                => undef,



    # hive_capacity values for some analyses:
        'reuse_capacity'            =>   4,
        'blast_factory_capacity'    =>  50,
        'blastp_capacity'           => 200,
        'mcoffee_capacity'          => 200,
        'split_genes_capacity'      => 200,
        'njtree_phyml_capacity'     => 200,
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
        'HMMer_classify_capacity'   => 100,

    # hive priority for non-LOCAL health_check analysis:

    # connection parameters to various databases:

        # Uncomment and update the database locations

        # the production database itself (will be created)
        # it inherits most of the properties from HiveGeneric, we usually only need to redefine the host, but you may want to also redefine 'port'

        # the master database for synchronization of various ids (use undef if you don't have a master database)
        'master_db' => 'mysql://ensro@mysql-eg-pan-1.ebi.ac.uk:4276/ensembl_compara_master',

    ######## THESE ARE PASSED INTO LOAD_REGISTRY_FROM_DB SO PASS IN DB_VERSION
    ######## ALSO RAISE THE POINT ABOUT LOAD_FROM_MULTIPLE_DBs

    prod_1 => {
      -host   => 'mysql-eg-prod-1.ebi.ac.uk',
      -port   => 4238,
      -user   => 'ensro',
      -db_version => $self->o('ensembl_release')
    },

    staging_1 => {
      -host   => 'mysql-eg-staging-1.ebi.ac.uk',
      -port   => 4160,
      -user   => 'ensro',
      -db_version => $self->o('ensembl_release')
    },

    staging_2 => {
      -host   => 'mysql-eg-staging-2.ebi.ac.uk',
      -port   => 4275,
      -user   => 'ensro',
      -db_version => $self->o('ensembl_release')
    },

        # NOTE: The databases referenced in the following arrays have to be hashes (not URLs)
        # Add the database entries for the current core databases and link 'curr_core_sources_locs' to them
        'curr_core_sources_locs' => [ $self->o('prod_1') ],
        # Add the database entries for the core databases of the previous release
        'prev_core_sources_locs'   => [ $self->o('staging_1') ],

        # Add the database location of the previous Compara release. Use "undef" if running the pipeline without reuse
        'prev_rel_db' => 'mysql://ensro@mysql-eg-staging-1.ebi.ac.uk:4160/ensembl_compara_fungi_19_72',

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
         '8Gb_job'      => {'LSF' => '-q production-rh6 -M8000  -R"select[mem>8000]  rusage[mem=8000]"' },
         'urgent_hcluster'     => {'LSF' => '-q production-rh6 -M32000 -R"select[mem>32000] rusage[mem=32000]"' },
         'msa'      => {'LSF' => '-q production-rh6 -W 24:00' },
         'msa_himem'    => {'LSF' => '-q production-rh6 -M 32768 -R"select[mem>32768] rusage[mem=32768]" -W 24:00' },
  };
}

sub pipeline_analyses {
    my $self = shift;
    my $all_analyses = $self->SUPER::pipeline_analyses(@_);
    my %analyses_by_name = map {$_->{'-logic_name'} => $_} @$all_analyses;

    ## Extend this section to redefine the resource names of some analysis
    $analyses_by_name{'hcluster_parse_output'}->{'-rc_name'} = '500Mb_job';

    # Some parameters can be division-specific
    if ($self->o('division') eq 'plants') {
        $analyses_by_name{'dump_canonical_members'}->{'-rc_name'} = '500Mb_job';
        $analyses_by_name{'members_against_allspecies_factory'}->{'-rc_name'} = '500Mb_job';
        $analyses_by_name{'blastp'}->{'-rc_name'} = '500Mb_job';
    }

    return $all_analyses;
}


1;
