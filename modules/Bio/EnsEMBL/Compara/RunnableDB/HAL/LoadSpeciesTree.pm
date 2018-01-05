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

Bio::EnsEMBL::Compara::RunnableDB::HAL::LoadSpeciesTree

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HAL::LoadSpeciesTree;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Utils::SpeciesTree;

use base ('Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree');


sub fetch_input {
    my $self = shift;

    my $gdb_adap = $self->compara_dba->get_GenomeDBAdaptor;
    my $mlss_adap = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $mlss = $mlss_adap->fetch_by_dbID( $self->param_required('mlss_id') );
    
    my $hal_path = $mlss->url;
    my %species_map = %{ eval $mlss->get_tagvalue('HAL_mapping') };

    die "Path to HAL file missing from  MLSS (id " . $self->param('mlss_id') . ") url field\n" unless (defined $hal_path);
    die "Species name mapping missing from method_link_species_set_tag\n" unless (%species_map);
    die "$hal_path does not exist" unless ( -e $hal_path );

    my $cmd = $self->run_command([$self->require_executable('halStats_exe'), '--tree', $hal_path], {die_on_failure => 1});
    my $newick_tree = $cmd->out;
    foreach my $gdb_id ( keys %species_map ) {
        my $hal_species = $species_map{$gdb_id};
        my $gdb = $gdb_adap->fetch_by_dbID($gdb_id);
        my $ens_species = $gdb->name;
        $newick_tree =~ s/$hal_species/$ens_species/g;
    }

    my $species_tree_root  = Bio::EnsEMBL::Compara::Utils::SpeciesTree->new_from_newick($newick_tree, $self->compara_dba);
    
    $self->param('species_tree_root', $species_tree_root);
}


1;
