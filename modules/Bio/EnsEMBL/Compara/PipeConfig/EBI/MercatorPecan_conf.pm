=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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


=pod 

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::EBI::MercatorPecan_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::MercatorPecan_conf -password <your_password> -mlss_id <your_current_Pecan_mlss_id>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output


=head1 DESCRIPTION  

    The PipeConfig file for MercatorPecan pipeline that should automate most of the pre-execution tasks.

    FYI: it took (3.7 x 24h) to perform the full production run for EnsEMBL release 62.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::MercatorPecan_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use base ('Bio::EnsEMBL::Compara::PipeConfig::MercatorPecan_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones


    # parameters that are likely to change from execution to another:
	#pecan mlss_id
#       'mlss_id'               => 522,   # it is very important to check that this value is current (commented out to make it obligatory to specify)
        'work_dir'              => '/hps/nobackup2/production/ensembl/' . $ENV{USER} . '/' . $self->o('pipeline_name'),
        'species_set_name'      => 'amniotes',
        'division'              => 'ensembl',
        'do_not_reuse_list'     => [ ],

    #location of full species tree, will be pruned
        'species_tree_file'     => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/species_tree.'.$self->o('division').'.branch_len.nw',

    # place to get the genome dumps
    'genome_dumps_dir' => '/hps/nobackup2/production/ensembl/compara_ensembl/genome_dumps/'.$self->o('division').'/',
    'reg_conf'  => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/production_reg_'.$self->o('division').'_conf.pl',

    # master database
    'master_db' => 'compara_master',
    # previous release data location for reuse
    'reuse_db'  => 'compara_prev',
    'paf_reuse_db' => 'amniotes_pecan_prev', # peptide_align_feature% tables only available here

    #Pecan default parameters
    'java_options'      => '-server -Xmx1000M',
    'java_options_mem1' => '-server -Xmx3500M -Xms3000m',
    'java_options_mem2' => '-server -Xmx6500M -Xms6000m',
    'java_options_mem3' => '-server -Xmx21500M -Xms21000m',

    'gerp_version'      => 2.1,
	    

    #Location of executables (or paths to executables)
    'gerp_exe_dir'              => $self->check_dir_in_cellar('gerp/20080211_1/bin'),
    'mercator_exe'              => $self->check_exe_in_cellar('cndsrc/2013.01.11/bin/mercator'),
    'blast_bin_dir'             => $self->check_dir_in_cellar('blast/2.2.30/bin'),
    'exonerate_exe'             => $self->check_exe_in_cellar('exonerate22/2.2.0/bin/exonerate'),
    'java_exe'                  => $self->check_exe_in_linuxbrew_opt('jdk@8/bin/java'),
    'estimate_tree_exe'         => $self->check_file_in_cellar('pecan/0.8.0/libexec/bp/pecan/utils/EstimateTree.py'),

    'semphy_exe'                => $self->check_exe_in_cellar('semphy/2.0b3/bin/semphy'),
    'ortheus_bin_dir'           => $self->check_dir_in_cellar('ortheus/0.5.0_1/bin'),
    'ortheus_lib_dir'           => $self->check_dir_in_cellar('ortheus/0.5.0_1'),
    'pecan_exe_dir'             => $self->check_dir_in_cellar('pecan/0.8.0/libexec'),


     # stats report email
     'epo_stats_report_email' => $ENV{'USER'} . '@ebi.ac.uk',
    };
}


sub resource_classes {
    my ($self) = @_;
    my $reg_requirement = '--reg_conf '.$self->o('reg_conf');    
    return {
         %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
         'default' => { 'LSF' => ['', $reg_requirement], 'LOCAL' => ['', $reg_requirement] },
         '100Mb'   => { 'LSF' => ['-C0 -M100   -R"select[mem>100]   rusage[mem=100]"',   $reg_requirement] },
         '1Gb'     => { 'LSF' => ['-C0 -M1000  -R"select[mem>1000]  rusage[mem=1000]"',  $reg_requirement] },
         '1.8Gb'   => { 'LSF' => ['-C0 -M1800  -R"select[mem>1800]  rusage[mem=1800]"',  $reg_requirement] },
         '3.5Gb'   => { 'LSF' => ['-C0 -M3500  -R"select[mem>3500]  rusage[mem=3500]"',  $reg_requirement] },
	     '7Gb'     => { 'LSF' => ['-C0 -M7000  -R"select[mem>7000]  rusage[mem=7000]"',  $reg_requirement] },
         '14Gb'    => { 'LSF' => ['-C0 -M14000 -R"select[mem>14000] rusage[mem=14000]"', $reg_requirement] },
         '30Gb'    => { 'LSF' => ['-C0 -M30000 -R"select[mem>30000] rusage[mem=30000]"', $reg_requirement] },
         'gerp'    => { 'LSF' => ['-C0 -M1000  -R"select[mem>1000]  rusage[mem=1000]"',  $reg_requirement] },
         'higerp'  => { 'LSF' => ['-C0 -M3800  -R"select[mem>3800]  rusage[mem=3800]"',  $reg_requirement] },
    };
}

1;

