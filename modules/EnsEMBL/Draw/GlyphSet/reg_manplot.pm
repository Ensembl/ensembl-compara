=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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
use List::Util qw(min max);

use base qw(EnsEMBL::Draw::GlyphSet);

# Note that the value of y-scale and the calculation of value must match
# or you will get the wrong ZMenus appearing.

sub _key { return $_[0]->my_config('key') || 'r2'; }

sub colour_key { return lc $_[1]->display_consequence; }
sub label_overlay { return 1; }
sub class { return 'group' if $_[0]{'display'} eq 'compact'; }
sub depth { return $_[0]{'display'} eq 'compact' ? 1 : $_[0]->SUPER::depth; }
sub supports_subtitles { return 1; }


sub _init {
  my $self = shift;
  my $key  = $self->_key;
  my $hub   = $self->{'config'}->hub;

  # LD track type display option
  return if ($self->{'display'} eq 'off');

  # Track height
  my $height = $self->my_config('height') || 80;

  # p-value or beta
  my $display = $self->{'display'};
  my $key;
  if($display eq 'beta') {
    $key = 'beta';
  } else {
    $key = 'neg_log10_pvalue';
  }

  # Get data
  my $eqtl_rest_url = $hub->species_defs->EQTL_REST_URL;

  my $rest = EnsEMBL::Web::REST->new($hub);

  my @data;

  my $fetch_url = sprintf( "%sassociations?gene_id=%s&qtl_group=%s&size=1000", $eqtl_rest_url, $hub->param('g'), $self->{'my_config'}->get('tissue'));
  
  do {
    my ($response,$error) = $rest->fetch_url($fetch_url, {});

    if($error) {
      my $msg = $response->[0];
      warn "REST failed: $msg\n";
      return $self->errorTrack(sprintf("Data source failed: %s",$msg));
    }

    @data = ( @data, values %{$response->{'_embedded'}->{'associations'}});

    $fetch_url = $response->{'_links'}->{'next'}->{'href'};

  } while ($fetch_url);
  

  # Legends
  foreach my $f (@data) {
    my $conseq = $f->{'display_consequence'};
    my $colour = $self->my_colour($conseq);
    $self->{'legend'}{'variation_legend'}{lc $conseq} ||= $colour if $conseq;
  }

  my ($y_scale,$y_off);
  if($display eq 'beta') {
    $self->{'my_config'}->set('min_score_label','-1');
    $self->{'my_config'}->set('max_score_label',"1");
    $self->{'my_config'}->set('h_mark',0.5);
    $self->{'my_config'}->set('h_mark_label',"0");
    $y_scale = 2;
    $y_off = 0.5;
  } else {
    $y_scale = int(max(0,map { $_->{$key} } @data))+1;
    $y_off = 0;
    $self->{'my_config'}->set('min_score_label','1');
    $self->{'my_config'}->set('max_score_label',"<10^-$y_scale");
  }

  # Track configuration
  $self->{'my_config'}->set('height', $height);
  $self->{'my_config'}->set('baseline_zero', 1);
  $self->push($self->Rect({
    x => 0,
    y => -4,
    width => $self->{'config'}->container_width,
    height => $height+8,
    absolutey => 1,
    href => $self->bg_link($y_scale),
    class => 'group'
  }));
  # Left-hand side labels
  # Shift down the lhs label to between the axes unless the subtitle is within the track
  $self->{'label_y_offset'} = ($height)/2 + $self->subtitle_height;

  my $config   = $self->track_style_config;
  my $features = [];

  my $slice = $self->{'container'};

  foreach my $f (@data) {
    next unless $f->{$key};
    my $position = $f->{'position'} - $slice->start+1;

    next if $position < 1 or $position > $slice->end;
    my $value = max($f->{$key}/$y_scale+$y_off,0);
    push @$features,{
      start => $position,
      end => $position,
      label => $f->{'rsid'},
      colour => $self->my_colour($f->{'display_consequence'}),
      score => $value,
    };
  }

  if (!scalar(@$features)) {
    $self->{'my_config'}->set('height', $self->subtitle_height);
    $self->{'label_y_offset'} = 0;
    my $track_name = $self->my_config('caption');
    $self->errorTrack("No $track_name data for this region");
  }
  else {
    my $style = EnsEMBL::Draw::Style::Plot::LD->new($config, [{'features' => $features}]);
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

sub href { return undef; }

sub bg_link {
  my ($self,$y_scale) = @_;

  return $self->_url({
    action => 'GTEX',
    ftype  => 'Regulation',
    sp  => ucfirst $self->species,
    scalex => $self->scalex,
    width => $self->{'container'}->length,
    g => $self->{'config'}->hub->param('g'),
    tissue => $self->{'my_config'}->get('tissue'),
    height => $self->{'my_config'}->get('height'),
    y_scale => $y_scale,
    renderer => $self->{'display'},
  });
}

1;
