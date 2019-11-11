=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

  Bio::EnsEMBL::Compara::PipeConfig::EBI::Vertebrates::ProteinTrees_conf

=head1 DESCRIPTION

    The Vertebrates PipeConfig file for ProteinTrees pipeline that should automate most of the pre-execution tasks.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::Vertebrates::ProteinTrees_conf;

use strict;
use warnings;


use base ('Bio::EnsEMBL::Compara::PipeConfig::EBI::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        # Tag attached to every single tree. Also used to select params - e.g. reg_conf, species_tree 
        'division'      => 'vertebrates',

        'pipeline_name' => $self->o('collection') . '_' . $self->o('division').'_protein_trees_'.$self->o('rel_with_suffix'),

    # User details

    # parameters that are likely to change from execution to another:
        # You can add a letter to distinguish this run from other runs on the same release
        
        #'rel_suffix'            => '',
        # names of species we don't want to reuse this time
        'do_not_reuse_list'     => [ ],

    #default parameters for the geneset qc

    # data directories:

    # "Member" parameters:
        'allow_ambiguity_codes'     => 1,

    # blast parameters:
        # cdhit is used to filter out proteins that are too close to each other
        'cdhit_identity_threshold' => 0.99,

    # clustering parameters:
        # affects 'hcluster_dump_input_per_genome'
        'outgroups'                     => { 'saccharomyces_cerevisiae' => 2 },
        # File with gene / peptide names that must be excluded from the clusters (e.g. know to disturb the trees)
        'gene_blacklist_file'           => '/nfs/production/panda/ensembl/warehouse/compara/proteintree_blacklist.e82.txt',

    # tree building parameters:
        'use_raxml'                 => 0,
        'use_quick_tree_break'      => 1,
        'use_notung'                => 0,

    # sequence type used on the phylogenetic inferences
    # It has to be set to 1 for the strains
        'use_dna_for_phylogeny'     => 0,

    # alignment filtering options

    # species tree reconciliation
        # you can define your own species_tree for 'notung' or 'CAFE'. It *has* to be binary
        'binary_species_tree_input_file'   => $self->o('binary_species_tree'),

    # homology_dnds parameters:
        # used by 'homology_dNdS'
        'taxlevels'                 => ['Theria', 'Sauria', 'Tetraodontiformes', 'Percomorphaceae'],

    # threshold used by per_genome_qc in order to check if the amount of orphan genes are acceptable
    # values were infered by checking previous releases, values that are out of these ranges may be caused by assembly and/or gene annotation problems.
        'mapped_gene_ratio_per_taxon' => {
            '2759'    => 0.5,     #eukaryotes
            '33208'   => 0.65,    #metazoans
            '7742'    => 0.85,    #vertebrates
            '117571'  => 0.9,     #bony vertebrates
            '9443'    => 0.95,    #primates
          },

    # mapping parameters:
        'do_stable_id_mapping'      => 1,
        'do_treefam_xref'           => 1,
        # The TreeFam release to map to
        'tf_release'                => '9_69',

        # How will the pipeline create clusters (families) ?
        # Possible values: 'blastp' (default), 'hmm', 'hybrid'
        #   'blastp' means that the pipeline will run a all-vs-all blastp comparison of the proteins and run hcluster to create clusters. This can take a *lot* of compute
        #   'hmm' means that the pipeline will run an HMM classification
        #   'hybrid' is like "hmm" except that the unclustered proteins go to a all-vs-all blastp + hcluster stage
        #   'topup' means that the HMM classification is reused from prev_rel_db, and topped-up with the updated / new species  >> UNIMPLEMENTED <<
        #   'ortholog' means that it makes clusters out of orthologues coming from 'ref_ortholog_db' (transitive closre of the pairwise orthology relationships)
        'clustering_mode'           => 'hybrid',

        # List of species some genes have been projected from
        'projection_source_species_names' => [ 'homo_sapiens', 'mus_musculus', 'danio_rerio' ],

        # How much the pipeline will try to reuse from "prev_rel_db"
        # Possible values: 'clusters' (default), 'blastp', 'members'
        #   'members' means that only the members are copied over, and the rest will be re-computed
        #   'hmms' is like 'members', but also copies the HMM profiles. It requires that the clustering mode is not 'blastp'  >> UNIMPLEMENTED <<
        #   'hmm_hits' is like 'hmms', but also copies the HMM hits  >> UNIMPLEMENTED <<
        #   'blastp' is like 'members', but also copies the blastp hits. It requires that the clustering mode is 'blastp'
        #   'clusters' is like 'hmm_hits' or 'blastp' (depending on the clustering mode), but also copies the clusters
        #   'alignments' is like 'clusters', but also copies the alignments  >> UNIMPLEMENTED <<
        #   'trees' is like 'alignments', but also copies the trees  >> UNIMPLEMENTED <<
        #   'homologies is like 'trees', but also copies the homologies  >> UNIMPLEMENTED <<

    # CAFE parameters
        # Do we want to initialise the CAFE part now ?
        'initialise_cafe_pipeline'  => 1,
        #Use Timetree divergence times for the CAFETree internal nodes
        'use_timetree_times'        => 1,

    # GOC parameters
        'goc_taxlevels'                 => ["Euteleostomi","Ciona"],
        'calculate_goc_distribution'    => 0,
        'goc_batch_size'                => 20,

    # Extra analyses
        # Export HMMs ?
        'do_hmm_export'                 => 0,
        # Do we want the Gene QC part to run ?
        'do_gene_qc'                    => 1,
        # Do we extract overall statistics for each pair of species ?
        'do_homology_stats'             => 1,
        # Do we need a mapping between homology_ids of this database to another database ?
        # This parameter is automatically set to 1 when the GOC pipeline is going to run with a reuse database
        'do_homology_id_mapping'                 => 1,
    };
}



sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    ## Extend this section to redefine the resource names of some analysis
    my %overriden_rc_names = (
        'CAFE_table'                => '24Gb_job',
        'hcluster_run'              => '1Gb_job',
        'hcluster_parse_output'     => '1Gb_job',
        'split_genes'               => 'default',   # This is 250Mb
        'CAFE_species_tree'         => '24Gb_job',
    );
    foreach my $logic_name (keys %overriden_rc_names) {
        $analyses_by_name->{$logic_name}->{'-rc_name'} = $overriden_rc_names{$logic_name};
    }
    $analyses_by_name->{'CAFE_analysis'}->{'-parameters'}{'pvalue_lim'} = 1;
}


1;
