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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::MurinaeProteinTrees_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Example::EnsemblProteinTrees_conf \
        -password <your_password> -mlss_id <your_current_PT_mlss_id>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output

=head1 DESCRIPTION

The PipeConfig file for ProteinTrees pipeline that should automate most of the pre-execution tasks.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::MurinaeProteinTrees_conf;

use strict;
use warnings;

use Bio::EnsEMBL::ApiVersion ();

use base ('Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        # the production database itself (will be created)
        # it inherits most of the properties from HiveGeneric, we usually only need to redefine the host, but you may want to also redefine 'port'

        'host'  => 'mysql-ens-compara-prod-1.ebi.ac.uk',
        'port'  => 4485,

    # User details

    # parameters that are likely to change from execution to another:
        # You can add a letter to distinguish this run from other runs on the same release
        'rel_suffix'            => '',
        # names of species we don't want to reuse this time
        'do_not_reuse_list'     => [ ],

        # Tag attached to every single tree
        'division'              => 'murinae',

    # Parameters to allow merging different runs of the pipeline
        'dbID_range_index'      => 3,
        'label_prefix'          => 'mur_',


    #default parameters for the geneset qc

    # dependent parameters: updating 'base_dir' should be enough

    # "Member" parameters:

    # blast parameters:

    # clustering parameters:

    # tree building parameters:
        'use_raxml'                 => 1,
        'use_dna_for_phylogeny'     => 1,

    # alignment filtering options

    # species tree reconciliation

    # homology_dnds parameters:
        # used by 'homology_dNdS'
        'taxlevels'                 => ['Murinae'],

    # mapping parameters:
        'do_stable_id_mapping'      => 0,
        'do_treefam_xref'           => 0,

    # HMM specific parameters (set to 0 or undef if not in use)

    # hive_capacity values for some analyses:

    # connection parameters to various databases:

        # the master database for synchronization of various ids (use undef if you don't have a master database)
        'master_db' => 'mysql://ensro@mysql-ens-compara-prod-1.ebi.ac.uk:4485/ensembl_compara_master',

        # Add the database location of the previous Compara release. Leave commented out if running the pipeline without reuse
        'prev_rel_db' => 'mysql://ensro@mysql-ens-compara-prod-1:4485/muffato_mouse_strain_homologies_89',

        # Where the members come from (as loaded by the LoadMembers pipeline)
        'member_db'   => 'mysql://ensro@mysql-ens-compara-prod-2.ebi.ac.uk:4522/muffato_load_members_90_ensembl',

        # Where to draw the orthologues from
        'ref_ortholog_db'   => 'mysql://ensro@mysql-ens-compara-prod-1:4485/muffato_protein_trees_90',

        # If 'prev_rel_db' above is not set, you need to set all the dbs individually
        #'goc_reuse_db'          => 'mysql://ensro@mysql-ens-compara-prod-2.ebi.ac.uk:4522/waakanni_protein_trees_88',
        #'mapping_db'            => 'mysql://ensro@mysql-ens-compara-prod-2.ebi.ac.uk:4522/waakanni_protein_trees_88',


        # How will the pipeline create clusters (families) ?
        #   'ortholog' means that it makes clusters out of orthologues coming from 'ref_ortholog_db' (transitive closre of the pairwise orthology relationships)
        'clustering_mode'           => 'ortholog',

    # CAFE parameters
        # Do we want to initialise the CAFE part now ?
        'initialise_cafe_pipeline'  => 0,

    # GOC parameters
        'goc_taxlevels'                 => ['Murinae'],

    # Extra analyses
        # Export HMMs ?
        'do_hmm_export'                 => 0,
        # Do we want the Gene QC part to run ?
        'do_gene_qc'                    => 0,
        # Do we extract overall statistics for each pair of species ?
        'do_homology_stats'             => 1,
        # Do we need a mapping between homology_ids of this database to another database ?
        # This parameter is automatically set to 1 when the GOC pipeline is going to run with a reuse database
        'do_homology_id_mapping'                 => 1,
    };
}


sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'cdna'              => $self->o('use_dna_for_phylogeny'),
        'ref_ortholog_db'   => $self->o('ref_ortholog_db'),
    }
}


sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    $analyses_by_name->{'make_treebest_species_tree'}->{'-parameters'}->{'allow_subtaxa'} = 1;  # We have sub-species
    $analyses_by_name->{'make_treebest_species_tree'}->{'-parameters'}->{'multifurcation_deletes_all_subnodes'} = [ 10088 ];    # All the species under the "Mus" genus are flattened, i.e. it's rat vs a rake of mice
    $analyses_by_name->{'expand_clusters_with_projections'}->{'-rc_name'} = '500Mb_job';
    $analyses_by_name->{'split_genes'}->{'-hive_capacity'} = 300;
}


1;

