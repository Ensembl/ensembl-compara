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
Example1 : 
init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::Lastz_conf --pipeline_name LASTZ_hagfish_93 --collection hagfish --host mysql-ens-compara-prod-3 --port 4523 --non_ref_species eptatretus_burgeri

Example2 : 
init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::Lastz_conf --pipeline_name LASTZ_human_fish_94 --collection collection-e94_new_species_human_lastz -ref_species homo_sapiens
=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::Lastz_conf;

#
#Test with a master and method_link_species_set_id.
#human chr 22 and mouse chr 16
#Use 'curr_core_sources_locs' to define the location of the core databases.
#Set the master to the ensembl release for this test only.

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::EBI::Lastz_conf');  # Inherit from LastZ@EBI config file


sub default_options {
    my ($self) = @_;
    return {
	    %{$self->SUPER::default_options},   # inherit the generic ones
	    #'pipeline_name'         => 'lastz_ebi_'.$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes

        'host'      => 'mysql-ens-compara-prod-2.ebi.ac.uk',
        'port'      =>  4522,
	    'master_db' => 'mysql://ensro@mysql-ens-compara-prod-1.ebi.ac.uk:4485/ensembl_compara_master',


	    'staging_loc' => {
            -host   => 'mysql-ens-vertannot-staging',
            -port   => 4573,
            -user   => 'ensro',
            -pass   => '',
        },

	    'livemirror_loc' => {
			-host   => 'mysql-ensembl-mirror.ebi.ac.uk',
			-port   => 4240,
			-user   => 'anonymous',
			-pass   => '',
			-db_version => $self->o('rel_with_suffix'),
		},

            # 'curr_core_sources_locs' is a list of servers from where the Registry will load the databases
            # 'curr_core_dbs_locs' is a list of database hash locators (incl. database name)
            # NOTE: you can add example configurations but leave these two lines below as the default
             'curr_core_sources_locs' => [ $self->o('staging_loc') ],
             'curr_core_dbs_locs' => undef,

	   };
}

1;
