package EnsEMBL::Web::Object::DAS::simple;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Object::DAS::dna_align);

sub Types {
  my $self = shift;
  return [
    { 'id' => 'simple feature'  }
  ];
}

sub Features {
  my $self = shift;
  return $self->_features( 'SimpleFeature', 'simple_alignment' );
}

sub _feature {
  my( $self, $f ) = @_;

## Now we do all the nasty stuff of retrieving features and creating DAS objects for them...
  my $type          = $f->analysis->logic_name;
  my $display_label = $f->display_label;
  my $slice_name = $f->slice->seq_region_name.':'.$f->slice->start.','.$f->slice->end.':'.$f->slice->strand;
  unless( exists $self->{_features}{$slice_name} ) {
    $self->{_features}{$slice_name} = {
      'REGION' => $f->slice->seq_region_name,
      'START'  => $f->slice->start,
      'STOP'   => $f->slice->end,
      'FEATURES' => [],
    };
    if( $f->slice->strand > 0 ) {
      $self->{_slice_hack}{$slice_name} = [  1, $self->{_features}{$slice_name}{'START'}-1 ];
    } else {
      $self->{_slice_hack}{$slice_name} = [ -1, $self->{_features}{$slice_name}{'STOP'} +1 ];
    }
  }
  push @{$self->{_features}{$slice_name}{'FEATURES'}}, {
   'ID'          => $type,
   'TYPE'        => "simple feature:$type",
   'SCORE'       => $f->score,
   'METHOD'      => $type,
   'CATEGORY'    => $type,
   'START'       => $self->{_slice_hack}{$slice_name}[0] * $f->start + $self->{_slice_hack}{$slice_name}[1],
   'END'         => $self->{_slice_hack}{$slice_name}[0] * $f->end   + $self->{_slice_hack}{$slice_name}[1],
   'ORIENTATION' => $self->{_slice_hack}{$slice_name}[0] * $f->strand > 0 ? '+' : '-',
  };
## Return the reference to an array of the slice specific hashes.
}

1;
