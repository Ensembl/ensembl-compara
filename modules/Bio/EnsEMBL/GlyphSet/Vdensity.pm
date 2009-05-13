package Bio::EnsEMBL::GlyphSet::Vdensity;
use strict;
use warnings;
no warnings 'uninitialized';
use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) = @_;
  my $Config = $self->{'config'};
  my $chr    = $self->{'extras'}->{'chr'} || $self->{'container'}->{'chr'};

  my $slice_adapt   = $self->{'container'}->{'sa'};
  my $density_adapt = $self->{'container'}->{'da'};

  my $chr_slice = $slice_adapt->fetch_by_region('chromosome', $chr);
  my $v_offset = $Config->container_width() - ($chr_slice->length() || 1);

  my @objs = map { { 'key' => $_,'scale'=>1,'max_value'=>0} }
             @{ $self->my_config('keys')||[] };

  my $features = 0;
  my $max_value = 0;

  #get the maximum value from all shared types if we want to scale across multiple tracks
  if ($self->my_config('scale_all')) {
    foreach my $sv (@{ $Config->get_parameter('scale_values') })  {
#      if (grep {$sv eq $_->{'key'}} @objs) {
	my $density = $density_adapt->fetch_Featureset_by_Slice($chr_slice, $sv, 150, 1);
	my $this_max_value = $density->max_value;
	$max_value = $this_max_value if $this_max_value > $max_value;
 #     }
    }
  }


## Pass one - get all the densities from the database...
  foreach(@objs) {
    $_->{'density'}   = $_->{'key'} ? $density_adapt->fetch_Featureset_by_Slice( $chr_slice, $_->{'key'}, 150, 1 ) : undef;
    next unless $_->{'density'};
    $_->{'max_value'} = $_->{'density'}->max_value;
    $max_value = $_->{'max_value'} if $_->{'max_value'} > $max_value;
    $features += $_->{'density'}->size;
  }
  return unless $max_value;

## Pass two - if they are all on the same scale - set scale factor to ratio with highest value..

  if( $self->my_config('same_scale') || $self->my_config('scale_all') ) {
    $_->{'scale'} = $_->{'max_value'}/$max_value foreach(@objs);
  }

## Pass three - now rescale all images to fit track width, and get and store values

  foreach(@objs) {
    $_->{'values'} = [];
    next unless $_->{'density'};
    $_->{'density'}->scale_to_fit( ($self->my_config( 'width' )||80) * $_->{'scale'} );
    $_->{'density'}->stretch(0);
    $_->{'values'} = $_->{'density'}->get_all_binvalues;
  }

## Pass four - render the features if they exist!!

  foreach my $o (@objs) {
    my @a = @{$o->{'values'}||[]};
    next unless @a;
    my $feature_colour = $self->my_colour($o->{'key'});
    my $style          = $self->my_colour($o->{'key'},'style');
    if( $style eq 'fill' || $style eq 'box' ) {
      my $part = $style eq 'fill' ? 'colour' : 'bordercolour';
      foreach (@a){ 
        $self->push($self->Rect({
          'x'      => $v_offset + $_->start,
          'y'      => 0,
          'width'  => $_->end - $_->start,
          'height' => $_->scaledvalue,
          $part    => $feature_colour,
          'absolutey' => 1,
        }));
      }
    } elsif( $style eq 'narrow' ) {
      foreach (@a){ 
        $self->push($self->Line({
          'x'      => $v_offset + ($_->start+$_->end)/2,
          'y'      => 0,
          'width'  => 0,
          'height' => $_->scaledvalue,
          'colour' => $feature_colour,
          'absolutey' => 1,
        }));
      }
    } else { 
      my $old_x = undef;
      my $old_y = undef;
      foreach (@a){ 
        my $new_x = ($_->start+$_->end)/2;
        my $new_y = $_->scaledvalue;
        $self->push($self->Line({
          'x'      => $old_x,
          'y'      => $old_y,
          'width'  => $new_x-$old_x,
          'height' => $new_y-$old_y,
          'colour' => $feature_colour,
          'absolutey' => 1,
        })) if defined $old_x;
        $old_x = $new_x;
        $old_y = $new_y;
      }
    }
  }
}

1;
