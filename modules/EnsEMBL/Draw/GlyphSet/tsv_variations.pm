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

package EnsEMBL::Draw::GlyphSet::tsv_variations;

### Track to draw variations at top of Transcript/Population/Image

use strict;

use EnsEMBL::Draw::Utils::Bump;
use Bio::EnsEMBL::Variation::Utils::Sequence qw(ambiguity_code);

use base qw(EnsEMBL::Draw::GlyphSet);

sub _init {
  my ($self) = @_;
  my $check = $self->type;
  return unless defined $check;
  return unless $self->strand() == -1;

  my $Config            = $self->{'config'};
  my $transcript        = $Config->{'transcript'}->{'transcript'};
  my $consequences_ref  = $Config->{'transcript'}->{'consequences'};
  my $alleles           = $Config->{'transcript'}->{'allele_info'};
  return unless $alleles && $consequences_ref;

  # Drawing params
  my( $fontname, $fontsize )  = $self->get_font_details( 'innertext' );
  my $pix_per_bp              = $Config->transform_object->scalex;
  my @res                     = $self->get_text_width( 0, 'M', '', 'font'=>$fontname, 'ptsize' => $fontsize );
  my( $font_w_bp, $font_h_bp) = ($res[2]/$pix_per_bp,$res[3]);
  my $height                  = $res[3] + 4;

  # Bumping params
  my $bitmap_length = int($Config->container_width() * $pix_per_bp);
  my $voffset = 0;
  my @bitmap;

  # Data stuff
  my $colour_map  = $self->my_config('colours');
  my $EXTENT      = $Config->get_parameter( 'context')|| 1e6;
     $EXTENT      = 1e6 if $EXTENT eq 'FULL';
  warn "######## ERROR arrays should be same length" unless length @$alleles == length @$consequences_ref;


  my $raw_coverage_obj  = $Config->{'transcript'}->{'coverage_obj'};
  my $coverage_level  = $Config->{'transcript'}->{'coverage_level'};
  my @coverage_obj;
  if ( @$raw_coverage_obj ){
    @coverage_obj = sort {$a->[2]->start <=> $b->[2]->start} @$raw_coverage_obj;
  }

  my $index = 0;
  foreach my $allele_ref (  @$alleles ) {
    my $allele = $allele_ref->[2];
    my $conseq_type = $consequences_ref->[$index];
    $index++;
    next unless $conseq_type && $allele;
    next if $allele->end < $transcript->start - $EXTENT;
    next if $allele->start > $transcript->end + $EXTENT;

    # Type and colour -------------------------------------------
    my $type = lc($conseq_type->display_consequence);
    my $colour;
    if ($type eq 'sara') {
      $colour = $colour_map->{$type}->{'border'};
    } else {
      $colour = $colour_map->{$type}->{'default'};
    }

    # Alleles (if same as ref, draw empty box )---------------------
    my $var_pep  = $type eq 'sara' ? '' : ($conseq_type->pep_allele_string || '');
    $var_pep =~ s/\//\|/g;
    my $aa_change;
    @$aa_change = split /\|/, $var_pep;
    my $S =  ( $allele_ref->[0]+$allele_ref->[1] )/2;
    my $width = $font_w_bp * length( $var_pep );

    my $ref_allele = $allele->ref_allele_string();
    # get the feature seq from each TVA
    # this will come flipped if transcript is on opposite strand to feature
    my @conseq_alleles = map {$_->feature_seq} @{$conseq_type->get_all_alternate_TranscriptVariationAlleles};
    warn "Consequence alleles has more than one alt allele" if $#conseq_alleles > 0;

    my $c;
    # Coverage -------------------------------------------------
    if ( grep { $_ eq "Sanger"}  @{$allele->get_all_sources() || []}  ) {
      my $coverage = 0;
      foreach ( @coverage_obj ) {
        next if $allele->start >  $_->[2]->end;
        last if $allele->start < $_->[2]->start;
        $coverage = $_->[2]->level if $_->[2]->level > $coverage;
      }
      if ($coverage) {
        $coverage = ">".($coverage-1) if $coverage == $coverage_level->[-1];
        $c= $coverage;
      }
    }

    my $allele_id = $allele->variation_name;
    my $dbid      = $allele->variation ? $allele->variation->dbID : undef or next;
    my $href_sara = $self->_url({
      'type'        => 'Transcript',
      'action'      => 'TranscriptVariation',
      'v'           => $allele_id,
      'vf'          => $dbid,
      'alt_allele'  => $allele->allele_string,#$conseq_alleles[0],
      'sara'        => 1,
    });

    # SARA snps ----------------------------------------------------
    if ($type eq 'sara') { # if 'negative snp'
       my $bglyph = $self->Rect({
      'x'             => $S - $font_w_bp / 2,
      'y'             => $height + 2,
      'height'        => $height,
      'width'         => $width + $font_w_bp +4,
      'bordercolour'  => 'grey70',
      'absolutey'     => 1,
      'href'          => $href_sara,
     });
      my $bump_start = int($bglyph->{'x'} * $pix_per_bp);
      $bump_start = 0 if ($bump_start < 0);
      my $bump_end = $bump_start + int($bglyph->width()*$pix_per_bp) +1;
      $bump_end = $bitmap_length if ($bump_end > $bitmap_length);
      my $row = & EnsEMBL::Draw::Utils::Bump::bump_row( $bump_start, $bump_end, $bitmap_length, \@bitmap );
      $bglyph->y( $voffset + $bglyph->{'y'} + ( $row * (2+$height) ) + 1 );
      $self->push( $bglyph );
      next;
    }

    # Normal SNPs
    # we need to get the original allele
    my $ref_tva = $conseq_type->{_alleles_by_seq}->{$ref_allele};
    my $ref_pep = $ref_tva->peptide;

    my $ref_codon = $ref_tva->codon;
    my $var_codon = $conseq_type->codons;
    $var_codon =~ s/\//\|/g;

    my $aa;
    $aa = "$ref_pep to $var_pep" if defined $ref_pep and defined $var_pep;
    my $codon = "$ref_codon $var_codon" if defined $ref_codon and defined $var_codon;

    # Draw ------------------------------------------------
    my @res = $self->get_text_width( 0, $var_pep, '', 'font'=>$fontname, 'ptsize' => $fontsize );
    my $W = ($res[2]+4)/$pix_per_bp;

    my $href = $self->_url({
      'type'        => 'Transcript',
      'action'      => 'TranscriptVariation',
      'v'           => $allele_id,
      'vf'          => $dbid,
      'alt_allele'  => $allele->allele_string,#$conseq_alleles[0],
      'aa_change'   => $aa,
      'cov'         => $c,
      'codon'       => $codon,
    });

    my $tglyph = $self->Text({
      'x'         => $S-$res[2]/$pix_per_bp/2,
      'y'         => $height + 3,
      'height'    => $font_h_bp,
      'width'     => $res[2]/$pix_per_bp,
      'textwidth' => $res[2],
      'font'      => $fontname,
      'ptsize'    => $fontsize,
      'colour'    => 'black',
      'text'      => $var_pep,
      'absolutey' => 1,
    });

    my $bglyph = $self->Rect({
      'x'         => $S - $W / 2,
      'y'         => $height + 2,
      'height'    => $height,
      'width'     => $W,
      'colour'    => $colour,
      'absolutey' => 1,
      'href'      => $href,
    });

    my $bump_start = int($bglyph->{'x'} * $pix_per_bp);
       $bump_start = 0 if ($bump_start < 0);
    my $bump_end = $bump_start + int($bglyph->width()*$pix_per_bp) +1;
       $bump_end = $bitmap_length if ($bump_end > $bitmap_length);
    my $row = & EnsEMBL::Draw::Utils::Bump::bump_row( $bump_start, $bump_end, $bitmap_length, \@bitmap );

    $tglyph->y( $voffset + $tglyph->{'y'} + ( $row * (2+$height) ) + 1 );
    $bglyph->y( $voffset + $bglyph->{'y'} + ( $row * (2+$height) ) + 1 );
    $self->push( $bglyph, $tglyph );
  }
}

sub title {
  my($self,$f) = @_;
  my $vid = $f->variation_name;
  my $type = $f->display_consequence;
  my $dbid = $f->dbID;
  my ($s,$e) = $self->slice2sr( $f->start, $f->end );
  my $loc = $s == $e ? $s
          : $s <  $e ? $s.'-'.$e
          :           "Between $s and $e"
          ;
  return "Variation: $vid; Location: $loc; Consequence: $type; Ambiguity code: ".$f->ambig_code;
}

sub error_track_name { return $_[0]->species_defs->AUTHORITY.' transcripts'; }
1;
