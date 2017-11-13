=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::GroupSpecies

=head1 SYNOPSIS

Splits species into groups, depending on the NCBI taxonomy

=head1 DESCRIPTION
 

=cut

package Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::GroupSpecies;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');
use Data::Dumper;

$Data::Dumper::Maxdepth = 3;

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'min_group_size'              => 5,

        # when using group_on_taxonomy, guide trees are generated to stitch the groups back together
        'species_per_group_per_guide' => 4, # how many species from each group should be included?
        'num_guide_trees'             => 10, # how many guide trees to generate
    };
}

sub fetch_input {
	my $self = shift;

	# $self->debug(5);

	my $collection = $self->param('collection');
	my $species_set_id = $self->param('species_set_id');

	die "Need either collection or species_set_id to be defined!" unless ( $collection || $species_set_id );

	my $dba = $self->compara_dba;
	my $gdb_adaptor = $dba->get_GenomeDBAdaptor;
	my $ss_adaptor = $dba->get_SpeciesSetAdaptor;
	
	my $species_set;
	if ( $collection ) {
		$species_set = $ss_adaptor->fetch_collection_by_name($collection);
	} elsif ( $species_set_id ) {
		$species_set = $ss_adaptor->fetch_by_dbID($species_set_id);
		$self->param('collection', $species_set->name); # set this for file naming later
	}
	my @genome_dbs = @{ $species_set->genome_dbs };

	# _print_gdb_list(\@genome_dbs, 'before exclusion of species');

	if ( $self->param('exclude_species') ) {
		foreach my $excl_species_name ( @{ $self->param('exclude_species') } ) {
			@genome_dbs = grep { $_->name ne $excl_species_name } @genome_dbs;
		}
	}

	# _print_gdb_list(\@genome_dbs, 'after exclusion of species');

	if ( $self->param('group_on_taxonomy') ){
		$self->param( 'dataflow_groups', $self->group_on_taxonomy( \@genome_dbs ) );
	} else {
		my @gdb_id_list = map { $_->dbID } @genome_dbs;
		push( @gdb_id_list, @{ $self->param('outgroup_gdbs') } ) if $self->param('outgroup_gdbs');
		@gdb_id_list = sort {$a <=> $b} @gdb_id_list; 
		$self->param( 'dataflow_groups', [{ genome_db_ids => \@gdb_id_list, collection => $self->param('collection')}] );
	}
}

sub _print_gdb_list {
	my ($gdbs, $tag) = @_;

	print "\n\n------- $tag -------\n";
	foreach my $g ( @$gdbs ) {
		print "\t- " . $g->name . " (" . $g->dbID . ")\n";
	}
}

sub group_on_taxonomy {
	my ($self, $gdbs) = @_;

	my $dba = $self->compara_dba;
	my $ncbi_adaptor = $dba->get_NCBITaxonAdaptor;

	my %taxonomic_groups;
	foreach my $gdb ( @$gdbs ) {
		my $taxon = $ncbi_adaptor->fetch_node_by_taxon_id($gdb->taxon_id);
		push( @{ $taxonomic_groups{$self->_taxonomic_order($taxon)} }, $gdb );
	}

	# check group sizes and merge small groups together
	my %merged_tax_groups = %{ $self->_merge_with_closest_relative( \%taxonomic_groups ) };
	
	# assign group representatives
	# my $group_reps = $self->_group_representatives( \%merged_tax_groups );
	
	# if ($self->debug) {
	# 	print "group representatives:\n";
	# 	foreach my $gid ( keys %$group_reps ) {
	# 		print "\t$gid : " . $group_reps->{$gid}->name . "(" . $group_reps->{$gid}->dbID . ")\n";
	# 	}
	# 	print "\n";
	# }


	# prepare groups for dataflow
	my @dataflow_groups;
	foreach my $group_id ( %merged_tax_groups ) {
		# grab all members of the group
		my @this_group_gdb_ids = map {$_->dbID} @{ $merged_tax_groups{$group_id} };
		next unless $this_group_gdb_ids[0]; # for some reason, empty groups are sneaking in - skip em

		# # add a representative species from each other group
		# foreach my $rep_group_id ( keys %$group_reps ) {
		# 	next if $rep_group_id == $group_id;
		# 	push( @this_group_gdb_ids, $group_reps->{$rep_group_id}->dbID );
		# }

		# add any user-defined outgroups
		# push( @this_group_gdb_ids, @{ $self->param('outgroup_gdbs') } ) if $self->param('outgroup_gdbs');

		@this_group_gdb_ids = sort {$a <=> $b} @this_group_gdb_ids;
		my $this_collection_name = $self->param('collection') . ".taxon_id_$group_id";
		push( @dataflow_groups, { genome_db_ids => \@this_group_gdb_ids, collection => $this_collection_name });
	}

	@dataflow_groups = sort {$a->{genome_db_ids}->[0] <=> $b->{genome_db_ids}->[0]} @dataflow_groups;

	# once species are in their groups, create additional groups with a selection of members
	# from each group for use when recombining the trees
	push( @dataflow_groups, @{ $self->_generate_guide_groups(\@dataflow_groups) } );

	return \@dataflow_groups;
}

sub _generate_guide_groups { 
	my ( $self, $groups ) = @_;

	my $num_guide_trees = $self->param('num_guide_trees');
	my $sp_per_group = $self->param('species_per_group_per_guide');
	# my @representative_species = @{ $self->param('representative_species') } if $self->param('representative_species');

	my @all_guide_groups;
	for ( my $i = 0; $i < $num_guide_trees; $i++ ) {
		my @this_guide_group;
		foreach my $g ( @$groups ) {
			# if ( grep { $_ } @$g )
			push( @this_guide_group, @{ $self->_select_random_gdb_ids($g, $sp_per_group) } );
		}
		push( @this_guide_group, @{ $self->param('outgroup_gdbs') } ) if $self->param('outgroup_gdbs');
		push( @all_guide_groups, { genome_db_ids => \@this_guide_group, collection => $self->param('collection') . ".guide_$i" } );
	}

	return \@all_guide_groups;
}

sub _select_random_gdb_ids {
	my ( $self, $g, $how_many ) = @_;

	my @group = @{$g->{genome_db_ids}};
	my @random_members;
	for ( my $i = 0; $i < $how_many; $i++ ) {
		my $randomelement = $group[rand @group];
		if ( grep { $_ == $randomelement } @random_members ) {
			$i--;
			next;
		} else {
			push( @random_members, $randomelement );
		}
	}

	return \@random_members;
}

sub _taxonomic_order {
	my ( $self, $taxon ) = @_;

	my $original_taxon = $taxon;

	while ( $taxon->rank ne 'order' && $taxon->rank ne 'superorder' ) {
		$taxon = $taxon->parent;
	}

	return $taxon->dbID;
}

sub _merge_with_closest_relative {
	my ( $self, $taxon_groups ) = @_;

	$self->print_groups($taxon_groups, 'pre-merging') if $self->debug > 2;

	my $dba = $self->compara_dba;
	my $ncbi_adaptor = $dba->get_NCBITaxonAdaptor;

	my $smallest_group_id = $self->_smallest_group_id($taxon_groups);
	my $c = 0;
	while ( scalar @{$taxon_groups->{$smallest_group_id}} < $self->param('min_group_size') ) {
		print "\n--- smallest group id: $smallest_group_id\n" if $self->debug > 2;
		my $small_group_taxon = $ncbi_adaptor->fetch_by_dbID($smallest_group_id);

		my $min_dist = 100;
		my $merge_id;
		foreach my $other_group_id ( keys %$taxon_groups ) {
			next if ( $smallest_group_id == $other_group_id );
			my $other_group_taxon = $ncbi_adaptor->fetch_by_dbID( $other_group_id );
			if ( $small_group_taxon->distance_to_node($other_group_taxon) < $min_dist ) {
				$min_dist = $small_group_taxon->distance_to_node($other_group_taxon);
				$merge_id = $other_group_id;
			}
		}

		print " --- merging $smallest_group_id into $merge_id\n" if $self->debug > 2;
		$taxon_groups = $self->_merge_groups( $taxon_groups, $smallest_group_id, $merge_id );

		$smallest_group_id = $self->_smallest_group_id($taxon_groups);
		$self->print_groups($taxon_groups, "merge_loop_$c") if $self->debug > 2;
		$c++;
	}

	return $taxon_groups;
}

sub _merge_groups {
	my ( $self, $group_ref, $merge_id1, $merge_id2 ) = @_;

	my %groups = %$group_ref;
	push( @{ $groups{$merge_id2} }, @{ $groups{$merge_id1} } );
	delete $groups{$merge_id1};
	return \%groups;
}

sub _smallest_group_id {
	my ( $self, $groups ) = @_;

	my $min_size = 1000;
	my $smallest_group_id;

	foreach my $id ( keys %$groups ) {
		if ( scalar @{$groups->{$id}} < $min_size ) {
			$min_size = scalar @{$groups->{$id}};
			$smallest_group_id = $id;
		}
	}

	return $smallest_group_id;
}

sub _group_representatives {
	my ($self, $groups) = @_;

	my %reps;

	# import user defined representatives
	my $ud_reps = $self->param('representative_species');
	if ( $ud_reps ) {
		my $gdb_adaptor = $self->compara_dba->get_GenomeDBAdaptor;

		foreach my $species_name ( @$ud_reps ) {
			my $this_gdb = $gdb_adaptor->fetch_by_name_assembly( $species_name );
			die "Cannot find genome_db for representative species: $species_name\n" unless $this_gdb;
			my $group_id_for_gdb = $self->_group_id_for_gdb( $groups, $this_gdb );
			$reps{$group_id_for_gdb} = $this_gdb if $group_id_for_gdb;
		}
	}

	# pick a member as rep if none has been user-defined
	# largest genome_db_id is chosen as default here as random is bad for testing
	foreach my $group_id ( keys %$groups ) {
		next if $reps{$group_id};
		my @sorted_gdbs = sort {$b->dbID <=> $a->dbID} @{ $groups->{$group_id} };
		$reps{$group_id} = $sorted_gdbs[0];
	}

	return \%reps;
}

sub _group_id_for_gdb {
	my ( $self, $groups, $gdb ) = @_;

	foreach my $gid ( keys %$groups ) {
		return $gid if ( grep { $_->dbID == $gdb->dbID } @{ $groups->{$gid} } );
	}
	return 0;
}

sub print_groups {
	my ( $self, $groups, $tag ) = @_;
	$tag ||= '';

	print "\n\n============ printing groups $tag ==============\n";
	foreach my $k ( keys %$groups ) {
		print "$k => [\n\t";
		print join(", ", map {$_->name . '(' . $_->dbID . ')'} @{ $groups->{$k} });
		print "\n],\n";
	}
	print "=================================================\n";
}

sub write_output {
	my $self = shift;

	my @groups = @{ $self->param_required('dataflow_groups') };
	my $collection = $self->param_required('collection');

	my $num_groups = scalar @groups;
	my $c = 1;
	foreach my $group_set ( @groups ) {
		print "* " . $group_set->{'collection'} . " : " . join(",", @{$group_set->{'genome_db_ids'}}) . "\n" if $self->debug;
		$self->dataflow_output_id( $group_set, 1 );
		$c++;
	}
}

1;