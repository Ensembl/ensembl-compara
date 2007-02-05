package EnsEMBL::Web::Object::DAS::simple;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Object::DAS);

sub Types {
  my $self = shift;
  return [
    { 'id' => 'simple feature'  }
  ];
}

sub Features {
  my $self = shift;
  return $self->base_features( 'SimpleFeature', 'simple_alignment' );
}

sub _feature {
  my( $self, $f ) = @_;

## Now we do all the nasty stuff of retrieving features and creating DAS objects for them...
  my $type          = $f->analysis->logic_name;
  my $display_label = $f->display_label;
  my $slice_name = $self->slice_cache( f->slice );
  push @{$self->{_features}{$slice_name}{'FEATURES'}}, {
   'ID'          => $type,
   'TYPE'        => "simple feature:$type",
   'SCORE'       => $f->score,
   'METHOD'      => $type,
   'CATEGORY'    => $type,
   $self->loc( $slice_name, $f->start, $f->end, $f->strand ),
  };
## Return the reference to an array of the slice specific hashes.
}

1;
