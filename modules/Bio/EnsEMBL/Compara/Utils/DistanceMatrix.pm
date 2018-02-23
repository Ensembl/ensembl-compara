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

Bio::EnsEMBL::Compara::Utils::DistanceMatrix

=head1 DESCRIPTION

An object that handles distance matrices in an easily accessible format for manipulation or file conversion.
It has been designed to read Mash tabular distance format for use in the CreateSpeciesTree_conf pipeline.

=cut

package Bio::EnsEMBL::Compara::Utils::DistanceMatrix;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use File::Basename;

use Data::Dumper;
$Data::Dumper::Maxdepth = 2;

=head2 new

	Example :
		my $dist_matrix = Bio::EnsEMBL::Compara::Utils::DistanceMatrix->new(-file => 'mash_distance.txt');
		my $dist_matrix = Bio::EnsEMBL::Compara::Utils::DistanceMatrix->new(-fh => $filehandle);
	Description : Creates a new DistanceMatrix object
	Returntype  : Bio::EnsEMBL::Compara::Utils::DistanceMatrix

=cut

sub new {
	my $self = shift;
	my($filename, $filehandle) =
        rearrange([qw(FILE FH)], @_);

    my $matrix = {};
    if ( $filename ) {
    	open(my $this_fh, '<', $filename);
    	# print STDERR "parsing matrix from $filename...\n";
    	$matrix = $self->parse_matrix($this_fh);
    } elsif ( $filehandle ) {
    	$matrix = $self->parse_matrix($filehandle);
    }

    # returns an empty matrix if no file is defined
    return bless $matrix, 'Bio::EnsEMBL::Compara::Utils::DistanceMatrix';
}

=head2 members

	Example : my @mems = $matrix->members();
	Description : return the ids for the members of the matrix
	Returntype: array

=cut

sub members {
	my $matrix = shift;
	return keys %$matrix;
}

=head2 distance

	Example : 
		my $this_distance = $matrix->distance('id1', 'id2');
		$matrix->distance('id1', 'id2', $new_distance);
	Description : getter/setter for the distance between two members
		of the matrix
	Returntype : as a getter, it returns the distance between the given
		members. as a setter, it returns the matrix

=cut

sub distance {
	my ($matrix, $s1, $s2, $new_distance) = @_;

	return $matrix->{$s1}->{$s2} unless defined $new_distance;
	$matrix->{$s1}->{$s2} = $new_distance;
	$matrix->{$s2}->{$s1} = $new_distance;
	$matrix->{$s1}->{$s1} = 0;
	$matrix->{$s2}->{$s2} = 0; # deal with diagonals
	return $matrix;
}

sub parse_matrix {
	my ($self, $dist_fh) = @_;

	# first get column order from header line
	my $header = <$dist_fh>;
	my @cols = split(/\s+/, $header);
	shift @cols; # remove first element '#query'

	# loop through data rows and store in 2D hash (gdb_id key)
	# my $matrix = $self->new();
	my $matrix = Bio::EnsEMBL::Compara::Utils::DistanceMatrix->new();
	while ( my $line = <$dist_fh> ) {
		my @elems = split(/\s+/, $line);
		my $species1_filename = shift @elems;

		my $x = 0;
		foreach my $e ( @elems ) {
			my $species2_filename = $cols[$x];
			$matrix = $matrix->distance($species1_filename, $species2_filename, $e);
			$x++;
		}
	}

	return $matrix;
}

=head2 convert_to_genome_db_ids

	Arg [1] : Bio::EnsEMBL::Compara::GenomeDBAdaptor
	Arg [2] : (optional) regex to extract species name and assembly from current id
	Example: $matrix->convert_to_genome_db_ids( $genome_db_adaptor );
	Example: $matrix->convert_to_genome_db_ids( $genome_db_adaptor, '(^[a-z]+)-([A-Z0-9]+)\.gz');
	Description : Convert keys in a matrix from species names (+assemblies) to genome_db_id.
	An optional regular expression may be passed if your filename format does not
	follow species_name.assembly.fa standard. This regex must result in $1 = species name
	and $2 = assembly name
	Returntype : Bio::EnsEMBL::Compara::Utils::DistanceMatrix

=cut 

sub convert_to_genome_db_ids {
	my ( $matrix, $gdb_adaptor, $opt_regex ) = @_;

	# my $gdb_adaptor  = $self->compara_dba->get_GenomeDBAdaptor;
	# my $ncbi_adaptor = $self->compara_dba->get_NCBITaxonAdaptor;

	# map filenames to genome_db_ids
	my $filename_regex = $opt_regex ? $opt_regex : '(^[A-Za-z_0-9]+)\.([A-Za-z0-9_\-\.]+)\.fa';

	my %file_map;
	foreach my $file ( $matrix->members ) {
		my ( $species_name, $assembly_name ) = $matrix->_get_species_info_from_filename($file, $filename_regex);
		my $this_gdb = $gdb_adaptor->fetch_by_name_assembly( $species_name, $assembly_name );
		die "Cannot find species $species_name ($assembly_name) in compara database" unless $this_gdb;
		$file_map{$file} = $this_gdb->dbID;
	}
	
	my $gdb_matrix = Bio::EnsEMBL::Compara::Utils::DistanceMatrix->new();
	foreach my $f1 ( $matrix->members ) {
		my $f1_gdb_id = $file_map{$f1};
		foreach my $f2 ( $matrix->members ) {
			my $f2_gdb_id = $file_map{$f2};
			$gdb_matrix->distance($f1_gdb_id, $f2_gdb_id, $matrix->distance($f1, $f2));
		}
	}
	return $gdb_matrix;
}

# run regex on filenames (dealing with prefixed paths) and return 
# species name and assembly
sub _get_species_info_from_filename {
	my ($self, $basefile, $regex) = @_;

	my ($filename, $filepath) = fileparse($basefile);
	$filename =~ m/$regex/;

	return ($1, $2);
}

=head2 add_taxonomic_distance

	Arg [1] : Bio::EnsEMBL::Compara::GenomeDBAdaptor
	Example : $matrix = $matrix->add_taxonomic_distance($genome_db_adaptor)
	Description : replace all distances in a matrix with an average of the given distance
		and the taxonomic distance for each pair of species. This method assumes that matrix
		ids are genome_db_ids (if they are not, convert them with $matrix->convert_to_genome_db_ids)
	Returntype : Bio::EnsEMBL::Compara::Utils::DistanceMatrix

=cut

sub add_taxonomic_distance {
	my ( $matrix, $genome_db_adaptor ) = @_;

	my $tax_matrix = Bio::EnsEMBL::Compara::Utils::DistanceMatrix->new();
	foreach my $m1 ( $matrix->members ) {
		my $taxon1 = $genome_db_adaptor->fetch_by_dbID($m1)->taxon;
		foreach my $m2 ( $matrix->members ) {
			my $this_matrix_dist = $matrix->distance($m1, $m2);
			my $taxon2 = $genome_db_adaptor->fetch_by_dbID($m2)->taxon;
			my $tax_dist = $taxon1->distance_to_node($taxon2);
			my $new_dist = $tax_dist >= 0.01 ? ($this_matrix_dist + $tax_dist)/2 : $this_matrix_dist;
			$tax_matrix->distance($m1, $m2, $new_dist);
		}
	}
	return $tax_matrix;
}

=head2 prune_gdbs_from_matrix

	Arg [1] : arrayref of Bio::EnsEMBL::Compara::GenomeDB objects
	Example : my $submatrix = $matrix->prune_gdbs_from_matrix(\@gdb_list);
	Description : returns a submatrix containing only the given species
	Returntype : Bio::EnsEMBL::Compara::Utils::DistanceMatrix

=cut

sub prune_gdbs_from_matrix {
	my ( $matrix, $gdb_list ) = @_;
	
	my @gdb_id_list = map {$_->dbID} @$gdb_list;
	my $submatrix = Bio::EnsEMBL::Compara::Utils::DistanceMatrix->new();
	foreach my $gdb1 ( @gdb_id_list ) {
		foreach my $gdb2 ( @gdb_id_list ) {
			$submatrix = $submatrix->distance( $gdb1, $gdb2, $matrix->distance($gdb1, $gdb2) );
		}
	}

	return $submatrix;
}

=head2 collapse_group_in_matrix

	Arg [1] : arrayref of Bio::EnsEMBL::Compara::GenomeDB objects
	Arg [2] : (optional) id to assign to newly grouped species (default: 'new')
	Example :
		my $collapsed = $matrix->collapse_group_in_matrix( \@gdb_list, 'primates' );
	Description : given a list of species, replace their matrix entries with a single,
		combined matrix entry using the average distance
	Returntype : Bio::EnsEMBL::Compara::Utils::DistanceMatrix

=cut

sub collapse_group_in_matrix {
	my ($matrix, $to_collapse_full, $new_group_id) = @_;

	# print "!!!! collapsing [" . join(',', map {$_->name . '(' . $_->dbID . ')'} @$to_collapse) . "] to $new_group_id\n";

	# first, check species are in the matrix
	my @to_collapse;
	foreach my $gdb ( @$to_collapse_full ) {
		push( @to_collapse, $gdb ) if ( defined $matrix->{$gdb->dbID} );
	}
	return $matrix if scalar @to_collapse == 0;

	$new_group_id ||= 'new';

	my $consensus_matrix = Bio::EnsEMBL::Compara::Utils::DistanceMatrix->new();
	$consensus_matrix = $consensus_matrix->distance( $new_group_id, $new_group_id, 0); # manually add diagonal
	my $x = 0;
	foreach my $gdb_id1 ( $matrix->members ) {
		next if ( grep {$gdb_id1 eq $_->dbID} @to_collapse );

		# my ( $tot_dist, $tot_num ) = ( 0,0 );
		my @collapse_dists;
		foreach my $gdb_id2 ( keys %$matrix ) {
			next if $consensus_matrix->{$gdb_id1}->{$gdb_id2};
			next if $consensus_matrix->{$gdb_id2}->{$new_group_id};
			if ( grep {$gdb_id2 eq $_->dbID} @to_collapse ) {
				push( @collapse_dists, $matrix->distance( $gdb_id1, $gdb_id2 ) );
			} else {
				$consensus_matrix = $consensus_matrix->distance($gdb_id1, $gdb_id2, $matrix->distance($gdb_id1, $gdb_id2));
			}
		}
		
		my $l = scalar @collapse_dists;
		my $t = 0;
		foreach my $i ( @collapse_dists ) { $t += $i; }
		my $mean = $t/$l;
		$consensus_matrix = $consensus_matrix->distance($gdb_id1, $new_group_id, $mean );
		$x++;

	}

	# delete empty entries (where do they come from anyway?!)
	foreach my $k ( keys %$consensus_matrix ) {
		delete $consensus_matrix->{$k} unless defined $consensus_matrix->{$k}->{$k};
	}

	return $consensus_matrix;
}

=head2 print_matrix

	Example : $matrix->print_matrix;
	Description : print human-friendly(ish) matrix
	Returntype : none

=cut

sub print_matrix {
	my $matrix = shift;

	my @keys = $matrix->members;
	print "\t" . join("      \t", @keys) . "\n";
	foreach my $x ( @keys ) {
		print "$x\t";
		foreach my $y ( @keys ) {
			my $s = $matrix->distance($x, $y);
			printf("%.5f", $s) if defined $s;
			print "NA     " if not defined $s;
			print "  \t";
		}
		print "\n";
	}
}

=head2 phylip_from_matrix

	Arg [1] : output file path
	Arg [2] : (optional) format - 'multi' or 'standard' (default: standard)
	Example : $matrix->phylip_from_matrix('/path/to/file.phy');
	Description : write the distance matrix in phylip format to the given file.
		'multi' format is designed to be compatible with the erable software. it allows
		for multiple datasets in a single file (see section 3. Input Files : 
		http://www.atgc-montpellier.fr/erable/usersguide.php)
	Returntype : none

=cut

sub phylip_from_matrix {
	my ( $matrix, $phylip_file, $format ) = @_;

	my @keys = keys %$matrix;
	my $species_count = scalar @keys;
	my $reformatted_matrix;
	foreach my $x ( @keys ) {
		if ( $x =~ /^mrg/ ) {
			$reformatted_matrix .= "$x\t";
		} else {
			$reformatted_matrix .= "gdb$x\t";
		}
		
		foreach my $y ( @keys ) {
			my $s = $matrix->{$x}->{$y};
			$reformatted_matrix .= sprintf("%.5f", $s) if defined $s;
			$reformatted_matrix .= "NA     " if not defined $s;
			$reformatted_matrix .= "  \t";
		}
		$reformatted_matrix .= "\n";
	}

	if ( $format && $format eq 'multi' ) {
		$reformatted_matrix = "1\n\n$species_count 1\n" . $reformatted_matrix;
	} else {
		$reformatted_matrix = "    $species_count\n" . $reformatted_matrix;
	}
	open(OUT, '>', $phylip_file);
	print OUT $reformatted_matrix;
	close OUT;
}

1;
