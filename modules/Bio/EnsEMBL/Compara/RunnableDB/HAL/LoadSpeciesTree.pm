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

Bio::EnsEMBL::Compara::RunnableDB::HAL::LoadSpeciesTree

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HAL::LoadSpeciesTree;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Utils::SpeciesTree;
use Bio::EnsEMBL::Hive::Utils qw(destringify);

use base ('Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree');


sub fetch_input {
    my $self = shift;

    my $gdb_adap = $self->compara_dba->get_GenomeDBAdaptor;
    my $mlss_adap = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $mlss = $mlss_adap->fetch_by_dbID( $self->param_required('mlss_id') );
    
    my $hal_path = $mlss->url;
    my %species_map = %{destringify($mlss->get_value_for_tag('HAL_mapping', '{}'))};

    die "Path to HAL file missing from  MLSS (id " . $self->param('mlss_id') . ") url field\n" unless (defined $hal_path);
    die "Species name mapping missing from method_link_species_set_tag\n" unless (%species_map);
    die "$hal_path does not exist" unless ( -e $hal_path );

    my $newick_tree = $self->get_command_output([$self->require_executable('halStats_exe'), '--tree', $hal_path]);
    foreach my $gdb_id ( keys %species_map ) {
        my $hal_species = $species_map{$gdb_id};
        my $gdb = $gdb_adap->fetch_by_dbID($gdb_id);
        my $ens_species = $gdb->name;
        if ( defined $gdb->genome_component ) {
            $ens_species = $ens_species . '_' . $gdb->genome_component;
        }
        $newick_tree =~ s/$hal_species/$ens_species/g;
    }

    my $species_tree_root  = Bio::EnsEMBL::Compara::Utils::SpeciesTree->new_from_newick($newick_tree, $self->compara_dba);

    if ($mlss->has_tag('genome_component')) {
        my $genome_component = $mlss->get_value_for_tag('genome_component');
        foreach my $leaf (@{$species_tree_root->get_all_leaves()}) {
            my $leaf_gdb = $gdb_adap->fetch_by_dbID($leaf->genome_db_id);
            my $comp_gdb = $gdb_adap->fetch_by_name_assembly($leaf_gdb->name, $leaf_gdb->assembly, $genome_component);
            if (defined $comp_gdb) {
                $leaf->node_name($comp_gdb->display_name);
            }
        }
    }

    $self->param('species_tree_root', $species_tree_root);
}


1;
