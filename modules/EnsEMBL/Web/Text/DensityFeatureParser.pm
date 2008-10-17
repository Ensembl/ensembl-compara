#
# Ensembl web module for Data::Bio::Text::DensityFeatureParser
#
# Cared for by James Smith <js5@sanger.ac.uk>
#
# Copyright James Smith
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

Data::Bio::Text::DensityFeatureParser - Density from text based data (URL,file or text)

=head1 SYNOPSIS

    my $dfp = new Data::Bio::Text::DensityFeatureParser();
       $dfp->no_of_bins(150);
       $dfp->no_of_bins($chr_length/150);
       $dfp->filter( '1' );
       $dfp->current_key( 'default' );

    $dfp->parse( $DATA );

    print "@{[$dfp->feature_types]}\n";

=head1 DESCRIPTION

Handles text based data in standard forms (PSL, BED, ...) and computes chromosomal densities

=head1 CONTACT

James Smith <js5@sanger.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Data::Bio::Text::DensityFeatureParser;

use Data::Bio::Text::FeatureParser;

@Data::Bio::Text::DensityFeatureParser::ISA =
  qw(Data::Bio::Text::FeatureParser);

use strict;
use warnings;
no warnings "uninitialized";

=head2 no_of_bins

 Title   : no_of_bins
 Usage   : $dfp->no_of_bins( 150 ) or $X = $dfp->no_of_bins();
 Function: Get setter for the number of bins to display
 Returns : integer (no of bins)
 Args    : integer - no of bins [optional - setting]

=cut

sub no_of_bins {
  my $self = shift;
  $self->{'_no_of_bins'} = shift if @_;
  return $self->{'_no_of_bins'};
}
 
=head2 bin_size

 Title   : bin_size
 Usage   : $dfp->bin_size( 150 ) or $X = $dfp->bin_size();
 Function: Get setter for the size of each bin
 Returns : number (size of bin)
 Args    : number - size of bin [optional - setting]

=cut

sub bin_size {
  my $self = shift;
  $self->{'_bin_size'} = shift if @_;
  return $self->{'_bin_size'};
}
 
=head2 store_feature

 Title   : store_feature
 Usage   : $dfp->store_feature( $type, $feature );
 Function: Adds a feature of given type ($type) to the data, updating the density information
           about the feature and updating the total count for that feature
 Returns : hash ref
 Args    : none

=cut

sub store_feature {
  my ( $self, $key, $feature ) = @_;
  my( $chr, $start, $end ) = ( $feature->seqname, $feature->rawstart, $feature->rawend );
  $start = int($start / $self->{'_bin_size'} );
  $end = int( $end / $self->{'_bin_size'} );
  $end = $self->{'_no_of_bins'} - 1 if $end >= $self->{'_no_of_bins'};
  $self->{'_bins'}{$key}{$chr} ||= [ map { 0 } 1..$self->{'_no_of_bins'} ];
  foreach( $start..$end ) {
    $self->{'_bins'}{$key}{$chr}[$_]++; 
  }
  $self->{'_counts'}{$key}++;
}

=head2 max_values

 Title   : counts
 Usage   : $dfp->max_values
 Function: Returns a hashref of the feature types (key) and max density (value)
 Returns : hash ref
 Args    : none

=cut

sub max_values {
  my $self = shift;
  my %max_value = map {($_,0)} keys %{ $self->{'_counts'} };
  foreach my $type ( $self->feature_types ) {
    foreach my $chr ( keys %{$self->{'_bins'}{$type}} ) {
      foreach ( @{$self->{'_bins'}{$type}{$chr}} ) {
        $max_value{$type} = $_ if $_>$max_value{$type};
      }
    }
  }
  return \%max_value;
}

=head2 feature_types

 Title   : feature_types
 Usage   : $dfp->feature_types
 Function: Return a list of the feature types
 Returns : List
 Args    : none

=cut

sub feature_types    { return keys %{$_[0]{'_counts'}}; }

=head2 features_of_type

 Title   : features_of_type
 Usage   : $dfp->features_of_type( 'type_1' );
 Function: Return a hash reference to chromosomes which have features of type "type_1"
           Each hash ref is keyed on chromosome - and each entry is an array of densities
 Returns : hash ref
 Args    : string (type)

=cut

sub features_of_type { return $_[0]{'_bins'}{$_[1]}; }

=head2 counts

 Title   : counts
 Usage   : $dfp->counts
 Function: Returns a hashref of the feature types (key) and no. of features (value)
 Returns : hash ref
 Args    : none

=cut

sub counts           { return $_[0]{'_counts'}; }

1;
