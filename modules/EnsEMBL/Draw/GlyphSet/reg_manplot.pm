=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::reg_manplot;

### Draws a Manhattan plot for Linkage Disequilibrium (LD) data

use strict;

use EnsEMBL::Draw::Style::Plot::LD;
use Bio::EnsEMBL::Variation::Utils::Constants;
use Bio::EnsEMBL::Variation::VariationFeature;
use EnsEMBL::Web::REST;
use POSIX qw(floor ceil);

use base qw(EnsEMBL::Draw::GlyphSet);

sub _key { return $_[0]->my_config('key') || 'r2'; }

sub colour_key { return lc $_[1]->display_consequence; }
sub label_overlay { return 1; }
sub class { return 'group' if $_[0]{'display'} eq 'compact'; }
sub depth { return $_[0]{'display'} eq 'compact' ? 1 : $_[0]->SUPER::depth; }
sub supports_subtitles { return 1; }

sub _init {
  my $self = shift;
  my $key  = $self->_key;

  # LD track type display option
  return if ($self->{'display'} eq 'off');

  # Track height
  my $height = $self->my_config('height') || 80;

  # Horinzontal line mark
  my $h_mark = $self->{'config'}->get_parameter($self->_key.'_mark') || 0.8;

  # Track configuration
  $self->{'my_config'}->set('height', $height);
  $self->{'my_config'}->set('h_mark', $h_mark);
  $self->{'my_config'}->set('baseline_zero', 1);

  # Left-hand side labels
  # Shift down the lhs label to between the axes unless the subtitle is within the track
  $self->{'label_y_offset'} = ($height)/2 + $self->subtitle_height;

  my $config   = $self->track_style_config;
  my $features = [];

  my $slice = $self->{'container'};
  my $rest = EnsEMBL::Web::REST->new($self->{'config'}->hub);
  my $data = $rest->fetch_via_ini('Homo_sapiens','gtex',{
    stableid => $self->{'config'}->hub->param('g'),
    tissue => $self->{'my_config'}->get('tissue'),
  });
  my $vdba = $slice->adaptor->db->get_db_adaptor('variation');
  my $va = $vdba->get_VariationAdaptor;
  foreach my $f (@$data) {
    my $v = $va->fetch_by_name($f->{'snp'});
    next unless $v;
    foreach my $vf (@{$v->get_all_VariationFeatures()||[]}) {
      my $start = $vf->start - $slice->start+1;
      my $end = $vf->end - $slice->start+1;
      next if $start < 1 or $end > $slice->length;
      push @$features,{
        start => $start,
        end => $end,
        label => $vf->name,
        colour => $self->my_colour($vf->display_consequence),
        href => '#',
        score => -log($f->{'value'})/log(10)
      };
    }
  }

  if (!scalar(@$features)) {
    $self->{'my_config'}->set('height', $self->subtitle_height);
    $self->{'label_y_offset'} = 0;
    my $track_name = $self->my_config('caption');
    $self->errorTrack("No $track_name data for this region");
  }
  else {
    my $style = EnsEMBL::Draw::Style::Plot::LD->new($config, $features);
    $self->push($style->create_glyphs);
  }
}

sub my_label { 
  my $self  = shift;  
  my $label = $self->type =~ /somatic/ ? 'Somatic Mutations' : 'Variations'; 
  return $label; 
}

sub title {
  my ($self, $f) = @_;
  my $vid     = $f->variation_name;
  my $type    = $f->display_consequence;
  my $dbid    = $f->dbID;
  my ($s, $e) = $self->slice2sr($f->start, $f->end);
  my $loc     = $s == $e ? $s : $s <  $e ? "$s-$e" : "Between $s and $e";
  
  return "Variation: $vid; Location: $loc; Consequence: $type; Ambiguity code: ". $f->ambig_code;
}

sub href {
  my ($self, $f, $value) = @_;
  
  my $key = $self->_key();

  return $self->_url({
    species  => $self->species,
    type     => 'Variation',
    v        => $f->variation_name,
    vf       => $f->dbID,
    vdb      => $self->my_config('db'),
    snp_fake => 1,
    config   => $self->{'config'}{'type'},
    track    => $self->type,
    $key     => $value
  });
}

1;
