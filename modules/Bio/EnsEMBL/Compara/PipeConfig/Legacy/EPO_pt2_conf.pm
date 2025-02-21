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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Legacy::EPO_pt2_conf

=head1 SYNOPSIS

    #1. Update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Legacy::EPO_pt2_conf -host mysql-ens-compara-prod-X -port XXXX \
            -division $COMPARA_DIV -species_set_name <species_set_name> -mlss_id <curr_epo_mlss_id>

    #5. Run the "beekeeper.pl ... -sync" and then " -loop" command suggested by init_pipeline.pl

    #6. Fix the code when it crashes

=head1 DESCRIPTION  

    This configuration file gives defaults for mapping (using exonerate at the
    moment) anchors to a set of target genomes (dumped text files).

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Legacy::EPO_pt2_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version v2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For INPUT_PLUS

use Bio::EnsEMBL::Compara::PipeConfig::Parts::EPOMapAnchors;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;

    return {
    	%{$self->SUPER::default_options},

        'pipeline_name' => $self->o('species_set_name').'_epo_anchor_mapping_'.$self->o('rel_with_suffix'),

        'master_db'         => 'compara_master',
        # database containing the anchors for mapping
        'compara_anchor_db' => $self->o('species_set_name') . '_epo_anchors',
        'reuse_db'          => $self->o('species_set_name') . '_epo_prev',

        'mapping_params'    => { bestn=>11, gappedextension=>"no", softmasktarget=>"no", percent=>75, showalignment=>"no", model=>"affine:local", },

    	# 'mlss_id' => 825, # epo mlss from master
    	
    	 # dont dump the MT sequence for mapping
    	'only_nuclear_genome' => 1,
        # batch size of anchor sequences to map
        'anchor_batch_size' => 1000,
        
        # Capacities
        'low_capacity'                  => 10,
        'map_anchors_batch_size'        => 5,
        'map_anchors_capacity'          => 1000,
        'trim_anchor_align_batch_size'  => 20,
        'trim_anchor_align_capacity'    => 500,
    };
}


sub pipeline_wide_parameters {
	my $self = shift @_;
	return {
		%{$self->SUPER::pipeline_wide_parameters},

                'mlss_id' => $self->o('mlss_id'),
		'genome_dumps_dir' => $self->o('genome_dumps_dir'),
		'compara_anchor_db' => $self->o('compara_anchor_db'),
		'master_db' => $self->o('master_db'),
		'reuse_db' => $self->o('reuse_db'),
	};
	
}

sub pipeline_analyses {
    my $self = shift;

    my $pipeline_analyses = Bio::EnsEMBL::Compara::PipeConfig::Parts::EPOMapAnchors::pipeline_analyses_epo_anchor_mapping($self);
    $pipeline_analyses->[0]->{'-input_ids'} = [{}];
    return $pipeline_analyses;
}


1;
