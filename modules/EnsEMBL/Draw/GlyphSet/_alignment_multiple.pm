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

package EnsEMBL::Draw::GlyphSet::_alignment_multiple;

### Draws compara multiple alignments - see EnsEMBL::Web::ImageConfig
### for usage

use strict;

use Time::HiRes qw(time);

use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;

use base qw(EnsEMBL::Draw::GlyphSet_wiggle_and_block);
use List::Util qw(min max);

sub colour { return $_[0]->{'feature_colour'}, $_[0]->{'label_colour'}, $_[0]->{'part_to_colour'}; }

sub wiggle_subtitle { $_[0]->{'subtitle_text'} || $_[0]->my_colour('score','text'); }

sub draw_features {
  ### Called from {{EnsEMBL::Draw::GlyphSet_wiggle_and_block.pm}}
  ### Arg 2 : draws wiggle plot if this is true
  ### Returns 0 if all goes well.  
  ### Returns error message to print if there are features missing (string)

  my ($self, $wiggle) = @_;
  my $strand              = $self->strand;
  my $strand_flag         = $self->my_config('strand');
  my $drawn_block         = 0;
  my $caption             = $self->my_config('caption'); 
  my $length              = $self->{'container'}->length;
  my $pix_per_bp          = $self->scalex;
  my $draw_cigar          = $self->type =~ /constrained/ ? undef : $pix_per_bp > 0.2;
  my $name                = $self->my_config('short_name') || $self->my_config('name');
  my $constrained_element = $self->my_config('constrained_element');
  my $feature_type        = $constrained_element ?  'element' : 'feature';
  my $feature_colour      = $self->my_colour($feature_type);
  my $feature_text        = $self->my_colour($feature_type, 'text' );
     $feature_text        =~ s/\[\[name\]\]/$name/;
  my $h                   = $self->get_parameter('opt_halfheight') ? 4 : 8;
  my $chr                 = $self->{'container'}->seq_region_name;
  my $chr_start           = $self->{'container'}->start;
  my $method_id           = $self->my_config('method_link_species_set_id');
  my $jump_to_alignslice  = $self->my_config('jump_to_alignslice');
  my $class               = $self->my_config('class');
  my $x                   = -1e8;
  my $species = $self->{'container'}->{'web_species'};

  #colours to distinguish alternating features for GenomicAlignBlock objects only 
  my @block_colours;
  if ($constrained_element) {
      @block_colours = ($feature_colour, $feature_colour);
  } else {
      @block_colours =($feature_colour, $self->{'config'}->colourmap->mix($feature_colour,'white',0.5));

  }

  if ($wiggle ne 'wiggle') {

    #Get features and group and sort them
    my $features = $self->element_features();
    my $sorted_features = [];
    if (scalar @{$features||[]}) {
      $sorted_features = $self->build_features_into_sorted_groups($features);

      unless ($constrained_element) {
        #draw containing box around groups
        foreach my $ga_s (@$sorted_features) {
          next unless @$ga_s;
          my $net_composite = $self->draw_containing_box($ga_s, $feature_colour);
          $self->push($net_composite);
        }
      }
    }
  
    my $i = 0;
    foreach my $feat (@{$sorted_features}) {

      #Start and end of a block
      my $block_start = $feat->[0]->{start} + $chr_start - 1;
      my $block_end = $feat->[-1]->{end} + $chr_start - 1;

      #Assign alternating colours to block
      $feature_colour = $block_colours[$i];
      $i = $i ? 0 : 1;

      #want a new zmenu for each block (do not define higher up because some elements are undefined (eg ref_id) and therefore don't overwrite the previous entry)
      my $zmenu  = {
                    type   => 'Location',
                    action => 'MultipleAlignment',
                    align  => $method_id,
                   };

     foreach my $f (@$feat) {
      my $start       = $f->{'start'};
      my $end         = $f->{'end'};
      my ($rs, $re)   = ($f->{'hstart'}, $f->{'hend'});
      ($start, $end)  = ($end, $start) if $end < $start; # Flip start end YUK!
      $start          = 1 if $start < 1;
      $end            = $length if $end > $length;

      next if int($end * $pix_per_bp) == int($x * $pix_per_bp);
      
      $drawn_block = 1;
      $x           = $start;

      # Don't link to AlignSliceView from constrained elements! - doesn't work in 51
      $zmenu->{'align'} = $method_id if $jump_to_alignslice;
      
      # use 'score' param to identify constrained elements track - 
      # in which case we show coordinates just for the block
      if ($constrained_element) {
        $zmenu->{'score'} = $f->{'score'};
        $zmenu->{'ftype'} = 'ConstrainedElement';
        $zmenu->{'id'}    = $f->{'dbID'};

        $block_start = $start + $chr_start - 1;
        $block_end   = $end   + $chr_start - 1;
        $zmenu->{'r'} = "$chr:$block_start-$block_end"; #set ConstrainedElement start and end
      } else {
        $zmenu->{'ftype'}  = 'GenomicAlignBlock';
        $zmenu->{'id'}     = $f->{'dbID'};
        $zmenu->{'r'} = "$chr:$rs-$re"; #only set region start and end for GenomicAlignBlocks
      }
      
      $zmenu->{'n0'} = "$chr:$block_start-$block_end"; #set block start and end
      
      if ($draw_cigar) {
        my $to_push = $self->Composite({
          href         => $self->_url($zmenu),
          x            => $start - 1,
          width        => 0,
          y            => 0,
          bordercolour => $feature_colour
        });
        
        $self->draw_cigar_feature({
          composite      => $to_push, 
          feature        => $f, 
          height         => $h, 
          feature_colour => $feature_colour, 
          delete_colour  => 'black', 
          scalex         => $pix_per_bp
        });
        
        $self->push($to_push);
      } else {
        $self->push($self->Rect({
          x         => $start - 1,
          y         => 0,
          width     => $end - $start + 1,
          height    => $h,
          colour    => $feature_colour,
          absolutey => 1,
          _feature  => $f, 
          href      => $self->_url($zmenu),
        }));
      }
     }
    }
    
    $self->_offset($h);
    if($drawn_block) {
      $self->{'subtitle_colour'} ||= $feature_colour;
      $self->{'subtitle_text'} = $feature_text;
    }
  }
  
  my $drawn_wiggle = $wiggle ? $self->wiggle_plot : 1;
  
  return 0 if $drawn_block && $drawn_wiggle;

  # Work out error message if some data is missing
  my @errors;

  push @errors, $self->my_colour($feature_type, 'text') if !$drawn_block;
  push @errors, $self->my_colour('score',       'text') if $wiggle && !$drawn_wiggle;
  
  s/\[\[name\]\]/$feature_text/ for @errors;
  
  return join ' and ', @errors;
}

## Now generate the feature array refs...

sub element_features {
  ### Retrieves block features for constrained elements
  ### Returns arrayref of features
  
  my $self  = shift;
  my $slice = $self->{'container'};
  my ($features, @rtn);
  
  if ($slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
    return $slice->{'_align_slice'}->get_all_ConstrainedElements;
  }

  my  $db                  = $self->dbadaptor('multi', $self->my_config('db'));
  my $constrained_element = $self->my_config('constrained_element');
  my $adaptor             = $db->get_adaptor($constrained_element ? 'ConstrainedElement' :  'GenomicAlignBlock');
  my $id                  = $constrained_element || $self->my_config('method_link_species_set_id');
  my $restrict            = 1;

  # Avoid Building MLSS cache. Saves almost a second on region in detail.
  # We should ask Compara to help us out with a cache-free _objs_to_sth.
  #  --dps
  my $mlss_ids = $self->species_defs->multi_hash->{'DATABASE_COMPARA'}->{'MLSS_IDS'};
  my $mlss_conf = $mlss_ids->{$id};
  return [] unless keys %{$mlss_conf||{}};

  my $ss = eval {$db->get_adaptor('SpeciesSet')->_uncached_fetch_by_dbID($mlss_conf->{'SPECIES_SET'})};
  return [] if $@;

  ## Get file URL (only needed by HAL alignments) 
  my $sd = $self->{'config'}->hub->species_defs;
  my $datafile_root = $sd->DATAFILE_ROOT.'/'.$sd->SUBDOMAIN_DIR;;
  my $ma = $db->get_adaptor('MethodLinkSpeciesSet');
  $ma->base_dir_location($datafile_root);
  my $url = $mlss_conf->{'URL'};

  my $ml = $db->get_adaptor('Method')->_uncached_fetch_by_dbID($mlss_conf->{'METHOD_LINK'});

  my $mlss = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
    -DBID         => $id,
    -ADAPTOR      => $ma,
    -METHOD       => $ml,
    -SPECIES_SET  => $ss,
    -URL          => $url
  );

  $features = $adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $slice, undef, undef, $restrict) || [];
  
  foreach my $feature (@$features) {
    my ($rtype, $gpath, $rname, $rstart, $rend, $rstrand) = split ':', $feature->slice->name;
    my $group_id = 0;
    $group_id = $feature->group_id unless ($constrained_element);
    my $cigar_line = $feature->reference_genomic_align->cigar_line unless ($constrained_element);

    my $is_low_coverage_species = 0;
    unless ($constrained_element) {
        # The species is not low-coverage if it's been used in one of the EPO alignments
        $is_low_coverage_species = !scalar( grep {($_->{type} eq 'EPO') && $_->{species}->{$self->species}}
                                            values %{$sd->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'}}
                                          );
    }

    
    push @rtn, Bio::EnsEMBL::DnaDnaAlignFeature->new_fast({
      dbID      => $feature->{'dbID'} || $feature->{'_original_dbID'},
      ref_id    => $feature->{'reference_genomic_align_id'},
      seqname   => $feature->slice->name,
      start     => $feature->start,
      end       => $feature->end,
      cigar_string => $cigar_line,
      strand    => 0,
      hseqname  => $rname,
      hstart    => $rstart,
      hend      => $rend,
      hstrand   => $rstrand,
      score     => $feature->score,
      group_id  => $group_id,
      extra_data => $is_low_coverage_species, #store whether this is a low_coverage species in extra_data field
    });
  }

  return \@rtn;
}

sub score_features {
  my $self  = shift;
  my $slice = $self->{'container'};

  return $slice->display_Slice_name eq $slice->{'web_species'} ? $slice->{'_align_slice'}->get_all_ConservationScores($self->image_width) : [] if $slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice');
  
  my $K  = $self->my_config('conservation_score');
  my $db = $self->dbadaptor('multi', $self->my_config('db'));
  
  return [] unless $K && $db;
  
  my $method_link_species_set = $db->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($K);
  
  return [] unless $method_link_species_set;

  return $db->get_ConservationScoreAdaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($method_link_species_set, $self->{'container'}, $self->image_width) || [];
}

sub wiggle_plot {
  ### Wiggle_plot
  ### Description: gets features for wiggle plot and passes to render_wiggle_plot
  ### Returns 1 if draws wiggles. Returns 0 if no wiggles drawn
  
  my $self     = shift;
  my $features = $self->score_features;
  
  return 0 unless scalar @$features;

  my $min_score = 0;
  my $max_score = 0;
  
  foreach (@$features) {
    my $s = $_->score;
    $min_score = $s if $s < $min_score;
    $max_score = $s if $s > $max_score;
  }
  
  $self->draw_wiggle_plot($features, { min_score => $min_score, max_score => $max_score });
  
  return 1;
}


# Features are grouped and rendered together
sub build_features_into_sorted_groups {
    my ($self,$feats) = @_;
  
    my $container   = $self->{'container'};
    my $strand      = $self->strand;
    my $strand_flag = $self->my_config('strand'); 
    my $length      = $container->length;
    my $method_link_species_set_id = $self->my_config('method_link_species_set_id');
    my $species = $self->my_config('name');
    my $part = ($strand == 1) || 0;
    my %out;
    my $k = 0;

    #Group features on group_id or the block dbID for low coverage species. Otherwise do not group
    foreach my $feat (@{$feats||[]}) {
        my $start = $feat->{start};
        my $end = $feat->{end};
        next if $end < 1 || $start > $length;
        #    next if $strand_flag eq 'b'; 

        #Set whether this is a low coverage species
        my $is_low_coverage_species = $feat->{extra_data};

        #Only group togther on dbID if low coverage species
        my $key;
        if ($is_low_coverage_species) {
            $key = ($feat->{group_id} || $feat->{dbID}); 
        } else {
            $key = ($feat->{group_id} || $k++);
        }

        push @{$out{$key}{'feats'}},[$start,$feat];
    }

    # sort contents of groups by start
    foreach my $g (values %out) {
        my @f = map {$_->[1]} sort { $a->[0] <=> $b->[0] } @{$g->{'feats'}};
        $g->{'len'} = max(map { $_->{end}   } @f) - min(map { $_->{start} } @f);
        $g->{'start'} = min(map { $_->{start} } @f);
        $g->{'feats'} = \@f;
    }
    
    #order by start
    return
      [ map { $_->{'feats'} } sort { $a->{'start'} <=> $b->{'start'} } values %out ];
}

# Draws out box of groups (hollow box)
sub draw_containing_box {
  my ($self,$feats, $feature_colour) = @_;

  my $ga_first = $feats->[0];
  my $ga_last = $feats->[-1];

  my $feature_key    = lc $self->my_config('type');
  my $h              = $self->get_parameter('opt_halfheight') ? 4 : 8;
  my $feature_colour = $feature_colour;
  my $container      = $self->{'container'};
  my $length         = $container->length;
  my $ga_first_start = $ga_first->{start};
  my $ga_last_end    = $ga_last->{end};
  my $width = $ga_last_end;
  if ($width > $length) {
    $width = $length;
  }
  if ($ga_first_start > 0) {
      $width -= $ga_first_start - 1;
  }

  my $net_composite = $self->Composite({
                                        x     => $ga_first_start > 1 ? $ga_first_start - 1 : 0,
                                        y     => 0,
                                        width => $width,
                                        height => $h,
                                        bordercolour => $feature_colour,
                                        absolutey => 1,
                                       });
  return $net_composite;

}

1;
