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

package EnsEMBL::Draw::GlyphSet::contig;

### Draw contig track (normally alternating blocks of light and dark blue)

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

sub _init {
  my $self = shift;
  
  return $self->render_text if $self->{'text_export'};
  
  # only draw contigs once - on one strand
  if ($self->species_defs->NO_SEQUENCE) {
    $self->errorTrack('Clone map - no sequence to display');
    return;
  }
  
  my ($fontname, $fontsize) = $self->get_font_details('innertext');
  my $container  = $self->{'container'};
  my $length     = $container->length;
  my $h          = [ $self->get_text_width(0, 'X', '', font => $fontname, ptsize => $fontsize) ]->[3];
  my $box_h      = $self->my_config('h');
  my $pix_per_bp = $self->scalex;
  my $features   = $self->features;
  
  if (!$box_h) {
    $box_h = $h + 4;
  } elsif ($box_h < $h + 4) {
    $h = 0;
  }
  
  foreach (0, $box_h) {
    $self->push($self->Rect({
      x         => 0,
      y         => $_,
      width     => $length,
      height    => 0,
      colour    => 'grey50',
      absolutey => 1,
    }));
  }
  
  if (scalar @$features) {
    $self->init_contigs($h, $box_h, $fontname, $fontsize, $features);
  } else {
    $self->errorTrack($container->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice') && $self->get_parameter('compara') ne 'primary' ? 'Alignment gap - no contigs to display' : 'Golden path gap - no contigs to display');
  }
}

sub init_contigs {
  my ($self, $h, $box_h, $fontname, $fontsize, $contig_tiling_path) = @_;
  my $length               = $self->{'container'}->length;
  my $pix_per_bp           = $self->scalex;
  my $threshold_navigation = ($self->my_config('threshold_navigation') || 2e6) * 1001;
  my $navigation           = $self->my_config('navigation') || 'on';
  my $show_navigation      = $length < $threshold_navigation && $navigation eq 'on';
  my $species              = $self->species;
  my @colours              = ('contigblue1', 'contigblue2');
  my $label_colour         = 'white';
  
  # Draw the Contig Tiling Path
  foreach (sort { $a->{'start'} <=> $b->{'start'} } @$contig_tiling_path) {
    my $strand = $_->strand;
    my $end    = $_->{'end'};
    my $start  = $_->{'start'};
    my $region = $_->{'name'};
    
    # AlignSlice segments can be on different strands - hence need to check if start & end need a swap
    ($start, $end) = ($end, $start) if $start > $end;
    $start = 1 if $start < 1;
    $end   = $length if $end > $length;
    
    $self->push($self->Rect({
      x         => $start - 1,
      y         => 0,
      width     => $end - $start + 1,
      height    => $box_h,
      colour    => $colours[0],
      absolutey => 1,
      title     => $region,
      href      => $show_navigation && $species ne 'ancestral_sequences' ? $self->href($_) : ''
    }));

    push @colours, shift @colours;

    my $w_px = ($end-$start+1)*$pix_per_bp;
    if ($h and $w_px > 50) {
      my @res = $self->get_text_width(($end - $start) * $pix_per_bp, $self->feature_label($_), $strand > 0 ? '>' : '<', font => $fontname, ptsize => $fontsize);
      
      if ($res[0]) {
        $self->push($self->Text({
          x         => ($end + $start - $res[2] / $pix_per_bp) / 2,
          height    => $res[3],
          width     => $res[2] / $pix_per_bp,
          textwidth => $res[2],
          y         => ($h - $res[3]) / 2,
          font      => $fontname,
          ptsize    => $fontsize,
          colour    => $label_colour,
          text      => $res[0],
          absolutey => 1
        }));
      }
    }
  }
}

sub render_text {
  my $self = shift;
  
  return if $self->species_defs->NO_SEQUENCE;
  
  my $export;  
  
  foreach (@{$self->features}) {
    $export .= $self->_render_text($_, 'Contig', { headers => [ 'id' ], values => [ $_->{'name'} ] }, {
      seqname => $_->seq_region_name,
      start   => $_->start, 
      end     => $_->end, 
      strand  => $_->strand
    });
  }
  
  return $export;
}

sub features {
  my $self      = shift;
  my $container = $self->{'container'};
  my $adaptor   = $container->adaptor;
  my @features;
  
  foreach (@{$container->project('seqlevel') || []}) {
    my $slice = Bio::EnsEMBL::Slice->new_fast({%{$_->to_Slice}}); 
    $slice->{'name'}  = $slice->coord_system->name eq 'ancestralsegment' ? $slice->{'_tree'} : $slice->seq_region_name; # This is a Slice of Ancestral sequences: display the tree instead of the ID;
    $slice->{'start'} = $_->from_start;
    $slice->{'end'}   = $_->from_end;
    
    push @features, $slice;
  }
  
  return \@features;
}

sub href {
  my ($self, $f) = @_;
  my $offset = $self->{'container'}->start - 1;
  
  return $self->_url({
    species => $self->species,
    type    => 'Location',
    action  => 'Contig',
    region  => $f->{'name'},
    r       => sprintf('%s:%s-%s', $self->{'container'}->seq_region_name, $f->start + $offset, $f->end + $offset)
  });
}

sub feature_label {
  my ($self, $f) = @_;
  return $f->strand == 1 ? "$f->{'name'} >" : "< $f->{'name'}";
}

1;
