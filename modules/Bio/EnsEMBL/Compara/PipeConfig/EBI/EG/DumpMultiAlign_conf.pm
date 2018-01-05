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

##
## Configuration file for DumpMultiAlign pipeline
package Bio::EnsEMBL::Compara::PipeConfig::EBI::EG::DumpMultiAlign_conf;

use strict;
use warnings;
use Bio::EnsEMBL::Hive::Version 2.4;
use base ('Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf');

sub default_options {
    my ($self) = @_;
    return {
	%{$self->SUPER::default_options},   # inherit the generic ones

        'staging_loc1' => {                     # general location of half of the current release core databases
            -host   => 'mysql-eg-staging-1',
            -port   => 4260,
            -user   => 'ensro',
            -pass   => '',
		    -driver => 'mysql',
		    -dbname => $self->o('ensembl_release'),
        },

        'staging_loc2' => {                     # general location of the other half of the current release core databases
            -host   => 'mysql-eg-staging-2',
            -port   => 4275,
            -user   => 'ensro',
            -pass   => '',
	        -driver => 'mysql',
	        -dbname => $self->o('ensembl_release'),
        },

        'livemirror_loc' => {                   # general location of the previous release core databases (for checking their reusability)
            -host   => 'mysql-eg-mirror.ebi.ac.uk',
            -port   => 4157,
            -user   => 'ensro',
            -driver => 'mysql',
            -dbname => $self->o('ensembl_release'),
        },

	#Location of core and, optionally, compara db
	'db_urls' => [ $self->dbconn_2_url('livemirror_loc') ],

        'split_size'    => 0,
        'format'        => 'maf',
        'make_tar_archive'  => 1,
    };
}

# Force an automatic loading of the registry in all workers.
sub beekeeper_extra_cmdline_options {
    my ($self) = @_;

	my $options = join(' ', $self->SUPER::beekeeper_extra_cmdline_options, "-reg_conf ".$self->o('registry'));
	
return $options;
}

sub resource_classes {
    my $self = shift;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
        'crowd' => { 'LSF' => '-q production-rh7 -C0 -M8000 -R"select[mem>8000] rusage[mem=8000]"' },
    }
}

sub pipeline_analyses {
    my ($self) = @_;
    # We get the analyses defined in the base class, we add a new one, and
    # we create the link between them
    my $super_analyses = $self->SUPER::pipeline_analyses;
    my ($mlss_factory) = grep {$_->{'-logic_name'} eq 'MLSSJobFactory'} @$super_analyses;
    $mlss_factory->{-flow_into} = {
        '2->A' => [ 'count_blocks' ],
        'A->1' => 'createREADME',
    };
    return [
        @$super_analyses,
        {   -logic_name     => 'createREADME',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::MafReadme',
        },
    ];
}

1;
