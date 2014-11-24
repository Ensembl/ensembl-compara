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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::BaseAge_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::BaseAge_conf -password <your_password>

=head1 DESCRIPTION  

    Calculate the age of a base

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::BaseAge_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.2;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},
            'ensembl_cvs_root_dir' => $ENV{'ENSEMBL_CVS_ROOT_DIR'}, 

            'ref_species' => 'homo_sapiens',
            'release_suffix'=> '', # set it to '' for the actual release
            'rel_with_suffix'       => $self->o('ensembl_release').$self->o('release_suffix'),
            'pipeline_name' => $self->o('ref_species').'_base_age_'.$self->o('rel_with_suffix'), # name used by the beekeeper to prefix job names on the farm

            #Write either the node name or node_id in "name" field of the bed file
#            'name' => "node_id",
            'name' => "name",

            #Location url of database to get EPO GenomicAlignTree objects from
#            'compara_url' => 'mysql://ensro@ens-livemirror:3306/ensembl_compara_' . $self->o('ensembl_release'),
            'compara_url' => 'mysql://ensro@compara4:3306/sf5_epo_17mammals_77',
            'clade_taxon_id' => 9443,   # this is the taxon_id of Primates

            #Location url of database to get snps from
            #'variation_url' => 'mysql://ensro@ens-livemirror:3306/' . $self->o('release'),
            'variation_url' => 'mysql://ensro@ens-staging1:3306/homo_sapiens_variation_77_38?group=variation',
            
            #Location details of ancestral sequences database
            #'anc_host'   => 'ens-livemirror',
            'anc_host'   => 'compara4',
            'anc_name'   => 'ancestral_sequences',
            #'anc_dbname' => 'ensembl_ancestral_' . $self->o('ensembl_release'),
            'anc_dbname' => 'sf5_epo_17mammals_ancestral_core_77',

            #Connection parameters for production database (the rest is defined in the base class)
            'host' => 'compara2',

            'master_db' => 'mysql://ensro@compara1/sf5_ensembl_compara_master',

            'staging_loc1' => {
                               -host   => 'ens-staging1',
                               -port   => 3306,
                               -user   => 'ensro',
                               -pass   => '',
                               -db_version => $self->o('ensembl_release'),
                              },
            'staging_loc2' => {
                               -host   => 'ens-staging2',
                               -port   => 3306,
                               -user   => 'ensro',
                               -pass   => '',
                               -db_version => $self->o('ensembl_release'),
                              },  
            'livemirror_loc' => {
                                 -host   => 'ens-livemirror',
                                 -port   => 3306,
                                 -user   => 'ensro',
                                 -pass   => '',
                                 -db_version => $self->o('ensembl_release'),
                                },

            'curr_core_sources_locs'    => [ $self->o('staging_loc1'), $self->o('staging_loc2'), ],
#            'curr_core_sources_locs'    => [ $self->o('livemirror_loc') ],

            # executable locations:
            'populate_new_database_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/populate_new_database.pl",
            'big_bed_exe' => '/software/ensembl/funcgen/bedToBigBed',
            'baseage_autosql' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/baseage_autosql.as",

            #Locations to write output files
            'bed_dir'        => sprintf('/lustre/scratch109/ensembl/%s/%s', $ENV{USER}, $self->o('pipeline_name')),
            'chr_sizes_file' => 'chrom.sizes',
            'big_bed_file'   => 'base_age'.$self->o('ensembl_release').'.bb',

            #Number of workers to run base_age analysis
            'base_age_capacity'        => 100,

            #
            #Resource requirements
            #
            'memory_suffix' => "", #temporary fix to define the memory requirements in resource_classes

          };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation

            'mkdir -p '.$self->o('bed_dir'), #Make bed_dir directory

	   ];
}

sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;

    return {
            %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class
    };
}

sub resource_classes {
    my ($self) = @_;

    return {
         %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
         '100Mb' => { 'LSF' => '-C0 -M100' . $self->o('memory_suffix') .' -R"select[mem>100] rusage[mem=100]"' },
	 '1Gb' =>    { 'LSF' => '-C0 -M1000' . $self->o('memory_suffix') .' -R"select[mem>1000] rusage[mem=1000]"' },  
	 '1.8Gb' => { 'LSF' => '-C0 -M1800' . $self->o('memory_suffix') .' -R"select[mem>1800] rusage[mem=1800]"' },
         '3.6Gb' =>  { 'LSF' => '-C0 -M3600' . $self->o('memory_suffix') .' -R"select[mem>3600] rusage[mem=3600]"' },
    };
}

sub pipeline_analyses {
    my ($self) = @_;

    return [
            # ---------------------------------------------[Run poplulate_new_database.pl script ]---------------------------------------------------
	    {  -logic_name => 'populate_new_database',
	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::PopulateNewDatabase',
	       -parameters    => {
				  'program'        => $self->o('populate_new_database_exe'),
				  'mlss_id'        => $self->o('mlss_id'),
                                  'master_db'      => $self->o('master_db'),				  
                                  'pipeline_db'    => $self->dbconn_2_url('pipeline_db'),
				 },
	       -flow_into => {
			      1 => [ 'load_genomedb_factory' ],
			     },
               -input_ids => [{}],
	       -rc_name => '1Gb',
	    },

            # ---------------------------------------------[load GenomeDB entries from master+cores]---------------------------------------------

        {   -logic_name => 'load_genomedb_factory',
	    -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
            -parameters => {
                'compara_db'    => $self->o('master_db'),   # that's where genome_db_ids come from
                'mlss_id'       => $self->o('mlss_id'),

                'call_list'             => [ 'compara_dba', 'get_MethodLinkSpeciesSetAdaptor', ['fetch_by_dbID', '#mlss_id#'], 'species_set_obj', 'genome_dbs'],
                'column_names2getters'  => { 'genome_db_id' => 'dbID', 'species_name' => 'name', 'assembly_name' => 'assembly', 'genebuild' => 'genebuild', 'locator' => 'locator' },

                'fan_branch_code'       => 2,
            },
            -flow_into => {
                '2->A' => [ 'load_genomedb' ],
		'A->1' => [ 'load_ancestral_genomedb' ],
            },
	    -rc_name => '100Mb',
	},

        {   -logic_name => 'load_genomedb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -parameters => {
                'registry_dbs'  => $self->o('curr_core_sources_locs'),
                'db_version'    => $self->o('ensembl_release'),
            },
	    -rc_name => '100Mb',
        },
        {   -logic_name => 'load_ancestral_genomedb',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                            'sql' => [ 'INSERT INTO genome_db (genome_db_id, name, locator) VALUE (63, "ancestral_sequences", "Bio::EnsEMBL::DBSQL::DBAdaptor/host=' . $self->o('anc_host') .';port=3306;user=ensro;pass=;dbname=' . $self->o('anc_dbname') . ';species=' . $self->o('anc_name') . ';species_id=1;disconnect_when_inactive=1")' ],
                           },
            #                -input_ids => [ { } ],
            -rc_name => '100Mb',
            -flow_into => {
                           '1' => [ 'chrom_sizes' ],
                          },
        },
            { -logic_name => 'chrom_sizes',
              -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
              -parameters => {
                              'bed_dir' => $self->o('bed_dir'),
                              'chr_sizes_file' => $self->o('chr_sizes_file'),
                              'cmd' => $self->db_cmd() . " --append -N -sql \"SELECT concat('chr',dnafrag.name), length FROM dnafrag JOIN genome_db USING (genome_db_id) WHERE genome_db.name = '" . $self->o('ref_species') . "'" . " AND is_reference = 1 AND coord_system_name = 'chromosome'\" >#bed_dir#/#chr_sizes_file#",
                             },
              -flow_into => {
                             '1' => [ 'base_age_factory' ],
                            },
           },

            {  -logic_name => 'base_age_factory',
               -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
               -parameters => {
                               'ref_species' => $self->o('ref_species'),
                               'inputquery'    => "SELECT dnafrag.name as seq_region FROM dnafrag JOIN genome_db USING (genome_db_id) WHERE genome_db.name = '" . $self->o('ref_species') . "'" . " AND is_reference = 1 AND coord_system_name = 'chromosome'",
                               'fan_branch_code'   => 2,
                              },
               -flow_into => {
                              '2->A' => [ 'base_age' ],
                              'A->1' => [ 'big_bed' ],
                             },
               -rc_name => '100Mb',
            },
            
            { -logic_name => 'base_age',
              -module     => 'Bio::EnsEMBL::Compara::RunnableDB::BaseAge::BaseAge',
              -parameters => {
                              'compara_url' => $self->o('compara_url'),
                              'variation_url' => $self->o('variation_url'),
                              'mlss_id' => $self->o('mlss_id'),
                              'species' => $self->o('ref_species'),
                              'bed_dir' => $self->o('bed_dir'),
                              'name' => $self->o('name'),
                              'clade_taxon_id' => $self->o('clade_taxon_id'),
                             },
              -batch_size => 1,
              -hive_capacity => $self->o('base_age_capacity'),
              -rc_name => '3.6Gb',
              -flow_into => {
                             2 => ':////accu?bed_files={seq_region}',
                            },

            },
             { -logic_name => 'big_bed',
               -module     => 'Bio::EnsEMBL::Compara::RunnableDB::BaseAge::BigBed',
               -parameters => {
                               'program' => $self->o('big_bed_exe'),
                              'baseage_autosql' => $self->o('baseage_autosql'),
                               'big_bed_file' => '#bed_dir#/'.$self->o('big_bed_file'),
                               'bed_dir' => $self->o('bed_dir'),
                               'chr_sizes_file' => $self->o('chr_sizes_file'),
                               'chr_sizes' => '#bed_dir#/#chr_sizes_file#',
                              },
               -rc_name => '1.8Gb',
             },

     ];
}
1;
