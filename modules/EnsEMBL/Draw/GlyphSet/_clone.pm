=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::_clone;

### Retrieve all BAC map clones - these are the clones in the
### subset "bac_map" - if we are looking at a long segment then we only
### retrieve accessioned clones ("acc_bac_map")

use strict;

use base qw(EnsEMBL::Draw::GlyphSet_simple);

sub label_overlay { return 1; }

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
  return $state ? lc $state : $self->my_config('set');
}

sub feature_label {
  my ($self, $f) = @_;
  return $f->get_first_scalar_attribute(qw(name well_name clone_name sanger_project synonym embl_acc));
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
