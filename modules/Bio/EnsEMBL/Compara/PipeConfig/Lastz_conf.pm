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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Lastz_conf

=head1 DESCRIPTION  

This is a base configuration files for all LastZ runs.
It is not intended to be run on its own, it just turns the generic
PairAligner pipeline into a LastZ one.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Lastz_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf');  # Inherit from base PairAligner class


sub default_options {
    my ($self) = @_;
    return {
	    %{$self->SUPER::default_options},   # inherit the generic ones

	    #
	    #Default pair_aligner
	    #
	    'pair_aligner_method_link' => [1001, 'LASTZ_RAW'],
	    'pair_aligner_logic_name' => 'LastZ',
	    'pair_aligner_module' => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::LastZ',

# 	    #
	    #Default chain
	    #
	    'chain_input_method_link' => [1001, 'LASTZ_RAW'],
	    'chain_output_method_link' => [1002, 'LASTZ_CHAIN'],
	    'linear_gap' => 'medium',

	    #
	    #Default net 
	    #
	    'net_input_method_link' => [1002, 'LASTZ_CHAIN'],
	    'net_output_method_link' => [16, 'LASTZ_NET'],
	   };
}

1;
