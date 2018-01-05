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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Example::QfoBlastProteinTrees_conf

=head1 DESCRIPTION  

Parameters to run the ProteinTrees pipeline on the Quest-for-Orthologs dataset using
a all-vs-all blast clustering

=head1 CONTACT

Please contact Compara with questions/suggestions

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Example::TuataraProteinTrees_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::Example::NoMasterProteinTrees_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the Ensembl ones

        #Ensembl core databases:                        
        'homo_sapiens' => {
            -host           => "ensdb-web-16",
            -port           => 5377,
            -user           => "ensro",
            -db_version     => 86,
            -dbname         => "homo_sapiens_core_86_37",
            -species        => "homo_sapiens"
        },

        'gallus_gallus' => {
            -host           => "ens-livemirror",
            -port           => 3306,
            -user           => "ensro",
            -db_version     => 85,
            -dbname         => "gallus_gallus_core_85_4",
            -species        => "gallus_gallus"
        },

        'meleagris_gallopavo' => {
            -host           => "ens-livemirror",
            -port           => 3306,
            -user           => "ensro",
            -db_version     => 85,
            -dbname         => "meleagris_gallopavo_core_85_21",
            -species        => "meleagris_gallopavo"
        },

        'anas_platyrhynchos' => {
            -host           => "ens-livemirror",
            -port           => 3306,
            -user           => "ensro",
            -db_version     => 85,
            -dbname         => "anas_platyrhynchos_core_85_1",
            -species        => "anas_platyrhynchos"
        },

        'taeniopygia_guttata' => {
            -host           => "ens-livemirror",
            -port           => 3306,
            -user           => "ensro",
            -db_version     => 85,
            -dbname         => "taeniopygia_guttata_core_85_1",
            -species        => "taeniopygia_guttata"
        },

        'ficedula_albicollis' => {
            -host           => "ens-livemirror",
            -port           => 3306,
            -user           => "ensro",
            -db_version     => 85,
            -dbname         => "ficedula_albicollis_core_85_1",
            -species        => "ficedula_albicollis"
        },

        'pelodiscus_sinensis' => {
            -host           => "ens-livemirror",
            -port           => 3306,
            -user           => "ensro",
            -db_version     => 85,
            -dbname         => "pelodiscus_sinensis_core_85_1",
            -species        => "pelodiscus_sinensis"
        },

        'anolis_carolinensis' => {
            -host           => "ens-livemirror",
            -port           => 3306,
            -user           => "ensro",
            -db_version     => 85,
            -dbname         => "anolis_carolinensis_core_85_2",
            -species        => "anolis_carolinensis"
        },

        'monodelphis_domestica' => {
            -host           => "ens-livemirror",
            -port           => 3306,
            -user           => "ensro",
            -db_version     => 85,
            -dbname         => "monodelphis_domestica_core_85_5",
            -species        => "monodelphis_domestica"
        },

        'ornithorhynchus_anatinus' => {
            -host           => "ens-livemirror",
            -port           => 3306,
            -user           => "ensro",
            -db_version     => 85,
            -dbname         => "ornithorhynchus_anatinus_core_85_1",
            -species        => "ornithorhynchus_anatinus"
        },

        'danio_rerio' => {
            -host           => "ens-livemirror",
            -port           => 3306,
            -user           => "ensro",
            -db_version     => 85,
            -dbname         => "danio_rerio_core_85_10",
            -species        => "danio_rerio"
        },

        'lepisosteus_oculatus' => {
            -host           => "ens-livemirror",
            -port           => 3306,
            -user           => "ensro",
            -db_version     => 85,
            -dbname         => "lepisosteus_oculatus_core_85_1",
            -species        => "lepisosteus_oculatus"
        },

        'mus_musculus' => {
            -host           => "ens-livemirror",
            -port           => 3306,
            -user           => "ensro",
            -db_version     => 85,
            -dbname         => "mus_musculus_core_85_38",
            -species        => "mus_musculus"
        },

        'takifugu_rubripes' => {
            -host           => "ens-livemirror",
            -port           => 3306,
            -user           => "ensro",
            -db_version     => 85,
            -dbname         => "xenopus_tropicalis_core_85_42",
            -species        => "xenopus_tropicalis"
        },

	    #if collection is set both 'curr_core_dbs_locs' and 'curr_core_sources_locs' parameters are set to undef otherwise the are to use the default pairwise values
        'curr_core_sources_locs' => [
                                      $self->o('gallus_gallus'),       $self->o('meleagris_gallopavo'),
                                      $self->o('anas_platyrhynchos'),  $self->o('taeniopygia_guttata'),
                                      $self->o('ficedula_albicollis'), $self->o('pelodiscus_sinensis'),
                                      $self->o('anolis_carolinensis'), $self->o('monodelphis_domestica'),
                                      $self->o('homo_sapiens'),        $self->o('ornithorhynchus_anatinus'),
                                      $self->o('danio_rerio'),         $self->o('lepisosteus_oculatus'),
                                      $self->o('takifugu_rubripes'),   $self->o('mus_musculus'),
          ],

    # custom pipeline name, in case you don't like the default one
        'pipeline_name'         => 'Tuatara_ProteinTree_'.$self->o('rel_with_suffix'),
        # Tag attached to every single tree
        'division'              => 'tuatara',

        #Since we are loading members from FASTA files, we dont have the dna_frags, so we need to allow it to be missing.
        'allow_missing_coordinates' => 0,

        #Compara server to be used
        'host' => 'compara4',

        # NOTE: The databases referenced in the following arrays have to be hashes (not URLs)
        # Add the database entries for the current core databases and link 'curr_core_sources_locs' to them
        'curr_file_sources_locs'    => [ '/homes/mateus/ENSEMBL/master/ensembl-compara/scripts/examples/tuatara_source.json' ],    # It can be a list of JSON files defining an additionnal set of species
    };
}

1;

