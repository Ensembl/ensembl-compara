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

package EnsEMBL::Draw::GlyphSet::fg_regulatory_features;

### Draw regulatory features track 

use strict;

use Role::Tiny::With;
with 'EnsEMBL::Draw::Role::Default';

use base qw(EnsEMBL::Draw::GlyphSet);

sub render_normal {
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', ['Feature::MultiBlocks']);
  $self->{'my_config'}->set('display_structure', 1);
  $self->{'my_config'}->set('bumped', 1);
  $self->{'my_config'}->set('height', 12);
  my $data = $self->get_data;
  $self->draw_features($data);
}

sub get_data {
  my $self    = shift;
  my $slice   = $self->{'container'}; 

  ## First, work out if we can even get any data!
  my $db_type = $self->my_config('db_type') || 'funcgen';
  my $db;
  if (!$slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
    $db = $slice->adaptor->db->get_db_adaptor($db_type);
    if (!$db) {
      warn "Cannot connect to $db_type db";
      return [];
    }
  }
  my $rfa = $db->get_RegulatoryFeatureAdaptor; 
  if (!$rfa) {
    warn ("Cannot get get adaptors: $rfa");
    return [];
  }
   
  ## OK, looking good - fetch data from db 
  my $cell_line = $self->my_config('cell_line');  
  my $config      = $self->{'config'};
  if ($cell_line) {
    my $ega = $db->get_EpigenomeAdaptor;
    my $epi = $ega->fetch_by_short_name($cell_line);
    $self->{'my_config'}->set('epigenome', $epi);
  }
  my $reg_feats = $rfa->fetch_all_by_Slice($self->{'container'}); 

  my $drawable        = []; 
  my $entries         = $self->{'legend'}{'fg_regulatory_features_legend'}{'entries'} || {};
  my $activities      = $self->{'legend'}{'fg_regulatory_features_legend'}{'activities'} || {};
  foreach my $rf (@{$reg_feats||[]}) {
    my ($type, $activity)  = $self->colour_key($rf);

    ## Create feature hash for drawing
    my $text    = $self->my_colour($type,'text');

    ## Determine colour and pattern
    my $key     = $activity =~ /active/ ? $type : $activity;
    my $colour  = $self->my_colour($key) || '#e1e1e1';
    my ($pattern, $patterncolour, $bordercolour);
    if ($activity eq 'inactive') {
      $patterncolour  = 'white';
      $pattern        = $self->{'container'}->length > 10000 ? 'hatch_thick' : 'hatch_thicker';
    }
    elsif ($activity eq 'na') {
      $colour       = 'white';
      $bordercolour = 'grey50';
    }

    ## Do legend colours and styles
    unless ($text =~ /unknown/i) {
      my $legend_params = {'colour' => $colour, 'border' => $bordercolour};
      if ($activity eq 'active') {
        $legend_params->{'legend'} = $text;
        $entries->{$key} = $legend_params;
      }
      elsif ($activity eq 'inactive') { ## Only show one generic entry for all inactive features
        $legend_params->{'stripe'}  = $patterncolour;
        $legend_params->{'colour'}  = 'grey80';
        $legend_params->{'legend'}  = 'Activity in epigenome: Inactive';
        $activities->{'inactive'}   = $legend_params;
      }
      else {
        my $label = 'Activity in epigenome: ';
        $label .= $_ eq 'na' ? 'Insufficient evidence' : ucfirst($activity);
        $legend_params->{'legend'} = $label; 
        $activities->{$activity} = $legend_params;
      }
    }

    ## Basic feature
    my $feature = {
        start         => $rf->start,
        end           => $rf->end,
        label         => $text,
        colour        => $colour,
        href          => $self->href($rf),
    };

    if ($pattern || $bordercolour) {
      $feature->{'pattern'}        = $pattern;
      $feature->{'patterncolour'}  = $patterncolour;
      $feature->{'bordercolour'}   = $bordercolour;
    }

    ## Add flanks and motif features, except on Genoverse where it's currently way too slow
    if ($self->{'container'}->length < 1000000) {
      my $appearance = {'colour' => $colour};
      if ($pattern) {
        $appearance->{'pattern'}        = $pattern;
        $appearance->{'patterncolour'}  = $patterncolour;
      }
      my ($extra_blocks, $flank_colour, $has_motifs) = $self->get_structure($rf, $type, $activity, $appearance);
    
      ## Extra legend items as required
      $entries->{'promoter_flanking'} = {'legend' => 'Promoter Flank', 'colour' => $flank_colour} if $flank_colour;
      $entries->{'x_motif'} = {'legend' => 'Motif feature', 'colour' => 'black', 'width' => 4} if $has_motifs;
      $feature->{extra_blocks}  = $extra_blocks;
    }

    ## OK, done
    push @$drawable, $feature;
  }


  $self->{'legend'}{'fg_regulatory_features_legend'}{'priority'}  ||= 1020;
  $self->{'legend'}{'fg_regulatory_features_legend'}{'legend'}    ||= [];
  $self->{'legend'}{'fg_regulatory_features_legend'}{'entries'}     = $entries;
  $self->{'legend'}{'fg_regulatory_features_legend'}{'activities'}  = $activities;

  #use Data::Dumper; warn Dumper($drawable);
  return [{
    features => $drawable,
    metadata => {
      force_strand => '-1',
      default_strand => 1,
      omit_feature_links => 1,
      display => 'normal'
    }
  }];
}

sub features {
  my $self    = shift;
  my $data = $self->get_data;
  return $data->[0]{'features'};
}

sub get_structure {
  my ($self, $f, $type, $activity, $appearance) = @_;
  my $hub       = $self->{'config'}{'hub'};
  my $epigenome = $self->{'my_config'}->get('epigenome') || '';
  my $slice     = $self->{'container'};

  my $start       = $f->start;
  my $end         = $f->end;
  my $bound_start = $f->bound_start;
  my $bound_end   = $f->bound_end;

  my $has_flanking = 0;
  my $flank_different = 0;
  if ($type eq 'promoter' && $activity eq 'active') {
    $appearance->{'colour'} = $self->my_colour('promoter_flanking');
    $flank_different = 1;
  }

  my $extra_blocks = [];
  if ($bound_start < $start || $bound_end > $end) {
    # Bound start/ends
    $bound_start = 0 if $bound_start < 0;
    push @$extra_blocks, {
      start  => $bound_start,
      end    => $start,
      %$appearance
    },{
      start  => $end,
      end    => $bound_end,
      %$appearance
    };
    $has_flanking = 1;
  }

  ## Add motif feature coordinates if any 
  my $has_motifs = 0;
  if ($epigenome && $activity ne 'na' && $activity ne 'inactive') {

    my $mfs;
    ## Check the cache first
    my $cache_key = $f->stable_id;
    if ($self->feature_cache($cache_key)) {
      $mfs = $self->feature_cache($cache_key);
    }

    unless ($mfs) {
      $mfs = eval { $f->get_all_experimentally_verified_MotifFeatures; };
      ## Cache motif features in case we need to draw another regfeats track
      $self->feature_cache($cache_key, $mfs);
    }

    ## Get peaks that overlap this epigenome
    foreach (@$mfs) {
      my $peaks = $_->get_all_overlapping_Peaks_by_Epigenome($epigenome);
      if (scalar @{$peaks||[]}) {
        push @$extra_blocks, {
                              start   => $_->start - $slice->start, 
                              end     => $_->end - $slice->start,
                              colour  => 'black',
                            };
        $has_motifs = 1;
      }
    }
  }
 
  ## Need to pass colour back for use in legend 
  my $flank_colour = ($has_flanking && $flank_different) ? $appearance->{'colour'} : undef;
  return ($extra_blocks, $flank_colour, $has_motifs);
}

sub colour_key {
  my ($self, $f) = @_;
  my $type = $f->feature_type->name;

  if($type =~ /CTCF/i) {
    $type = 'ctcf';
  } elsif($type =~ /Enhancer/i) {
    $type = 'enhancer';
  } elsif($type =~ /Open chromatin/i) {
    $type = 'open_chromatin';
  } elsif($type =~ /TF binding site/i) {
    $type = 'tf_binding_site';
  } elsif($type =~ /Promoter Flanking Region/i) {
    $type = 'promoter_flanking';
  } elsif($type =~ /Promoter/i) {
    $type = 'promoter';
  } else  {
    $type = 'Unclassified';
  }

  my $activity  = 'active';
  my $config    = $self->{'config'};
  my $epigenome = $self->{'my_config'}->get('epigenome');
  if ($epigenome) {
    my $regact = $f->regulatory_activity_for_epigenome($epigenome);
    if ($regact) {
      $activity  = $regact->activity;
    }
  }

  return (lc $type, lc $activity);
}

sub href {
  my ($self, $f) = @_;
 
  my $hub = $self->{'config'}->hub;
  my $page_species = $hub->referer->{'ENSEMBL_SPECIES'};
  my @other_spp_params = grep {$_ =~ /^s[\d+]$/} $hub->param;
  my %other_spp;
  foreach (@other_spp_params) {
    ## If we're on an aligned species, swap parameters around
    if ($hub->param($_) eq $self->species) {
      $other_spp{$_} = $page_species;
    }
    else {
      $other_spp{$_} = $hub->param($_);
    }
  }

  return $self->_url({
    species =>  $self->species, 
    type    => 'Regulation',
    rf      => $f->stable_id,
    fdb     => 'funcgen', 
    cl      => $self->my_config('cell_line'),  
    %other_spp,
  });
}

1;
