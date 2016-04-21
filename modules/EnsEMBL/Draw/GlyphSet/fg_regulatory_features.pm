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
  my $fsa       = $db->get_FeatureSetAdaptor; 
  
  if (!$fsa) {
    warn ("Cannot get get adaptors: $fsa");
    return [];
  }
  
  my $config        = $self->{'config'};
  my ($feature_set) = grep $_->cell_type->name =~ /\Q$cell_line\E/, @{$fsa->fetch_all_displayable_by_type('regulatory')};
  my $reg_feats     = $feature_set ? $feature_set->get_Features_by_Slice($self->{'container'}) : [];
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

  if (scalar @$reg_feats) {
    my $legend_entries = [];
    foreach (@$reg_feats) {
      my $key = $self->colour_key($_);
      push $legend_entries, $key;
      push $legend_entries, 'promoter_flanking';
    }
    if(grep { $_ eq 'promoter' } @$legend_entries) {
    }
    $self->{'legend'}{'fg_regulatory_features_legend'} ||= { priority => 1020, legend => [], entries => $legend_entries };	
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
  if($f->can('activity')) {
    my $activity = $f->activity;
    # case 0: handled by pattern code
    # case 1: correct
    if($activity == 4) {
      $type = 'na';
    } elsif($activity == 2) {
      $type = 'poised';
    } elsif($activity == 3) {
      $type = 'repressed';
    }
  }
  return lc $type;
}

sub tag {
  my ($self, $f) = @_;
  my $colour_key = $self->colour_key($f);
  my $colour     = $self->my_colour($colour_key);
  my $flank_colour = $colour;
  if($colour_key eq 'promoter') {
    $flank_colour = $self->my_colour('promoter_flanking');
  }
  my @loci       = @{$f->get_underlying_structure};
  my $bound_end  = pop @loci;
  my $end        = pop @loci;
  my ($bound_start, $start, @mf_loci) = @loci;
  my @result;
 
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

sub render_tag {
  my ($self, $tag, $composite, $slice_length, $height, $start, $end) = @_;
  
  if ($tag->{'style'} eq 'fg_ends') {
    my $f_start = $tag->{'start'} || $start;
    my $f_end   = $tag->{'end'}   || $end;
       $f_start = 1             if $f_start < 1;
       $f_end   = $slice_length if $f_end   > $slice_length;
       
    $composite->push($self->Rect({
      x         => $f_start - 1,
      y         => $height / 2,
      width     => $f_end - $f_start + 1,
      height    => 0,
      colour    => $tag->{'colour'},
      absolutey => 1,
      zindex    => 0
    }), $self->Rect({
      x       => $f_start - 1,
      y       => 0,
      width   => 0,
      height  => $height,
      colour  => $tag->{'colour'},
      zindex => 1
    }), $self->Rect({
      x      => $f_end,
      y      => 0,
      width  => 0,
      height => $height,
      colour => $tag->{'colour'},
      zindex => 1
    }));
  }
  
  return;
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
  return sprintf 'Regulatory Feature: %s; Type: %s; Location: Chr %s:%s-%s', $f->stable_id, ucfirst $self->colour_key($f), $f->seq_region_name, $f->start, $f->end;
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

  return undef unless $f->can('activity');
  my $act = $f->activity;
  return ['hatch_really_thick','grey90',0] if $act==0;
  return ['hatch_really_thick','white',0] if $act==4;
  return undef;
}

sub feature_label {
  my ($self,$f) = @_;

  return undef unless $f->can('activity');
  my $act = $f->activity;
  return "{grey30}inactive in this cell line" if $act==0;
  return "{grey30}N/A" if $act==4;
  return undef;
}

sub label_overlay { return 1; }
sub max_label_rows { return $_[0]->my_config('max_label_rows') || 1; }

1;
