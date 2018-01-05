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

Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::BuildMashDistanceMatrix

=head1 SYNOPSIS

Parse mash dist output and create a distance matrix for tree building with NJ

=head1 DESCRIPTION

=cut

package Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::BuildMashDistanceMatrix;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Data::Dumper;

sub run {
	my $self = shift;

	my %distance_hash;
	my %species_hash; # get full list of unique species names
	
	open(MASH, '<', $self->param_required('mash_output_file'));
	# my @mash_dist_output = split( "\n", $self->param_required('mash_output'));
	# foreach my $comparison ( @mash_dist_output ) {

	while ( my $comparison = <MASH> ) {
		print "COMPARISON: $comparison\n";
		my ($file1, $file2, $dist, $pval, $shared_hashes) = split( /\s/, $comparison );
		my $species1 = $self->get_species_name_from_sketch($file1);
		my $species2 = $self->get_species_name_from_sketch($file2);
		next if $species1 eq $species2;
		$distance_hash{$species1}->{$species2} = $dist;
		$species_hash{$species1} = 1;
		$species_hash{$species2} = 1;
	}

	close MASH;

	my @species_order = sort keys %species_hash;

	# print Dumper \@species_order;
	print Dumper \%species_hash;
	print Dumper \%distance_hash;

	my $matrix = $self->create_matrix(\%distance_hash, \@species_order);
	$self->write_mega_file( \@species_order, $matrix );
	unlink $self->param('mash_output_file') if ( $self->param('cleanup_distance_file') );
}

sub get_species_name_from_sketch {
	my ( $self, $sketch_file ) = @_;

	$sketch_file =~ m/([A-Za-z_]+)/;
	return $1;
}

sub create_matrix {
	my ($self, $dist_hash, $species_order) = @_;

	my @matrix;
	for ( my $i = 0; $i < scalar @$species_order; $i++ ) {
		push( @matrix, ["[" . ($i+1) . "]"] );
		# set padding
		for( my $x = 0; $x < $i; $x++ ) {
			push( @{ $matrix[$i] }, '     ' );
		}

		my $i_species = $species_order->[$i];
		for ( my $j = $i+1; $j < scalar @$species_order; $j++ ) {
			my $j_species = $species_order->[$j];
			push( @{ $matrix[$i] }, sprintf("%.3f", $dist_hash->{$i_species}->{$j_species}) );
		}
	}
	return \@matrix;
}

sub write_mega_file {
	my ( $self, $species_order, $matrix ) = @_;

	my $ntaxa = scalar @$species_order;
	my $mega_file = $self->param_required('output_file');
	open(MEGA, '>', $mega_file);

	# print headers
	print MEGA "#mega\n!Title Ensembl Species;\n";
	print MEGA "!Description mash distance matrix for ensembl species;\n";
	print MEGA "!Format DataType=Distance DataFormat=UpperRight NTaxa=$ntaxa;\n\n";

	# print species list
	for ( my $i = 0; $i < $ntaxa; $i++ ) {
		print MEGA "[" . ($i+1) . "] #" . $species_order->[$i] . "\n";
	}

	# print matrix
	my @taxon_numbers = 1..$ntaxa;
	print MEGA "[\t" . join( "\t", @taxon_numbers ) . " ]\n";
	foreach my $row ( @$matrix ) {
		print MEGA join( "\t", @$row ) . "\n"
	}
	close MEGA;
}

1;