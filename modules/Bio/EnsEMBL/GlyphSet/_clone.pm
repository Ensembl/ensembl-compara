package Bio::EnsEMBL::GlyphSet::_clone;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet_simple);

## Retrieve all BAC map clones - these are the clones in the
## subset "bac_map" - if we are looking at a long segment then we only
## retrieve accessioned clones ("acc_bac_map")

sub features {
  my $self = shift;
  my $db   = $self->my_config('db');

  my @sorted =  
    map  { $_->[1] }
    sort { $a->[0] <=> $b->[0] }
    map  {[ $_->seq_region_start - 1e9 * $_->get_scalar_attribute('state'), $_ ]}
    map  { @{$self->{'container'}->get_all_MiscFeatures($_, $db) || []} } $self->my_config('set');
    
  return \@sorted;
}

## If bac map clones are very long then we draw them as "outlines" as
## we aren't convinced on their quality... However draw ENCODE filled

sub get_colours {
  my ($self, $f) = @_;
  my $colours = $self->SUPER::get_colours($f);
  
  if (!$self->my_colour($colours->{'key'}, 'solid')) {
    $colours->{'part'} = 'border' if $f->get_scalar_attribute('inner_start');
    $colours->{'part'} = 'border' if $self->my_config('outline_threshold') && $f->length > $self->my_config('outline_threshold');
  }
  
  return $colours;
}

sub colour_key {
  my ($self, $f) = @_;
  (my $state = $f->get_scalar_attribute('state')) =~ s/^\d\d://;
  
  return lc $state if $state;
  
  my $flag = 'default';
     $flag = $self->{'flags'}{$f->dbID} ||= $self->{'flag'} = $self->{'flag'} eq 'default' ? 'alt' : 'default' if $self->my_config('set', 'alt');
  
  return ($self->my_config('set'), $flag);
}

## Return the image label and the position of the label
## (overlaid means that it is placed in the centre of the
## feature.

sub feature_label {
  my ($self, $f) = @_;
  return $self->my_config('no_label') ? () : ($f->get_first_scalar_attribute(qw(name well_name clone_name sanger_project synonym embl_acc)), 'overlaid');
}

## Link back to this page centred on the map fragment
sub href {
  my ($self, $f) = @_;
  
  return $self->_url({
    type         => 'Location',
    action       => 'MiscFeature',
    r            => $f->seq_region_name . ':' . $f->seq_region_start . '-' . $f->seq_region_end,
    misc_feature => $f->get_first_scalar_attribute(qw(name well_name clone_name sanger_project synonym embl_acc)),
    mfid         => $f->dbID,
    db           => $self->my_config('db'),
  });
}

sub tag {
  my ($self, $f) = @_; 
  my ($s, $e) = ($f->get_scalar_attribute('inner_start'), $f->get_scalar_attribute('inner_end'));
  my @result;
  
  if ($s && $e) {
    (my $state = $f->get_scalar_attribute('state')) =~ s/^\d\d://;
    ($s, $e) = $self->sr2slice($s, $e);
    push @result, { style => 'rect', start => $s, end => $e, colour => $self->my_colour($state) };
  }
  
  push @result, { style => 'left-triangle', start => $f->start, end => $f->end, colour => $self->my_colour('fish_tag') } if $f->get_scalar_attribute('fish');
  
  return @result;
}

sub render_tag {
  my ($self, $tag, $composite, $slice_length, $height, $start, $end) = @_;
  my @glyph;
  
  if ($tag->{'style'} eq 'left-triangle') {
    my $triangle_end = $start - 1 + 3/$self->scalex;
       $triangle_end = $end if $triangle_end > $end;

    push @glyph, $self->Poly({
      colour    => $tag->{'colour'},
      absolutey => 1,
      points    => [ 
        $start - 1,    0,
        $start - 1,    3,
        $triangle_end, 0
      ],
    });
  }
  
  return @glyph;
}

sub export_feature {
  my $self = shift;
  my ($feature, $feature_type) = @_;
  
  return $self->_render_text($feature, $feature_type, { 
    headers => [ 'id' ],
    values  => [ [$self->feature_label($feature)]->[0] ]
  });
}

1;
