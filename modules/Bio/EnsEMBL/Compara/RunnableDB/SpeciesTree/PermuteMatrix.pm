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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::PermuteMatrix

=head1 SYNOPSIS

Given mash dist output, parse the matrix and flow out permuted submatrices.
These submatrices are composed of:
- taxonomic groups (eg. primates, rodents)
- stepping up the taxonomy, create groups with more diverse species, but collapsing subclades which already have a tree

=head1 DESCRIPTION
 

=cut

package Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::PermuteMatrix;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::Compara::Utils::DistanceMatrix;

use File::Basename;

use Data::Dumper;
$Data::Dumper::Maxdepth = 2;

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'min_group_size'  => 4,
        'taxonomic_ranks' => ['order', 'class', 'phylum', 'kingdom'],
        # 'custom_groups'   => ['Vertebrata', 'Sauropsida', 'Amniota', 'Tetrapoda'],
        # 'outgroup_id' => '127', # outgroup for everything

        # blacklisting certain unreliable genome_dbs will result in:
        # 1. exemption from being outgroups as they are not high quality enough
        # 2. exemption from collapsed groups - their distance will not be included in the average
        'blacklisted_genome_db_ids' => [49, 108], # hedgehog, rabbit
    };
}

sub fetch_input {
	my $self = shift;

	my $gdb_adaptor = $self->compara_dba->get_GenomeDBAdaptor;
	my $ncbi_adaptor = $self->compara_dba->get_NCBITaxonAdaptor;
	
	# parse matrix and replace filenames with genome_db_ids
	my $mash_dist_file = $self->param_required('mash_dist_file');
	print "\n -- Generating matrix from $mash_dist_file\n" if $self->debug; 
	my $distance_matrix = Bio::EnsEMBL::Compara::Utils::DistanceMatrix->new(
		-file => $mash_dist_file
	);
	$distance_matrix = $distance_matrix->convert_to_genome_db_ids($gdb_adaptor);
	$distance_matrix = $distance_matrix->add_taxonomic_distance($gdb_adaptor);
	
	my @gdb_ids = $distance_matrix->members;
	# print " -- matrix genomes: " . join(", ", @gdb_ids) . "\n";
	my @gdbs = map { $gdb_adaptor->fetch_by_dbID($_) } @gdb_ids;

	# generate submatrices
	print " -- Detecting optimal taxonomic groupings\n" if $self->debug;
	my @tax_groups_ids = $self->_taxonomic_groups(\@gdbs);

	my (@prev_group_ids, %all_groups, @matrices_dataflow, $this_outgroup);
	foreach my $group_taxon_id ( @tax_groups_ids ) {
		my $current_group_taxon = $ncbi_adaptor->fetch_node_by_taxon_id($group_taxon_id);
		print " -- Grouping " . $current_group_taxon->name . "...\n" if $self->debug if $self->debug;

		# extract initial submatrix for the group
		my @group_gdbs = @{$gdb_adaptor->fetch_all_current_by_ancestral_taxon_id($group_taxon_id)};
		print "\t -- fetching submatrix for " . scalar @group_gdbs . " genomes\n" if $self->debug;
		my $submatrix = $distance_matrix->prune_gdbs_from_matrix( \@group_gdbs );

		# add an outgroup
		if ( $group_taxon_id == $ncbi_adaptor->fetch_node_by_name('root')->dbID ) {
			$this_outgroup = $self->param_required('outgroup_id');
		} else {
			($submatrix, $this_outgroup) = $self->_add_outgroup( $submatrix, $distance_matrix );
		}
		print "\t -- " . $gdb_adaptor->fetch_by_dbID($this_outgroup)->name . " selected as outgroup\n" if $self->debug;

		# collapse any previous groups
		foreach my $prev_group ( @prev_group_ids ) {
			my $prev_group_taxon = $ncbi_adaptor->fetch_node_by_taxon_id($prev_group);
			next unless $prev_group_taxon->has_ancestor($current_group_taxon);
			print "\t -- " . $prev_group_taxon->name . " is a member of this group - collapsing it\n" if $self->debug;
			my $prev_group_gdbs = $gdb_adaptor->fetch_all_current_by_ancestral_taxon_id($prev_group);
			$submatrix = $submatrix->collapse_group_in_matrix( $prev_group_gdbs, "mrg_$prev_group" );
		}

		# add to dataflow
		my $mdf = { 
			group_key => $group_taxon_id, 
			distance_matrix => $submatrix, 
			outgroup => $this_outgroup 
		};
		push( @matrices_dataflow, $mdf );
		unshift( @prev_group_ids, $group_taxon_id );
	}	

	$self->param('matrices_dataflow', \@matrices_dataflow );
	$self->param('distance_matrix',    $distance_matrix );
}

sub write_output {
	my $self = shift;

	# example dataflow
	# matrices_dataflow = [
	#     { group_key => $key1, distance_matrix => $matrix1, outgroup => $this_outgroup },
	#     { group_key => $key2, distance_matrix => $matrix2 }, # no outgroup
	# ]
	$self->dataflow_output_id( $self->param('matrices_dataflow'), 2 );
}

sub _add_outgroup {
	my ( $self, $submatrix, $full_matrix ) = @_;

	my @sub_gdb_ids = $submatrix->members;
	my $rep_gdb_id  = $sub_gdb_ids[0];

	my ( $closest_gdb_id, $min_distance) = (undef, 100);
	foreach my $full_key ( $full_matrix->members ) {
		next if ( defined $self->param('blacklisted_genome_db_ids') && grep { $full_key eq $_ } @{$self->param('blacklisted_genome_db_ids')} ); # skip any that are on the naughty list
		next if (grep { $_ eq $full_key } @sub_gdb_ids); # skip any that exist in the submatrix

		if ( $full_matrix->distance($rep_gdb_id, $full_key) < $min_distance ) {
			$closest_gdb_id = $full_key;
			$min_distance = $full_matrix->distance($rep_gdb_id, $full_key);
		}
	} 

	unless ($closest_gdb_id) {
		print "Can't find a suitable outgroup\n";
		return $submatrix;
	}

	foreach my $sub_key ( $submatrix->members ) {
		$submatrix = $submatrix->distance($sub_key, $closest_gdb_id, $full_matrix->distance($sub_key, $closest_gdb_id));
	}

	return ($submatrix, $closest_gdb_id);
}

sub _taxonomic_rank {
	my ( $self, $taxon, $rank ) = @_;

	my $original_taxon = $taxon;

	# first, check for exact rank matches
	while ( defined $taxon && $taxon->name ne 'root' ) {
		return $taxon->dbID if ($taxon->rank eq $rank);
		$taxon = $taxon->parent;
	}

	# if exact match is not found, use fuzzy-ish match
	$taxon = $original_taxon;
	unless ( $taxon->rank eq $rank ) {
		foreach my $prefix ( "super", "sub" ) { # fix this order for more consistency in results during testing
			while ( defined $taxon && $taxon->name ne 'root' ) {
				return $taxon->dbID if ($taxon->rank eq "$prefix$rank");
				$taxon = $taxon->parent;
			}
		}
	}

	$self->warning("Cannot find $rank (or super/sub-$rank) for " . $original_taxon->name . "\n");
	return 0;
}

sub _taxonomic_groups {
	my ($self, $gdbs) = @_;

	my $gdb_adaptor = $self->compara_dba->get_GenomeDBAdaptor;
	my $ncbi_adaptor = $self->compara_dba->get_NCBITaxonAdaptor;
	my %group_taxon_ids;

	# first, grab all the ranks for each genome_db
	my @ranks = @{ $self->param_required('taxonomic_ranks') };
	foreach my $gdb ( @$gdbs ) {
		my $this_gdb_taxon = $ncbi_adaptor->fetch_node_by_taxon_id($gdb->taxon_id);
		foreach my $rank ( @ranks ) {
			my $this_rank_taxon = $self->_taxonomic_rank($this_gdb_taxon, $rank);
			$group_taxon_ids{$this_rank_taxon} = 1 if $this_rank_taxon;
		}
	}

	# now, add in the additional groupings, if any
	if ( $self->param('custom_groups') ) {
		my @custom_groups = @{ $self->param('custom_groups') };
		foreach my $custom_group ( @custom_groups ) {
			my $custom_taxon = $ncbi_adaptor->fetch_node_by_name($custom_group);
			die "Cannot find taxon_id for group '$custom_group'\n" unless $custom_taxon;
			$group_taxon_ids{$custom_taxon->dbID} = 1;
		}
	}

	# order them from smallest to largest
	my @group_taxa  = map  { $ncbi_adaptor->fetch_node_by_taxon_id($_) } keys %group_taxon_ids;
	my %group_counts = map { $_->dbID => scalar(@{$gdb_adaptor->fetch_all_current_by_ancestral_taxon_id($_->dbID)}) } @group_taxa;
	my @sorted_taxa = sort { $group_counts{$a->dbID} <=> $group_counts{$b->dbID} } grep { $group_counts{$_->dbID} > $self->param_required('min_group_size') } @group_taxa;
	my @sorted_taxon_ids = map {$_->dbID} @sorted_taxa;

	# finally, add the root
	my $root_taxon = $ncbi_adaptor->fetch_node_by_name('root');
	push(@sorted_taxon_ids, $root_taxon->dbID); # usually 1, but fetch from db just incase

	return @sorted_taxon_ids;
}

1;
