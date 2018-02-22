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
	my $distance_matrix = Bio::EnsEMBL::Compara::Utils::DistanceMatrix->new(
		-file => $self->param_required('mash_dist_file')
	);
	$distance_matrix = $distance_matrix->convert_to_genome_db_ids($gdb_adaptor);
	$distance_matrix = $distance_matrix->add_taxonomic_distance($gdb_adaptor);
	
	my @gdb_ids = $distance_matrix->members;
	my @gdbs = map { $gdb_adaptor->fetch_by_dbID($_) } @gdb_ids;

	# generate submatrices
	my @taxonomic_ranks = @{ $self->param_required('taxonomic_ranks') };
	my ($prev_groups, %all_groups, @matrices_dataflow);
	my %rank_groups;
	for ( my $i = 0; $i < scalar @taxonomic_ranks; $i++ ) {
		my $tax_rank = $taxonomic_ranks[$i];
		# first, get groups that form large enough clades
		my %large_groups = %{$self->group_on_taxonomy(\@gdbs, $tax_rank)};

		my @group_ids = keys %large_groups;
		$rank_groups{$tax_rank} = \@group_ids;

		my $this_outgroup;
		foreach my $group_key ( keys %large_groups ) {
			# extract initial submatrix for the group
			my $submatrix = $distance_matrix->prune_gdbs_from_matrix( $large_groups{$group_key} );

			# add an outgroup
			($submatrix, $this_outgroup) = $self->_add_outgroup($submatrix, $distance_matrix, $group_key);

			# collapse any previous groups
			foreach my $all_key ( @{ $rank_groups{ $taxonomic_ranks[$i-1] } } ) { # only merge those from previous rank
				$submatrix = $submatrix->collapse_group_in_matrix( $all_groups{$all_key}, "mrg_$all_key" );
			}

			# add to dataflow
			my $mdf = { 
				group_key => $group_key, 
				distance_matrix => $submatrix, 
				outgroup => $this_outgroup 
			};
			push( @matrices_dataflow, $mdf );
		}	

		# update all groups that have been seen already
		%all_groups = ( %all_groups, %large_groups );

		# check if all species have been covered in one group - if so, stop
		if ( scalar keys %large_groups == 1 ) {
			my @one_key_list  = keys %large_groups;
			my $end_taxon_id  = pop @one_key_list;
			my $num_gdbs      = scalar @gdbs;
			my $num_group_mem = scalar @{ $large_groups{$end_taxon_id} };
			if ($num_group_mem == $num_gdbs) {
				my $this_taxon = $ncbi_adaptor->fetch_node_by_taxon_id($end_taxon_id);
				print "Looks like these are all in " . $this_taxon->rank . " " . $this_taxon->name . ". Stopping here.\n";
				$self->warning("Looks like these are all in " . $this_taxon->rank . " " . $this_taxon->name . ". Stopping here.\n");
				last;
			}
		}
		
	}

	$matrices_dataflow[-1]->{group_key} = 'root';

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

sub group_on_taxonomy {
	my ($self, $gdbs, $tax_rank) = @_;

	my $dba = $self->compara_dba;
	my $ncbi_adaptor = $dba->get_NCBITaxonAdaptor;

	my %taxonomic_groups;
	foreach my $gdb ( @$gdbs ) {
		my $taxon = $ncbi_adaptor->fetch_node_by_taxon_id($gdb->taxon_id);
		my $this_rank = $self->_taxonomic_rank($taxon, $tax_rank);
		push( @{ $taxonomic_groups{$this_rank} }, $gdb ) if $this_rank;
	}

	my %large_groups;
	foreach my $group_key ( keys %taxonomic_groups ) {
		my $group = $taxonomic_groups{$group_key};
		my $group_size = scalar @$group;
		if (scalar @$group >= $self->param_required('min_group_size')) {
			$large_groups{$group_key} = $group;
		}
	}

	return \%large_groups;
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

1;
