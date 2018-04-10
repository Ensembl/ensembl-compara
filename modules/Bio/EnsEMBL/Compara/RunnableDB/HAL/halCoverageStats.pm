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


=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::HAL::halCoverageStats

=head1 DESCRIPTION

This Runnable takes 3 inputs a genome_db_id, the hal_species_name, the hal alignment file. it uses the HalXs code to calculate the pairwise coverage of the given species in the given hal alignment file 

The coverages are stored in an accu neme


=cut

package Bio::EnsEMBL::Compara::RunnableDB::HAL::halCoverageStats;

use strict;
use warnings;
use Data::Dumper;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
#        'halStats_exe' => '/nfs/software/ensembl/RHEL7-JUL2017-core2/linuxbrew/bin/halStats',
#        'mlss_id' => 835, #mouse strain MSA mlss id
#        'genome_db_id'  => 134,
#        'temp_hal_species_name' => 'simHuman_chr6', #C57B6J',
#        'compara_db' => 'mysql://ensadmin:ensembl@mysql-ens-compara-prod-1.ebi.ac.uk:4485/ensembl_compara_92',
#        'temp_hal_path'  => '/homes/waakanni/cactus_linuxbrew/cactus/example_SM_local/result.hal',
#        'species_name_mapping' => {134 => 'C57B6J', 155 => 'rn6',160 => '129S1_SvImJ',161 => 'A_J',162 => 'BALB_cJ',163 => 'C3H_HeJ',164 => 'C57BL_6NJ',165 => 'CAST_EiJ',166 => 'CBA_J',167 => 'DBA_2J',168 => 'FVB_NJ',169 => 'LP_J',170 => 'NOD_ShiLtJ',171 => 'NZO_HlLtJ',172 => 'PWK_PhJ',173 => 'WSB_EiJ',174 => 'SPRET_EiJ', 178 => 'AKR_J'},
#        'temp_result' => 'SPRET_EiJ, 2.62559e+09, 1.52198e+08, 5.94547e+07, 3.6716e+07, 2.54746e+07, 1.92152e+07, 1.48778e+07, 1.17484e+07, 9.18044e+06, 7.23219e+06, 5.58522e+06, 4.42185e+06, 3.53558e+06, 2.6432e+06, 1.98818e+06, 1.53266e+06, 1.16407e+06, 896452, 664648, 507556, 387216, 292926, 226926, 183318, 146694, 114219, 60113, 24716, 17940, 15388, 15358, 15358, 15358, 15358, 15358, 15358, 14782, 11970, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
#PWK_PhJ, 2.19534e+09, 1.16353e+08, 4.64335e+07, 2.67608e+07, 1.76145e+07, 1.25068e+07, 9.17194e+06, 6.94272e+06, 5.33394e+06, 4.10546e+06, 3.1337e+06, 2.38886e+06, 1.81903e+06, 1.43116e+06, 1.10114e+06, 861595, 661274, 503823, 400408, 301218, 225621, 166353, 129202, 107700, 84265, 55362, 37482, 33757, 27417, 15633, 2595, 110, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
#CAST_EiJ, 2.17478e+09, 1.17693e+08, 4.56922e+07, 2.61382e+07, 1.74241e+07, 1.25128e+07, 9.39102e+06, 7.28251e+06, 5.77229e+06, 4.57332e+06, 3.71026e+06, 2.94423e+06, 2.34679e+06, 1.85937e+06, 1.46639e+06, 1.16366e+06, 947092, 725547, 546963, 446995, 317355, 239798, 167689, 124229, 79045, 53804, 37526, 25525, 17177, 11980, 3284, 443, 153, 153, 153, 153, 33, 33, 33, 33, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
#WSB_EiJ, 2.1651e+09, 1.14367e+08, 4.35032e+07, 2.44382e+07, 1.56944e+07, 1.10703e+07, 8.24852e+06, 6.37224e+06, 4.9571e+06, 3.88533e+06, 3.08129e+06, 2.49595e+06, 2.00265e+06, 1.56984e+06, 1.22882e+06, 969119, 773911, 597577, 456193, 368169, 256445, 177919, 118682, 77873, 46227, 31516, 25952, 24831, 21409, 17923, 12214, 4631, 1733, 536, 124, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
#NZO_HlLtJ, 2.16602e+09, 1.21247e+08, 4.62465e+07, 2.63859e+07, 1.74553e+07, 1.2577e+07, 9.51539e+06, 7.46826e+06, 5.92602e+06, 4.6857e+06, 3.80331e+06, 3.01708e+06, 2.44639e+06, 1.9881e+06, 1.5437e+06, 1.21756e+06, 982517, 794616, 611090, 476296, 367290, 288459, 214162, 162080, 125111, 100839, 78128, 63006, 53956, 48337, 40200, 29523, 26123, 23425, 21920, 19811, 17483, 15747, 13122, 11482, 9809, 7042, 5062, 2837, 839, 38, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
#C57BL_6NJ, 2.16232e+09, 1.16799e+08, 4.48184e+07, 2.54816e+07, 1.65802e+07, 1.18953e+07, 8.93708e+06, 6.97065e+06, 5.33583e+06, 4.1628e+06, 3.25985e+06, 2.58111e+06, 2.04001e+06, 1.59706e+06, 1.23212e+06, 958036, 737739, 576080, 439208, 349346, 257308, 190364, 131128, 93982, 67537, 48533, 42549, 34950, 30843, 28844, 26452, 24478, 22765, 20496, 19362, 18254, 16804, 14916, 11321, 8053, 6783, 5019, 3761, 1879, 95, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
#C57B6J, 2.16728e+09, 1.17393e+08, 4.70947e+07, 2.72243e+07, 1.83135e+07, 1.34903e+07, 1.02459e+07, 8.06812e+06, 6.4349e+06, 5.10371e+06, 4.13168e+06, 3.28795e+06, 2.59164e+06, 2.02366e+06, 1.5549e+06, 1.20232e+06, 1.01397e+06, 838292, 660382, 542099, 415181, 329008, 253412, 200983, 164414, 134016, 120982, 97685, 89205, 83267, 76184, 61784, 49024, 43339, 38959, 33435, 32878, 28910, 21678, 10657, 6809, 4856, 1939, 1913, 1902, 1860, 522, 522, 522, 433, 371, 358, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0',
    }
}

sub fetch_input {
    my $self = shift;
    my %species_map = %{ eval $self->param('species_name_mapping') };
    unless ( $self->param('halStats_exe')) {
    	die "Please provide the hal stat command";
    }
    my $mlss_adap = $self->compara_dba()->get_MethodLinkSpeciesSetAdaptor;
    print $self->param('halStats_exe'), "\n\n" if ( $self->debug >3 );
    my $mlss = $mlss_adap->fetch_by_dbID( $self->param_required('mlss_id') );
    my $hal_path = $mlss->url;
    print "this is the hal_path : $hal_path\n\n" if ( $self->debug >3 );
    unless ($hal_path) {
    	die "the path to the hal file is missing \n";
    }

    my $species_tree = $mlss->species_tree();
    my $species_tree_root = $species_tree->root();
    my $node = $species_tree_root->find_leaves_by_field('genome_db_id', $self->param('genome_db_id') )->[0];
    my $stn_adap = $self->compara_dba()->get_SpeciesTreeNodeAdaptor;
    my $stn = $stn_adap->fetch_node_by_node_id($node->node_id);
    print "this is the node id : ", $node->node_id, "\n This is the species tree node id : ", $stn->dbID , "\n" if ( $self->debug >3 );
    $self->param('node', $stn);
    $self->param('hal_path', $hal_path);
    $self->param('species_map', \%species_map);
}

sub run {
    my $self = shift;
    my $cmd = $self->run_command([$self->require_executable('halStats_exe'), '--coverage', $self->param('species_map')->{$self->param('genome_db_id')}, $self->param('hal_path')], {die_on_failure => 1});
    #parse the result to extract the columns 'Genome' and  'sitesCovered1Times'
    my @halCov = split /\n/, $cmd->out;
    my %halCov_hash;
    foreach my $line (@halCov){
        my @split_line = split /,/, $line;
        if ($split_line[0] eq 'Genome'){
            next;
        }
        else {
            $split_line[0] =~ s/^\s+|\s+$//g ; #trim remove white space from both ends of a string:
            $split_line[1] =~ s/^\s+|\s+$//g ;
            $halCov_hash{$split_line[0]} = $split_line[1];
        }
    }
    $self->param('halCov_hash', \%halCov_hash);    
}

sub write_output {
    my $self = shift;

    my %rSpecies_map = reverse %{$self->param_required('species_map')};
#    print Dumper(%rSpecies_name_mapping);
    foreach my $genome (keys %{$self->param('halCov_hash')} ) {
        my $tag = "genomes_coverage_$rSpecies_map{$genome}";

        print "this is the genome : ", $genome ," this is the coverage : ", $self->param('halCov_hash')->{$genome}, " this is the tag : \n", $tag, "\n" if ( $self->debug >3 );
        $self->param('node')->store_tag($tag, $self->param('halCov_hash')->{$genome} );

    }
}


1;
