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

Parameters to run the ProteinTrees pipeline without a master database.
It can use a mix of Ensembl core databases and custom defined assemblies. To be defined at: 'curr_file_sources_locs'.
Currently we support sources from augustus_maker, refseq and gigascience.
It uses a all-vs-all blast clustering approach.

Custom assemblies should be defined in a JSON file like this:
    [
        {
            "production_name" : "tuatara",
            "taxonomy_id"     : "8508",
            "cds_fasta"       : "/your/source/directory/my_species_1.cds.fa",
            "prot_fasta"      : "/your/source/directory/my_species_1.prot.fa",
            "gene_coord_gff"  : "/your/source/directory/my_species_1.gff",
            "source"          : "augustus_maker",
        },

        {
            "production_name" : "alligator_mississippiensis",
            "taxonomy_id"     : "8496",
            "cds_fasta"       : "/your/source/directory/my_species_2.cds.fa",
            "prot_fasta"      : "/your/source/directory/my_species_2.prot.fa",
            "gene_coord_gff"  : "/your/source/directory/my_species_2.gff",
            "source"          : "refseq",
        },

        {
            "production_name" : "pogona_vitticeps",
            "taxonomy_id"     : "103695",
            "cds_fasta"       : "/your/source/directory/my_species_3.cds.fa",
            "prot_fasta"      : "/your/source/directory/my_species_3.prot.fa",
            "gene_coord_gff"  : "/your/source/directory/my_species_3.gff",
            "cience"          : "gigascience",
        },
    ]

=head1 CONTACT

Please contact Compara with questions/suggestions

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Example::NoMasterProteinTrees_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the Ensembl ones

        #Example of how to use Ensembl core databases:                        
        'homo_sapiens' => {
            -host           => "ensembldb.ensembl.org",
            -port           => 3306,
            -user           => "anonymous",
            -db_version     => 88,
            -dbname         => "homo_sapiens_vega_88_38",
            -species        => "homo_sapiens"
        },

        'filter_high_coverage'      => 0,
	    	    
	    #if collection is set both 'curr_core_dbs_locs' and 'curr_core_sources_locs' parameters are set to undef otherwise the are to use the default pairwise values
        'curr_core_sources_locs' => [
                                      $self->o('homo_sapiens'),
          ],


    # parameters that are likely to change from execution to another:
        # It is very important to check that this value is current (commented out to make it obligatory to specify)

        # To run without a master database
        'mlss_id'                   => undef,
        'do_stable_id_mapping'      => 0,
        'prev_rel_db'               => undef,
        'clustering_mode'           => 'blastp',

    # custom pipeline name, in case you don't like the default one
        'pipeline_name'         => 'My_ProteinTree_pipeline_'.$self->o('rel_with_suffix'),
        # Tag attached to every single tree
        'division'              => 'my_division',

        #Since we are loading members from FASTA files, we dont have the dna_frags, so we need to allow it to be missing.
        'allow_missing_coordinates' => 0,

        #Compara/MySQL server to be used
        'host' => 'compara4',

    # connection parameters to various databases:

        # the master database for synchronization of various ids (use undef if you don't have a master database)
        'master_db' => undef,
        'ncbi_db'   => 'mysql://anonymous@ensembldb.ensembl.org/ensembl_compara_89',

        # NOTE: The databases referenced in the following arrays have to be hashes (not URLs)
        # Add the database entries for the current core databases and link 'curr_core_sources_locs' to them
        'curr_file_sources_locs'    => [ '/nfs/production/panda/ensembl/compara/mateus/SANGER/tuatara/tuatara_data/tuatara_source.json' ],    # It can be a list of JSON files defining an additionnal set of species
    };
}

1;

