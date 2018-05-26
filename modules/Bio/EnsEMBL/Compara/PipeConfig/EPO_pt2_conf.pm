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

Bio::EnsEMBL::Compara::PipeConfig::EPO_pt2_conf

=head1 SYNOPSIS

    #1. Update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. Check all default_options, you will probably need to change the following :
        pipeline_db (-host)
        resource_classes 

	'ensembl_cvs_root_dir' - the path to the compara/hive/ensembl GIT checkouts - set as an environment variable in your shell
        'password' - your mysql password
	'compara_anchor_db' - database containing the anchor sequences (entered in the anchor_sequence table)
	'master_db' - location of your master db containing relevant info in the genome_db, dnafrag, species_set, method_link* tables
        The dummy values - you should not need to change these unless they clash with pre-existing values associated with the pairwise alignments you are going to use

    #4. Run init_pipeline.pl script:
        Using command line arguments:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EPO_pt2_conf.pm

    #5. Run the "beekeeper.pl ... -sync" and then " -loop" command suggested by init_pipeline.pl

    #6. Fix the code when it crashes

=head1 DESCRIPTION  

    This configuaration file gives defaults for mapping (using exonerate at the moment) anchors to a set of target genomes (dumped text files)

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EPO_pt2_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For INPUT_PLUS

use Bio::EnsEMBL::Compara::PipeConfig::Parts::EPOMapAnchors;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;

    return {
    	%{$self->SUPER::default_options},

        'pipeline_name' => $self->o('species_set_name').'_epo_anchor_mapping_'.$self->o('rel_with_suffix'),

        'mapping_params'    => { bestn=>11, gappedextension=>"no", softmasktarget=>"no", percent=>75, showalignment=>"no", model=>"affine:local", },

    	'anchors_mlss_id' => 10000, # this should correspond to the mlss_id in the anchor_sequence table of the compara_anchor_db database (from EPO_pt1_conf.pm)
    	# 'mlss_id' => 825, # epo mlss from master
        'mapping_method_link_id' => 10000, # dummy value - should not need to change
    	'mapping_method_link_name' => 'MAP_ANCHORS', 
    	'mapping_mlssid' => 10000, # dummy value - should not need to change
    	'trimmed_mapping_mlssid' => 11000, # dummy value - should not need to change
    	
    	 # dont dump the MT sequence for mapping
    	'only_nuclear_genome' => 1,
    	 # batch size of grouped anchors to map
    	'anchor_batch_size' => 10,
    	 # max number of sequences to allow in an anchor
    	'anc_seq_count_cut_off' => 15,
    };
}

sub pipeline_create_commands {
    my ($self) = @_; 
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
        $self->pipeline_create_commands_rm_mkdir('seq_dump_loc'),
        $self->pipeline_create_commands_lfs_setstripe('seq_dump_loc'),
           ];  
}

sub resource_classes {
    my ($self) = @_; 
    return {
	%{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
	'default'  => {'LSF' => '-C0 -M2500 -R"select[mem>2500] rusage[mem=2500]"' }, # farm3 lsf syntax
	'mem3500'  => {'LSF' => '-C0 -M3500 -R"select[mem>3500] rusage[mem=3500]"' },
	'mem7500'  => {'LSF' => '-C0 -M7500 -R"select[mem>7500] rusage[mem=7500]"' },
    'mem14000' => {'LSF' => '-C0 -M14000 -R"select[mem>14000] rusage[mem=14000]"' },

    };  
}

sub pipeline_wide_parameters {
	my $self = shift @_;
	return {
		%{$self->SUPER::pipeline_wide_parameters},

		'anchors_mlss_id' => $self->o('anchors_mlss_id'),
		'mapping_method_link_id' => $self->o('mapping_method_link_id'),
        	'mapping_method_link_name' => $self->o('mapping_method_link_name'),
        	'mapping_mlssid' => $self->o('mapping_mlssid'),
		'trimmed_mapping_mlssid' => $self->o('trimmed_mapping_mlssid'),
		'seq_dump_loc' => $self->o('seq_dump_loc'),
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
