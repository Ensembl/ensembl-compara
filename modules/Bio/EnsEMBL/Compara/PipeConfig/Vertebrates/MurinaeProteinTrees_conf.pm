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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::MurinaeProteinTrees_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::MurinaeProteinTrees_conf -host mysql-ens-compara-prod-X -port XXXX

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output

=head1 DESCRIPTION

The Murinae PipeConfig file for StrainsProteinTrees pipeline that should automate most of the pre-execution tasks.

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
        'label_prefix'          => 'mur_',

        'multifurcation_deletes_all_subnodes' => [ 10088 ], # All the species under the "Mus" genus are flattened, i.e. it's rat vs a rake of mice

    # clustering parameters:
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


sub tweak_analyses {
    my $self = shift;

    $self->SUPER::tweak_analyses(@_);

    my $analyses_by_name = shift;

    ## Extend this section to redefine the resource names of some analysis
    my %overriden_rc_names = (
        'expand_clusters_with_projections'  => '1Gb_job',
        'overall_qc'    => '8Gb_job',
    );
    foreach my $logic_name (keys %overriden_rc_names) {
        $analyses_by_name->{$logic_name}->{'-rc_name'} = $overriden_rc_names{$logic_name};
    }
}


1;
