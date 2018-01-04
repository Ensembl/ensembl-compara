=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::cactus_hal;

### Draws compara pairwise alignments - see EnsEMBL::Web::ImageConfig
### and E::W::ImageConfig::MultiBottom for usage

use strict;

use List::Util qw(max min);

use EnsEMBL::Draw::Style::Feature::Alignment;

use base qw(EnsEMBL::Draw::GlyphSet);

# Useful for debugging. Should all be 0 in checked-in code.
my $debug_force_cigar   = 1; # CIGAR at all resolutions
my $debug_force_compact = 0; # render_normal -> render_compact

sub init {
  my $self = shift;

  ## Fetch and cache features
  my $data = $self->get_data;
  my $features = $data->[0]{'features'} || [];
 
  ## No features show "empty track line" if option set
  if ($features eq 'too_many') {
    $self->too_many_features;
    return [];
  }
  elsif (!scalar(@$features)) {
    $self->no_features;
    return [];
  }

  ## Set track depth (i.e. number of rows of features)  
  my $depth = $self->depth;
  $depth    = 1e3 unless defined $depth;
  $self->{'my_config'}->set('depth', $depth);

  ## Set track height
  $self->{'my_config'}->set('height', '10');
  
  ## OK, done!
  return $features;
}


sub render_normal {
  my $self = shift;

  return $self->render_compact if $debug_force_compact;

  $self->{'my_config'}->set('bumped', 1);
  $self->{'my_config'}->set('no_join', 1);

  my $data = $self->get_data;
  if (scalar @{$data->[0]{'features'}||[]}) {
    #use Data::Dumper; $Data::Dumper::Sortkeys = 1;
    #warn Dumper($data);
    my $config = $self->track_style_config;
    my $style  = EnsEMBL::Draw::Style::Feature::Alignment->new($config, $data);
    $self->push($style->create_glyphs);
  }
  else {
    $self->no_features;
  }

}

sub render_compact {
  my $self = shift;

  $self->{'my_config'}->set('no_join', 1);
}

sub get_data {
  my $self = shift;
  $self->{'my_config'}->set('DEBUG_RAINBOW', 1); 

  ## Check the cache first
  my $cache_key = $self->my_label;
  if ($self->feature_cache($cache_key)) {
    return $self->feature_cache($cache_key);
  }

  my $ref_sp    = $self->{'config'}->hub->species;
  my $nonref_sp = $self->{'config'}->hub->param('s1');

  my $slice   = $self->{'container'};
  my $compara = $self->dbadaptor('multi',$self->my_config('db'));
  my $mlss_a  = $compara->get_MethodLinkSpeciesSetAdaptor;
  my $mlss_id = $self->my_config('method_link_species_set_id');
  my $mlss    = $mlss_a->fetch_by_dbID($mlss_id);
  my $gab_a   = $compara->get_GenomicAlignBlockAdaptor;

  #Get restricted blocks
  my $gabs = $gab_a->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $slice, undef, undef, 'restrict');

  my @slices      = split(' ',$self->my_config('slice_summary')||'');
  my $strand_flag = $self->my_config('strand');
  my $length      = $slice->length;
  my $strand      = $self->strand;
  my $colour      = $self->my_colour('default');
  $self->{'config'}{'hub'}->param('r1') =~ /:(\d+)\-/;
  my $other_start = $1; 

  my $features = [];
  my $connections = {};
  use Data::Dumper;

  foreach my $gab (@{$gabs||[]}) {
    warn "\n\n### NEXT";
    my $start     = $gab->reference_slice_start;
    my $end       = $gab->reference_slice_end;
    my $nonref    = $gab->get_all_non_reference_genomic_aligns->[0];
    my $nr_start  = $nonref->dnafrag_start - $other_start;
    my $nr_end    = $nonref->dnafrag_end - $other_start;
    my $hseqname  = $nonref->dnafrag->name;
   
    next if $end < 1 || $start > $length;

    ## Build structure from cigar
    my $structures = {};

    ## Only draw CIGAR if really zoomed in!
    if ($self->scalex > 0.2 || $debug_force_cigar) {
      ## Build underlying CIGAR structure
      my %cigars = (
                    'ref'     => $gab->reference_genomic_align->cigar_line,
                    'nonref'  => $nonref->cigar_line,
                    );

      while (my($key, $cigar) = each (%cigars)) {
        warn ">>> CIGAR $cigar";
        ## Skip if it's 100% match
        next unless $cigar =~ /[IDG]/;
        my $cigar_start = 0;
        my $cigar_array = _parse_cigar($cigar);
        foreach (@$cigar_array) {
          my ($length, $type) = @$_;
          my $segment_colour = $type eq 'D' ? 'black' : $colour; 
          push @{$structures->{$key}}, {
                      'start'   => $cigar_start, 
                      'end'     => $cigar_start + $length,
                      'colour'  => $segment_colour,
                    };
          $cigar_start += $length;
        }
      }
    }

    ## Convert into something the drawing code can understand
    my $drawable = {
                    $ref_sp     => {
                                    'start'     => $start, 
                                    'end'       => $end, 
                                    'structure' => $structures->{'ref'},
                                    'colour'    => $colour,
                                    },
                    $nonref_sp  => {'start'     => $nr_start, 
                                    'end'       => $nr_end,
                                    'structure' => $structures->{'nonref'},
                                    'colour'    => $colour,
                                    },
                  };
    warn Dumper($drawable);

=pod
    my @tag = ($gab->reference_genomic_align->original_dbID, $gab->get_all_non_reference_genomic_aligns->[0]->original_dbID);
    @tag = (
      #Need to use original_dbID if GenomicAlign has been restricted
      $gab->reference_genomic_align->dbID() || $gab->reference_genomic_align->original_dbID,
      $gab->get_all_non_reference_genomic_aligns->[0]->dbID() || $gab->get_all_non_reference_genomic_aligns->[0]->original_dbID
    );
=cut

    my @tag = (
                sprintf('%s_%s-%s', $ref_sp, $start, $end),
                sprintf('%s_%s-%s', $nonref_sp, $nr_start, $nr_end),
              );
    #warn ">>> TAG @tag";

    push @$features, $drawable;
  }

  ## Set cache
  my $data = [{'features' => $features, 'connections' => $connections}];
  $self->feature_cache($cache_key, $data);
  return $data;
}

###### PRIVATE METHODS ###########

sub parse_cigar {
## Build CIGAR array from "match/gap" CIGARs in each GenomicAlign.
## (The one good thing we once got automatically from DnaAlignFeatures).
## Based on _convert_GenomicAlignBlocks_into_DnaDnaAlignFeatures, but
## implemented more efficiently.
## @param gab - GenomicAlignBlock
## @return ArrayRef
  my ($self, $gab) = @_;

  my @inputs = map { _split_cigar($_) } (
    $gab->reference_genomic_align->cigar_line,
    $gab->get_all_non_reference_genomic_aligns->[0]->cigar_line
  );

  if ($gab->reference_slice_strand < 0) {
    @inputs = map { [ reverse @$_ ] } @inputs;
  }

  my $out = [];
  while (@{$inputs[0]} and @{$inputs[1]}) {
    my $n = min(map { $_->[0][0] } @inputs);
    my $m = join("",map { ($_->[0][1] eq 'M')?'N':'-' } @inputs);
    $m = { NN => 'M', 'N-' => 'I', '-N' => 'D' }->{$m};
    return undef unless($m);
    push @$out, [$n,$m];

    foreach my $in (@inputs) {
      shift @$in unless $in->[0][0] -= $n;
    }
  }
  return $out;
  #return join("",map { (($_->[0]==1)?'':$_->[0]).$_->[1] } @out);
}

sub _parse_cigar {
# Split CIGAR string into array
  my $cigar = shift;
  my @out;
  while ($cigar =~ s/^(\d*)([A-Z])//) { push @out,[$1||1,$2]; }
  return \@out;
}

# Should we draw a cross rather than a quadrilateral?
sub _should_draw_cross {
  my ($self, $gab) = @_;

  my $this_ori  = $gab->reference_slice_strand;
  my $other_ori = $self->my_config('ori');
  my $nonref    = $gab->get_all_non_reference_genomic_aligns->[0];

  # flipdata -- alignment is interstrand
  # flipview -- views are in opposite orientations
  my $flipdata = ($gab->reference_slice_strand != $nonref->dnafrag_strand);
  my $flipview = (($this_ori == -1) xor ($other_ori == -1));
  return ($flipdata xor $flipview);
}


1;
