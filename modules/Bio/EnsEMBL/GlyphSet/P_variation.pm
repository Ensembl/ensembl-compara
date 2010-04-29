package Bio::EnsEMBL::GlyphSet::P_variation;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my $self = shift;
  
  return $self->render_text if $self->{'text_export'};
  
  my $config     = $self->{'config'};
  my $snps       = $self->cache('image_snps');
  my $x          = 0;
  my $h          = $self->my_config('height') || 4; 
  my $last_indel = '##############';
  my $pix_per_bp = $self->scalex;
  my $t_width    = $h * 0.75 / $pix_per_bp;
  
  $self->_init_bump(undef,  $self->my_config('depth') || 1e6);

  return unless $snps;
  
  foreach my $int (@$snps) {
    $x++;
    
    next if $last_indel eq $int->{'indel'};
    
    if ($int->{'type'} eq 'insert' || $int->{'type'} eq 'delete') {
      my ($in, $out, $end) = $int->{'type'} eq 'insert' ? ($h, 0, 1) : (0, $h, $int->{'length'} - 1);
      my $pos    = $x . ($end ? '-' . ($x + $end) : '');
      my $colour = $self->my_colour('insert');
      
      my $glyph = $self->Poly({
        x         => $x - $t_width,
        y         => 0,
        width     => $t_width * 2,
        points    => [ $x - $t_width, $out, $x, $in, $x + $t_width, $out ],
        colour    => $colour,
        absolutey => 1
      });
      
      my $bump_start = int($glyph->x * $pix_per_bp);
      my $bump_end   = $bump_start + $glyph->width + 3;
      my $row        = $self->bump_row($bump_start, $bump_end);
      
      $glyph->y_transform(1.5 * $row * ($h + 2));
      
      $self->push($glyph);
      
      # use a rectangle for the zmenu hit box because the triangles are hard to click on
      $self->push($self->Rect({
        x         => $x - $t_width,
        y         => $in + (1.5 * $row * ($h + 2)),
        width     => 2 * $t_width,
        height    => $h,
        absolutey => 1,
        title     => sprintf('%sion %s; %s: %s; Position: %d-%d; Length: %d', uc $int->{'type'}, $int->{'snp_id'}, uc $int->{'type'}, $int->{'allele'}, $x, $x + $end, $int->{'length'}),
        href      => $self->_url({
          type   => 'Variation',
          action => 'VariationProtein',
          v      => $int->{'snp_id'},
          vf     => $int->{'vdbid'},
          vtype  => uc $int->{'type'},
          pos    => $pos,
          len    => $int->{'length'},
          indel  => $int->{'allele'}
        })
      }));
      
      $last_indel = $int->{'indel'};
      
      $config->{'P_variation_legend'}{ucfirst $int->{'type'}} ||= {
        colour => $colour,
        shape  => 'Poly'
      };
    } elsif ($int->{'type'} eq 'snp' || $int->{'type'} eq 'syn') {
      my $snp    = '';
      my $type   = 'Synonymous';
      my $colour = $self->my_colour($int->{'type'});
      
      if ($int->{'type'} eq 'snp') {
        $type = 'Non-synonymous';
        $snp  = "Alternative Residues: $int->{'pep_snp'}; ";
      }
      
      $snp .= 'Codon: ';
      
      my $codon;
      
      for my $letter (0..2) {
        my $string = $int->{'ambigcode'}[$letter] ? "[$int->{'ambigcode'}[$letter]]" : $int->{'nt'}[$letter];
        $snp   .= $string;
        $codon .= $string;
      }
      
      my $glyph = $self->Rect({
        x             => $x - $h /2,
        y             => 0,
        width         => $h,
        height        => $h,
        colour        => $colour,
        absolutey     => 1,
        absolutewidth => 1,
        title         => sprintf('%s SNP %s; Type: %s; Residue: %d; %s; Alleles: %s', $type, $int->{'snp_id'}, $int->{'allele'}, $x, $snp, $int->{'allele'}),
        href          => $self->_url({
          type   => 'Variation',
          action => 'VariationProtein',
          v      => $int->{'snp_id'},
          vf     => $int->{'vdbid'},
          res    => $x,
          cod    => $codon,
          ar     => $int->{'pep_snp'},
          al     => $int->{'allele'}
        })
      });
      
      my $bump_start = int($glyph->x * $pix_per_bp);
      my $bump_end   = $bump_start + $glyph->width + 3;
      my $row        = $self->bump_row($bump_start, $bump_end);
      
      $glyph->y($glyph->y + 1.5 * $row * ($h + 2));
      $self->push($glyph);
      
      $config->{'P_variation_legend'}{$type} ||= {
        colour => $colour,
        shape  => 'Rect'
      };
    }
  }
}

sub render_text {
  my $self = shift;
  
  my $container = $self->{'container'};
  my $snps = $self->cache('image_snps');

  return unless $snps;

  my $start = 0;
  my $export;

  foreach (@$snps) {
    $start++;
    
    my $id = $_->{'snp_id'};
    
    next unless $id;
    
    my ($end, $codon, $type);
    
    if ($_->{'type'} eq 'insert' || $_->{'type'} eq 'delete') {
      $end = $_->{'type'} eq 'insert' ? 1 : $_->{'length'};
    } elsif ($_->{'type'} eq 'snp' || $_->{'type'} eq 'syn') {  
      $type = $_->{'type'} eq 'snp' ? 'NON_SYNONYMOUS_CODING' : 'SYNONYMOUS_CODING';
      
      for my $letter (0..2) { 
        $codon .= $_->{'ambigcode'}->[$letter] ? qq{[$_->{'ambigcode'}->[$letter]]} : $_->{'nt'}->[$letter]; 
      }
    } else {
      next;
    }
    
    $export .= $self->_render_text($container, 'Variation', { 
      headers => [ 'variation_name', 'alleles', 'class', 'type', 'alternative_residues', 'codon' ],
      values  => [ $id, $_->{'allele'}, $_->{'type'}, $type, $_->{'pep_snp'}, $codon ]
    }, { 
      start  => $start,
      end    => $start + $end,
      source => $_->{'snp_source'}
    });
  }
  
  return $export;
}

1;
