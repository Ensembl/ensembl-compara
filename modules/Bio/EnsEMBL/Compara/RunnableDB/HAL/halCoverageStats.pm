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


=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::HAL::halCoverageStats

=head1 DESCRIPTION

This Runnable calculates the pairwise coverage of the given species in the given hal alignment file.

The coverage stats for each HAL genome are stored in the corresponding node of the species tree.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HAL::halCoverageStats;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Utils qw(destringify);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
#        'halStats_exe' => '/nfs/software/ensembl/RHEL7-JUL2017-core2/linuxbrew/bin/halStats',
#        'mlss_id' => 835, #mouse strain MSA mlss id
#        'genome_db_id'  => 134,
#        'temp_hal_species_name' => 'simHuman_chr6', #C57B6J',
#        'compara_db' => 'mysql://ensadmin:'.$ENV{ENSADMIN_PSW}.'@mysql-ens-compara-prod-1.ebi.ac.uk:4485/ensembl_compara_93',
#        'temp_hal_path'  => '/homes/waakanni/cactus_linuxbrew/cactus/example_SM_local/result.hal',
#        'species_name_mapping' => '{134 => \'C57B6J\', 155 => \'rn6\',160 => \'129S1_SvImJ\',161 => \'A_J\',162 => \'BALB_cJ\',163 => \'C3H_HeJ\',164 => \'C57BL_6NJ\',165 => \'CAST_EiJ\',166 => \'CBA_J\',167 => \'DBA_2J\',168 => \'FVB_NJ\',169 => \'LP_J\',170 => \'NOD_ShiLtJ\',171 => \'NZO_HlLtJ\',172 => \'PWK_PhJ\',173 => \'WSB_EiJ\',174 => \'SPRET_EiJ\', 178 => \'AKR_J\'}',
    }
}

sub fetch_input {
    my $self = shift;
    unless ( $self->param('halStats_exe')) {
    	die "Please provide the path to hal stat executable";
    }
    my $mlss_adap = $self->compara_dba()->get_MethodLinkSpeciesSetAdaptor;
    print $self->param('halStats_exe'), "\n\n" if ( $self->debug >3 );
    my $mlss = $mlss_adap->fetch_by_dbID( $self->param_required('mlss_id') );
    my $hal_path = $mlss->url;
    print "this is the hal_path : $hal_path\n\n" if ( $self->debug >3 );
    unless ($hal_path) {
    	die "the path to the hal file is missing \n";
    }

    my %species_map = %{destringify($mlss->get_value_for_tag('HAL_mapping', '{}'))};

    my $species_tree = $mlss->species_tree();
    my $species_tree_root = $species_tree->root();
    my $node = $species_tree_root->find_leaves_by_field('genome_db_id', $self->param('genome_db_id') )->[0];
    print "this is the node id : ", $node->node_id, "\n\n" if ( $self->debug >3 );
    $self->param('node', $node);
    $self->param('hal_path', $hal_path);
    $self->param('species_map', \%species_map);
}

sub run {
    my $self = shift;
    my $cmd = [$self->require_executable('halStats_exe'), '--coverage', $self->param('species_map')->{$self->param('genome_db_id')}, $self->param('hal_path')];
    my @halCov = $self->get_command_output($cmd);
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
        unless ($rSpecies_map{$genome} == $self->param('genome_db_id')) {  
            my $tag = "genome_coverage_$rSpecies_map{$genome}";
            print "this is the genome : ", $genome ," this is the coverage : ", $self->param('halCov_hash')->{$genome}, " this is the tag : \n", $tag, "\n" if ( $self->debug >3 );
            $self->param('node')->store_tag($tag, $self->param('halCov_hash')->{$genome} );
        }
        else {
            my $tag = "total_genome_length";
            print "the genome is the same as the query genome : ", $genome ," this is total genome length  : ", $self->param('halCov_hash')->{$genome}, " this is the tag : \n", $tag, "\n" if ( $self->debug >3 );
            $self->param('node')->store_tag($tag, $self->param('halCov_hash')->{$genome} );
        }
    }
}


1;
