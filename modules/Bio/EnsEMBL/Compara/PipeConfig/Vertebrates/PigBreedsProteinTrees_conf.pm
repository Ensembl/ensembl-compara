=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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

Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::PigBreedsProteinTrees_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::PigBreedsProteinTrees_conf -host mysql-ens-compara-prod-X -port XXXX

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output

=head1 DESCRIPTION

The Sus PipeConfig file for StrainsProteinTrees pipeline that should automate most of the pre-execution tasks.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::PigBreedsProteinTrees_conf;

use strict;
use warnings;

use Bio::EnsEMBL::ApiVersion ();

use base ('Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::StrainsProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # Parameters to allow merging different runs of the pipeline
        'collection'            => 'pig_breeds',       # The name of the species-set within that division
        'label_prefix'          => 'pig_breeds_',

        'multifurcation_deletes_all_subnodes' => [ 9822 ], # All the species under the "Sus" genus are flattened, i.e. it's cow vs a rake of pigs

    # clustering parameters:
        # List of species some genes have been projected from
        'projection_source_species_names' => ['sus_scrofa'],

    # homology_dnds parameters:
        # used by 'homology_dNdS'
        'taxlevels' => ['Suidae'],

    # threshold used by per_genome_qc in order to check if the amount of orphan genes are acceptable
    # values are lower than in the Verterbates config file because the clustering method is less comprehensive
        'mapped_gene_ratio_per_taxon' => {
            '9821'   => 0.75,    # suidae
        },

    # GOC parameters
        'goc_taxlevels' => ['Suidae'],
    };
}

1;
