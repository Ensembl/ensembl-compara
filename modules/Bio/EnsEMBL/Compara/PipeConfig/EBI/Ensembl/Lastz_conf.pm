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

=head1 SYNOPSIS

Example1 : 
init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::Lastz_conf --pipeline_name LASTZ_hagfish_93 --collection hagfish --host mysql-ens-compara-prod-3 --port 4523 --non_ref_species eptatretus_burgeri

Example2 : 
init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::Lastz_conf --pipeline_name LASTZ_human_fish_94 --collection collection-e94_new_species_human_lastz -ref_species homo_sapiens

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::Lastz_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::EBI::Lastz_conf');  # Inherit from LastZ@EBI config file


sub default_options {
    my ($self) = @_;
    return {
	    %{$self->SUPER::default_options},   # inherit the generic ones
	    'pipeline_name'         => 'lastz_' . $self->o('division') . '_'.$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes

        'host'      => 'mysql-ens-compara-prod-2.ebi.ac.uk',
        'port'      =>  4522,
	    'master_db' => 'compara_master',
        'division'  => 'ensembl',
        'reg_conf'  => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/production_reg_'.$self->o('division').'_conf.pl',

	   };
}

1;
