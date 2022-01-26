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

package EnsEMBL::Draw::GlyphSet::alignscalebar;

### Draws scalebar for Location/Compara_Alignments/Image - standard
### black'n'white scalebar, with aligned slice beneath shown as
### coloured blocks in shades of pink

use strict;

use base qw(EnsEMBL::Draw::GlyphSet::scalebar);

sub render {
  my $self = shift;

  my $container     = $self->{'container'};  
  my $contig_strand = $container->can('strand') ? $container->strand : 1;
  my $strand        = $self->strand;
  my $compara       = $self->get_parameter('compara');
  
  my $global_start = $contig_strand < 0 ? -$container->end : $container->start;
  my $global_end   = $contig_strand < 0 ? -$container->start : $container->end;
  
  $self->label($self->Text({ text => '' })) if $strand < 0;
  
  $self->render_align_gap($global_start, $global_end);
  $self->render_align_bar($global_start, $global_end, 5);
  $self->SUPER::render($strand > 0 ? 0 : 20) if $strand > 0;
  
  # Draw the species separator line
  if ($strand > 0 && $compara ne 'primary') {
    $self->push($self->Line({
      x             => -120,
      y             => -24,
      colour        => 'black',
      width         => 20000,
      height        => 0,
      absolutex     => 1,
      absolutewidth => 1,
      absolutey     => 1
    }));
  }
}

# Display gaps in AlignSlices
sub render_align_gap {
  my $self = shift;
  my ($global_start, $global_end) = @_;

  my $container = $self->{'container'};
  my $y = $self->strand > 0 ? 8 : 2;
  
  my $cigar_arrayref = $container->get_cigar_arrayref;

  # Display only those gaps that amount to more than 1 pixel on screen, otherwise screen gets white when you zoom out too much
  my $min_length = 1 / $self->scalex;

  my @inters = @$cigar_arrayref;
  
  my $cigar_num = 0;
  my $box_start = 0;
  my $box_end   = 0;
  my $colour    = 'white';
  my $join_z    = -10;

  while (@inters) {
    $cigar_num = shift @inters || 1;
    
    my $cigar_type = shift @inters;
    
    $box_end = $box_start + $cigar_num - 1;

    # Skip normal alignment (M) and gaps in between alignment blocks (G)
    if ($cigar_type !~ /G|M/) {
      
      if ($cigar_num > $min_length) { 
        my $glyph = $self->Rect({
          x         => $box_start,
          y         => $y,
          z         => $join_z,
          width     => $cigar_num,
          height    => 3,
          colour    => $colour, 
          absolutey => 1
        });
        
        if ($self->{'strand'} < 0) {
          $self->join_tag($glyph, "alignsliceG_$box_start", 0, 0, $colour, 'fill', $join_z);
          $self->join_tag($glyph, "alignsliceG_$box_start", 1, 0, $colour, 'fill', $join_z);
        } else {
          $self->join_tag($glyph, "alignsliceG_$box_start", 1, 1, $colour, 'fill', $join_z);
          $self->join_tag($glyph, "alignsliceG_$box_start", 0, 1, $colour, 'fill', $join_z);
        }
        
        $self->push($glyph);
      }
    }
    
    $box_start = $box_end + 1;
  }
}

# Display AlignSlice bars
sub render_align_bar {
  my $self = shift;
  
  my ($global_start, $global_end, $yc) = @_;
  
  my $config      = $self->{'config'};
  my $species     = $self->species;
  my $pix_per_bp  = $self->scalex;
  my $last_end    = undef;
  my $last_chr    = -1;
  my $last_slice  = undef;
  my $join_z      = -20;
  my $last_s2s    = -1;
  my $last_s2e    = -1;
  my $last_s2st   = 0;

  my %colour_map;
  my %colour_map2;
  my @colours = qw(antiquewhite1 mistyrose1 burlywood1 khaki1 cornsilk1 lavenderblush1 lemonchiffon2 darkseagreen2 lightcyan1 papayawhip seashell1);
  
  foreach my $s (sort {$a->{'start'} <=> $b->{'start'}} @{$self->{'container'}->get_all_Slice_Mapper_pairs(1)}) {
    my $s2        = $s->{'slice'};
    my $ss        = $s->{'start'};
    my $sst       = $s->{'strand'};
    my $se        = $s->{'end'};
    my $s2s       = $s2->{'start'};
    my $s2e       = $s2->{'end'};
    my $s2st      = $s2->{'strand'};
    my $s2t       = $s2->{'seq_region_name'};
    my $s2sp      = $s2->adaptor->db->species if($s2->adaptor);
    my $box_start = $ss;
    my $box_end   = $se;
    my $filled    = $sst;
    my $s2l       = abs($s2e - $s2s) + 1;
    my $sl        = abs($se - $ss) + 1;
    my ($title, $href);
    
    if ($s2t eq 'GAP') {
      $title = 'AlignSlice; Gap in the alignment';
    } elsif ($species eq 'ancestral_sequences') {
      $title = "AlignSlice; ID: $s2t; $s2->{'_tree'}";
    } else {
      $href = $self->_url({ 
        species  => $species,
        action   => 'Align',
        r        => "$s2t:$s2s-$s2e",
        strand   => $s2st,
        interval => "$ss-$se"
      });
    }
    
    $colour_map{$s2t}  ||= shift @colours || 'grey';
    $colour_map2{$s2t} ||= 'darksalmon';
    
    my $col  = $colour_map{$s2t};
    my $col2 = $colour_map2{$s2t};
    
    my $glyph = $self->Rect({
      x         => $box_start - $global_start, 
      y         => $yc,
      width     => abs($box_end - $box_start + 1),
      height    => 3,
      absolutey => 1,
      title     => $title,
      href      => $href,
      ($filled == 1 ? 'colour' : 'bordercolour') => $col2
    });
    
    if ($self->{'strand'} < 0) {
      $self->join_tag($glyph, "alignslice_$box_start", 0, 0, $col, 'fill', $join_z);
      $self->join_tag($glyph, "alignslice_$box_start", 1, 0, $col, 'fill', $join_z);
    } else {
      $self->join_tag($glyph, "alignslice_$box_start", 1, 1, $col, 'fill', $join_z);
      $self->join_tag($glyph, "alignslice_$box_start", 0, 1, $col, 'fill', $join_z);
    }
    
    $self->push($glyph);

    my $species_defs  = $config->{'hub'}->species_defs;
    my $map           = $species_defs->multi_val('ENSEMBL_SPECIES_URL_MAP');
    my $ref_species   = $map->{$species};
    my $other_species = $map->{$s2sp}; 

    my $ref_species_common_name = lc $species_defs->get_config($ref_species, 'SPECIES_DISPLAY_NAME');
    my $other_species_common_name = lc $species_defs->get_config($other_species, 'SPECIES_DISPLAY_NAME') || '';
    
    # This happens when we have two slices following each other
    if (defined $last_end and ($last_end <= $ss - 1)) {
      my $s3l = $s2st == -1 && $last_s2st == -1 ? $last_s2s - $s2e + 1 : $s2s - $last_s2e - 1;
      my $xc  = $box_start - $global_start - ($ss-$last_end)/2;
      my $h   = $yc - 2;
      my $colour;
      my $legend;
      
      $href = '';
      
      if ($last_chr ne $s2t) {
       if ($s2 && $s2->has_karyotype && $last_slice && $last_slice->has_karyotype) {
        # Different chromosomes
        $colour = 'black';
        $title = "AlignSlice Break; There is a breakpoint in the alignment between chromosome $last_chr and $s2t";
        $legend = "Breakpoint between $other_species_common_name chromosomes";
       }
      } elsif ($last_s2st ne $s2st) {
        # Same chromosome, different strand (inversion)
        $colour = 'dodgerblue';
        $title = "AlignSlice Break; There is an inversion in chromosome $s2t";
        $legend = "Inversion on the $other_species_common_name chromosome";
      } elsif ( (($last_end == $ss-1) && ($s3l > 0)) or ($s3l == 0) ) {
        # Same chromosome, same strand, gap in only 1 genome (blocks are adjacent in the other)
        my ($from, $to);
        
        $colour = 'red';
        $title = sprintf('Gap in the %s genome', $s3l ? $other_species_common_name : $ref_species_common_name);
        $legend = 'Indel (> 50 bp)';
        
        if ($s2st == 1) {
          $from = $last_s2e;
          $to = $s2s;
        } else {
          $from = $s2e;
          $to = $last_s2s;
        }
        
        ($from, $to) = ($to, $from) if $from > $to;
        
        $href = $self->_url({ species => $species, action => 'Align', r => "$s2t:$from-$to", break => 1 });
      } elsif ($s3l < 0 ) {
        # Same chromosome, same strand, inverted order in the target species
        $colour = 'yellowgreen';
        $title = "AlignSlice Break; There is a breakpoint in the alignment on chromosome $s2t";
        $legend = "Shuffled blocks on the $other_species_common_name chromosome";
      } else {
        # Gap in both genomes
        #warn "else s3l=$s3l last_end=$last_end ss=$ss diff=".($ss-$last_end-1)."\n";
      }
      
      my $base = $self->strand == 1 ? $h - 3 : $h + 9;
      
      $self->push($self->Triangle({
        colour    => $colour,
        absolutey => 1,
        title     => $title,
        href      => $href,
        mid_point => [ $xc, $h + 3 ],
        width     => 4 / $pix_per_bp,
        height    => 6,
        direction => $self->strand == 1 ? 'down' : 'up'
      })) if $legend;
      
      $config->{'alignslice_legend'}{$colour} = {
        priority => $self->_pos,
        legend   => $legend
      } if $legend && $self->{container}->coord_system()->version() !~ /(EPO|PECAN)/;
    }
    
    $last_end = $se;
    $last_s2s = $s2s;
    $last_s2e = $s2e;
    $last_s2st = $s2st;
    $last_chr = $s2t;
    $last_slice = $s2;
  }
  
  # alignment legend for multiple alignment (show everything)
  if ($self->{container}->coord_system()->version() =~ /(EPO|PECAN)/) { 
    my $all_legend = [
                   { colour => 'black', title => 'AlignSlice Break; Breakpoint in alignment', legend => 'Breakpoint between chromosomes'},
                   { colour => 'dodgerblue', title => 'AlignSlice Break; Inversion in chromosome', legend => 'Inversion on chromosome'},      
                   { colour => 'red', title => 'Gap in genome', legend => 'Indel (> 50 bp)'},      
                   { colour => 'yellowgreen', title => 'AlignSlice Break; Breakpoint in alignment', legend => 'Shuffled blocks on chromosome'},      
    ];

    for my $row (@$all_legend) {     
      my $colour = $row->{colour};
      $config->{'alignslice_legend'}{$colour} = {
        priority => $self->_pos,
        legend   => $row->{legend}
      };
    }
  }   
}

1;
