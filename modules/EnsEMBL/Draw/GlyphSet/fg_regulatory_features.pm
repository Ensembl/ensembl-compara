=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

use base qw(EnsEMBL::Draw::GlyphSet_simple);

sub my_label { return sprintf 'Reg. Features from cell type %s. Select another using button above?', $_[0]->my_config('cell_line'); }
sub my_empty_label { return sprintf('No Reg. Features from cell type %s. Select another using button above?', $_[0]->my_config('cell_line')); }
sub class    { return 'group'; }

sub features {
  my $self    = shift;
  my $slice   = $self->{'container'}; 
  my $db_type = $self->my_config('db_type') || 'funcgen';
  my $fg_db;

  if (!$slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
    $fg_db = $slice->adaptor->db->get_db_adaptor($db_type);
    
    if (!$fg_db) {
      warn "Cannot connect to $db_type db";
      return [];
    }
  }
  
  return $self->fetch_features($fg_db);
}

sub fetch_features {
  my ($self, $db) = @_;
  my $cell_line = $self->my_config('cell_line');  
  my $rfa       = $db->get_RegulatoryFeatureAdaptor; 
  
  if (!$rfa) {
    warn ("Cannot get get adaptors: $rfa");
    return [];
  }
  
  my $config      = $self->{'config'};

  my $fsets;
  if ($cell_line) {
    my $fsa = $db->get_FeatureSetAdaptor;
    $fsets  = $fsa->fetch_by_name($cell_line);
    my $ega = $db->get_EpigenomeAdaptor;
    my $epi = $ega->fetch_by_name($cell_line);
    $self->{'my_config'}->set('epigenome', $epi);
  }
  my $reg_feats = $rfa->fetch_all_by_Slice($self->{'container'}, $fsets); 

  my $rf_url        = $config->hub->param('rf');
  my $counter       = 0;
  
  if ($rf_url) {
    foreach (@$reg_feats) {
      last if $_->stable_id eq $rf_url;
      $counter++;
    }
    
    if (exists $reg_feats->[$counter]) { 
      unshift @$reg_feats, $reg_feats->[$counter];  # adding the matching regulatory features to the top of the array so that it is drawn first
      splice @$reg_feats, $counter + 1, 1;          # and removing it where it was in the array (counter+1 since we add one more element above)
    }
  }

  if (scalar @{$reg_feats||[]}) {
    my $legend_entries  = $self->{'legend'}{'fg_regulatory_features_legend'}{'entries'} || [];
    my $activities      = $self->{'legend'}{'fg_regulatory_features_legend'}{'activities'} || [];
    foreach (@$reg_feats) {
      my ($key, $is_activity) = $self->colour_key($_);
      if ($is_activity) {
        push @$activities, $key;
      }
      else {
        push @$legend_entries, $key;
      }
    }
    push @$legend_entries, 'promoter_flanking' if scalar @$legend_entries;

    $self->{'legend'}{'fg_regulatory_features_legend'}{'priority'}  ||= 1020;
    $self->{'legend'}{'fg_regulatory_features_legend'}{'legend'}    ||= [];
    $self->{'legend'}{'fg_regulatory_features_legend'}{'entries'}     = $legend_entries;
    $self->{'legend'}{'fg_regulatory_features_legend'}{'activities'}  = $activities;
  }

  return $reg_feats;
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

  my $is_activity = 0;
  my $config      = $self->{'config'};
  my $epigenome = $self->{'my_config'}->get('epigenome');
  if ($epigenome) {
    my $regact    = $f->regulatory_activity_for_epigenome($epigenome);
    if ($regact) {
      my $activity  = $regact->activity;
      if ($activity =~ /^(POISED|REPRESSED|NA)$/) {
        $type = $activity;
        $is_activity = 1;
      }
    }
  }

  return (lc $type, $is_activity);
}

sub tag {
  my ($self, $f) = @_;

  my $hub = $self->{'config'}{'hub'};

  my ($colour_key) = $self->colour_key($f);
  my $colour     = $self->my_colour($colour_key);
  my $flank_colour = $colour;
  if ($colour_key eq 'promoter') {
    $flank_colour = $self->my_colour('promoter_flanking');
  }
  my $epigenome = $self->{'my_config'}->get('epigenome');

  my @result;
  my $loci = [ map { $_->{'locus'} }
     @{$hub->get_query('GlyphSet::RFUnderlying')->go($self,{
      species => $self->{'config'}{'species'},
      type => 'funcgen',
      epigenome => $epigenome,
      feature => $f,
    })}
  ];

  return if $@ || !$loci || !scalar(@$loci);
  my $bound_end  = pop @$loci;
  my $end        = pop @$loci;
  my ($bound_start, $start, @mf_loci) = @$loci;
  if ($bound_start < $start || $bound_end > $end) {
    # Bound start/ends
    push @result, {
      style  => 'rect',
      colour => $flank_colour,
      start  => $bound_start,
      end    => $start
    },{
      style  => 'rect',
      colour => $flank_colour,
      start  => $end,
      end    => $bound_end
    };
  }
  
  # Motif features
  while (my ($mf_start, $mf_end) = splice @mf_loci, 0, 2) { 
    push @result, {
      style  => 'rect',
      colour => 'black',
      start  => $mf_start,
      end    => $mf_end,
      class  => 'group'
    };
  }

  return @result;
}

sub highlight {
  my ($self, $f, $composite, $pix_per_bp, $h) = @_;
  return unless $self->{'config'}->get_option('opt_highlight_feature') != 0;

  my %highlights = map { $_ => 1 } $self->highlights;  
  return unless $highlights{$f->stable_id};
  
  $self->unshift($self->Rect({
    x         => $composite->x - 2/$pix_per_bp,
    y         => $composite->y - 2,
    width     => $composite->width + 4/$pix_per_bp,
    height    => $h + 4,
    colour    => 'highlight2',
    absolutey => 1,
  }));
}

sub href {
  my ($self, $f) = @_;
  
  return $self->_url({
    species =>  $self->species, 
    type    => 'Regulation',
    rf      => $f->stable_id,
    fdb     => 'funcgen', 
    cl      => $self->my_config('cell_line'),  
  });
}

sub title {
  my ($self, $f) = @_;
  my ($colour_key) = $self->colour_key($f);
  return sprintf 'Regulatory Feature: %s; Type: %s; Location: Chr %s:%s-%s', $f->stable_id, ucfirst $colour_key, $f->seq_region_name, $f->start, $f->end;
}

sub export_feature {
  my $self = shift;
  my ($feature, $feature_type) = @_;
  
  return $self->_render_text($feature, $feature_type, { 
    headers => [ 'id' ],
    values  => [ $feature->stable_id ]
  });
}

sub pattern {
  my ($self,$f) = @_;
  my $epigenome = $self->{'my_config'}->get('epigenome');
  return undef unless $epigenome;

  my $regact  = $f->regulatory_activity_for_epigenome($epigenome);
  if ($regact) {
    my $act     = $regact->activity;
    return ['hatch_really_thick','grey90',0] if $act eq 'INACTIVE';
    return ['hatch_really_thick','white',0] if $act eq 'NA';
  }
  return undef;
}

sub feature_label {
  my ($self,$f) = @_;
  my $epigenome = $self->{'my_config'}->get('epigenome');
  return undef unless $epigenome;

  my $regact  = $f->regulatory_activity_for_epigenome($epigenome);
  if ($regact) {
    my $act     = $regact->activity;
    return "{grey30}inactive in this cell line" if $act eq 'INACTIVE';
    return "{grey30}N/A" if $act eq 'NA';
  }
  return undef;
}

sub label_overlay { return 1; }
sub max_label_rows { return $_[0]->my_config('max_label_rows') || 1; }

1;
