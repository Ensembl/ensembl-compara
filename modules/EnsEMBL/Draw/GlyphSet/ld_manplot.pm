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

package EnsEMBL::Draw::GlyphSet::ld_manplot;

### Draws a Manhattan plot for Linkage Disequilibrium (LD) data

use strict;

use EnsEMBL::Draw::Style::Plot::LD;
use Bio::EnsEMBL::Variation::Utils::Constants;
use Bio::EnsEMBL::Variation::VariationFeature;
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
  my $ld_type = $self->{'config'}->get_parameter('ld_type');
  $self->{'display'} = 'off' unless ($ld_type && ($ld_type eq $key || $ld_type eq 'both'));
  return if ($self->{'display'} eq 'off');

  # Focus variant name
  my $var_name;
  if ($self->{'config'}->core_object('variation')) {
    $var_name = $self->{'config'}->core_object('variation')->name;
  }

  # Track height
  my $height = $self->my_config('height') || 40;

  # Horinzontal line mark
  my $h_mark = $self->{'config'}->get_parameter($self->_key.'_mark') || 0.8;

  # Track configuration
  $self->{'my_config'}->set('focus_variant', $var_name) if (defined $var_name);
  $self->{'my_config'}->set('height', $height);
  $self->{'my_config'}->set('h_mark', $h_mark);
  $self->{'my_config'}->set('baseline_zero', 1);

  # Left-hand side labels
  # Shift down the lhs label to between the axes unless the subtitle is within the track
  $self->{'label_y_offset'} = ($height)/2 + $self->subtitle_height;

  my $config  = $self->track_style_config;
  my $data    = $self->fetch_features();

  if (!scalar(@$data)) {
    $self->{'my_config'}->set('height', $self->subtitle_height);
    $self->{'label_y_offset'} = 0;
    my $track_name = $self->my_config('caption');
    $self->errorTrack("No $track_name data for this region");
  }
  else {
    my $style = EnsEMBL::Draw::Style::Plot::LD->new($config, $data);
    $self->push($style->create_glyphs);
  }
}

sub my_label { 
  my $self  = shift;  
  my $label = $self->type =~ /somatic/ ? 'Somatic Mutations' : 'Variations'; 
  return $label; 
}

sub features {
  my $self         = shift;
  my $config       = $self->{'config'};
  my $max_length   = $self->my_config('threshold') || 1000;
  my $slice_length = $self->{'container'}->length;
  my $tracks = []; 

  if ($slice_length > $max_length * 1010) {
    $self->errorTrack("Variation features are not displayed for regions larger than ${max_length}Kb");
  } else {
    $tracks = $self->fetch_features() || [];
    if (!scalar(@$tracks)) {
      my $track_name = $self->my_config('caption'); 
      $self->errorTrack("No $track_name data for this region");
    }
  }
  return $tracks;
}

sub fetch_features {
  my $self      = shift;
  my $config    = $self->{'config'};
  my $slice     = $self->{'container'};
  my $id        = $self->{'my_config'}->id;
  my $var_db    = $self->my_config('db') || 'variation';
  my $variation = $config->core_object('variation')->name;
  my $pop_name  = $self->my_config('pop_name');
  my $vf_id     = $self->{'config'}->get_parameter('vf');

  unless ($pop_name) {
    warn "****[WARNING]: No population defined";
    return;
  }
  unless ($vf_id) {
    warn "****[WARNING]: No variant location defined";
    return;
  }

  # Population
  my $pop_adaptor = $slice->adaptor->db->get_db_adaptor('variation')->get_PopulationAdaptor;
  my $pop_obj = $pop_adaptor->fetch_by_name($pop_name);
  my $pop_id =  $pop_obj->dbID;
 
   # Variation Feature
  my $vf_adaptor = $slice->adaptor->db->get_db_adaptor('variation')->get_VariationFeatureAdaptor;
  my $vf_obj = $vf_adaptor->fetch_by_dbID($vf_id);

  # LD Feature Container
  my $ld_adaptor = $slice->adaptor->db->get_db_adaptor('variation')->get_LDFeatureContainerAdaptor;
  $ld_adaptor->max_snp_distance(ceil($slice->length/2));

  # Limit to the LD associated with the focus variant
  my $data = $ld_adaptor->fetch_by_VariationFeature($vf_obj,$pop_obj);
  my $ld_containers = $data->get_all_ld_values();

  my $key = $self->_key();
  my (@snps, @snps_data);

  my $selected_snp;

  foreach my $ld_data ( @$ld_containers ) {
    my $vf;
    my $vf_selected;
    my %data;
    $vf = ($ld_data->{'variation1'}->variation_name eq $variation) ? $ld_data->{'variation2'} : $ld_data->{'variation1'};

    # Add the focus SNP in the list of features
    if (!$selected_snp) {
      $vf_selected = ($ld_data->{'variation1'}->variation_name eq $variation) ? $ld_data->{'variation1'} : $ld_data->{'variation2'};
      my %focus_data;
      $focus_data{'start'}  = ($vf_selected->{'start'} - $slice->start);
      $focus_data{'end'}    = ($vf_selected->{'end'} - $slice->start);
      $focus_data{'label'}  = $vf_selected->variation_name;
      $focus_data{'colour'} = 'black';
      $focus_data{'href'}   = $self->href($vf_selected);
      $selected_snp = 1;
      push @snps_data, \%focus_data;
      push @snps, $vf_selected;
    }
    
    if ($vf->variation_name ne $variation) {
      my $score = $ld_data->{$key};
      my $colour_key = $self->colour_key($vf);
      $data{'start'}  = ($vf->{'start'} - $slice->start);
      $data{'end'}    = ($vf->{'end'} - $slice->start);
      $data{'label'}  = $vf->variation_name;
      $data{'colour'} = $self->my_colour($colour_key);
      $data{'href'}   = $self->href($vf,$score);
      $data{'score'}  = $score;
    }
    if (%data) {
      push @snps_data, \%data; 
      push @snps, $vf;
    }
  }

  $self->{'legend'}{'variation_legend'}{$_->display_consequence} ||= $self->get_colour($_) for @snps;

  return [{'features' => \@snps_data}];
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
