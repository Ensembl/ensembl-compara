=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

  Bio::EnsEMBL::Compara::PipeConfig::Example::WBParaSiteProteinTrees_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Example::WBParaSiteProteinTrees_conf \
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

package Bio::EnsEMBL::Compara::PipeConfig::Example::WBParaSiteProteinTrees_conf;

use strict;
use warnings;


use base ('Bio::EnsEMBL::Compara::PipeConfig::Example::EGProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the EnsemblGenomes ones (especially all the paths and capacities)

    # parameters that are likely to change from execution to another:
        #mlss_id => 40043,
        #'do_not_reuse_list' => ['guillardia_theta'], # set this to empty or to the genome db names we should ignore

    # custom pipeline name, in case you don't like the default one
        'dbowner' => 'ensembl_compara',       # Used to prefix the database name (in HiveGeneric_conf)
        'pipeline_name' => $self->o('division').'_hom_'.$self->o('ps_release').'_'.$self->o('ensembl_release'),
        'division'  => 'wbparasite',

    # dependent parameters: updating 'work_dir' should be enough
        'base_dir'              =>  '/nfs/nobackup2/ensemblgenomes/wormbase/parasite/'.$self->o('ENV', 'USER').'/compara',
        # work_dir and exe_dir are defined in the base class

    # "Member" parameters:

    # blast parameters:

    # clustering parameters:

    # tree building parameters:
        'species_tree_input_file'   =>  '/nfs/panda/ensemblgenomes/wormbase/parasite/config/compara_guide_tree.wbparasite.tre',

    # alignment filtering options

    # species tree reconciliation

    # homology_dnds parameters:

    # mapping parameters:

    # executable locations:

    # HMM specific parameters (set to 0 or undef if not in use)

    # hive_capacity values for some analyses:

    # hive priority for non-LOCAL health_check analysis:

    # connection parameters to various databases:

        # the production database itself (will be created)
        # it inherits most of the properties from HiveGeneric, we usually only need to redefine the host, but you may want to also redefine 'port'

        # the master database for synchronization of various ids (use undef if you don't have a master database)
        'master_db' => 'mysql://ensro@mysql-eg-pan-1.ebi.ac.uk:4276/ensembl_compara_master_parasite',

    ######## THESE ARE PASSED INTO LOAD_REGISTRY_FROM_DB SO PASS IN DB_VERSION
    ######## ALSO RAISE THE POINT ABOUT LOAD_FROM_MULTIPLE_DBs

    prod_1 => {
      -host   => 'mysql-ps-prod-1.ebi.ac.uk',
      -port   => 4450,
      -user   => 'ensro',
      -db_version => $self->o('ensembl_release')
    },

    staging_1 => {
      -host   => 'mysql-ps-staging-1.ebi.ac.uk',
      -port   => 4451,
      -user   => 'ensro',
      -db_version => $self->o('ensembl_release')
    },


    # NOTE: The databases referenced in the following arrays have to be hashes (not URLs)
    # Add the database entries for the current core databases and link 'curr_core_sources_locs' to them
    'curr_core_sources_locs' => [ $self->o('prod_1') ],
    
    # Add the database entries for the core databases of the previous release
    'prev_core_sources_locs'   => [ ],
          
    # Add the database location of the previous Compara release. Use "undef" if running the pipeline without reuse
    'prev_rel_db' => undef,

    };
}



sub resource_classes {
  my ($self) = @_;
  return {
         # Many classes are already defined there
         %{$self->SUPER::resource_classes},
         # But we could add some more here
  };
}

sub pipeline_analyses {
    my $self = shift;
    my $all_analyses = $self->SUPER::pipeline_analyses(@_);
    my %analyses_by_name = map {$_->{'-logic_name'} => $_} @$all_analyses;

    ## Extend this section to redefine the resource names of some analysis
    # e.g. $analyses_by_name{'hcluster_parse_output'}->{'-rc_name'} = '500Mb_job';

    return $all_analyses;
}


1;
