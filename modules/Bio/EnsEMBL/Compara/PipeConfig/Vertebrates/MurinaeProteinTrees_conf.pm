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

  Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::MurinaeProteinTrees_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::MurinaeProteinTrees_conf -host mysql-ens-compara-prod-X -port XXXX \
            -mlss_id <curr_murinae_ptree_mlss_id>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output

=head1 DESCRIPTION

The Murinae PipeConfig file for StrainsProteinTrees pipeline that should automate most of the pre-execution tasks.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::MurinaeProteinTrees_conf;

use strict;
use warnings;

use Bio::EnsEMBL::ApiVersion ();

use base ('Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::StrainsProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # Parameters to allow merging different runs of the pipeline
        'collection'            => 'murinae',       # The name of the species-set within that division
        'dbID_range_index'      => 18,
        'label_prefix'          => 'mur_',

        'multifurcation_deletes_all_subnodes' => [ 10088 ], # All the species under the "Mus" genus are flattened, i.e. it's rat vs a rake of mice

    # clustering parameters:
        # How will the pipeline create clusters (families) ?
        #   'ortholog' means that it makes clusters out of orthologues coming from 'ref_ortholog_db' (transitive closre of the pairwise orthology relationships)
        'clustering_mode' => 'ortholog',

        # List of species some genes have been projected from
        'projection_source_species_names' => ['mus_musculus'],

    # homology_dnds parameters:
        # used by 'homology_dNdS'
        'taxlevels' => ['Murinae'],

    # threshold used by per_genome_qc in order to check if the amount of orphan genes are acceptable
    # values are lower than in the Verterbates config file because the clustering method is less comprehensive
        'mapped_gene_ratio_per_taxon' => {
            '39107'   => 0.75,    #murinae
        },

    # GOC parameters
        'goc_taxlevels' => ['Murinae'],
    };
}

1;
