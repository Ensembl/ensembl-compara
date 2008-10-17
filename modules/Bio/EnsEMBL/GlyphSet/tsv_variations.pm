package Bio::EnsEMBL::GlyphSet::tsv_variations;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Bump;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end);
use Data::Dumper;
use Bio::EnsEMBL::Variation::Utils::Sequence qw(ambiguity_code variation_class);

sub _init {
  my ($self) = @_;
  my $check = $self->check();
  return unless defined $check;
  return unless $self->strand() == -1;

  my $Config        = $self->{'config'};  
  my $transcript = $Config->{'transcript'}->{'transcript'}; 
  my $consequences_ref = $Config->{'transcript'}->{'consequences'};
  my $alleles      = $Config->{'transcript'}->{'allele_info'};
  return unless $alleles && $consequences_ref;

  # Drawing params
  my( $fontname, $fontsize ) = $self->get_font_details( 'innertext' );
  my $pix_per_bp    = $Config->transform->{'scalex'};
  my @res = $self->get_text_width( 0, 'M', '', 'font'=>$fontname, 'ptsize' => $fontsize );
  my( $font_w_bp, $font_h_bp) = ($res[2]/$pix_per_bp,$res[3]);
  my $height = $res[3] + 4;   

  # Bumping params
  my $pix_per_bp    = $Config->transform->{'scalex'};
  my $bitmap_length = int($Config->container_width() * $pix_per_bp);
  my $voffset = 0;
  my @bitmap;

  # Data stuff
  my $colour_map = $self->my_config('colours');
  my $EXTENT        = $Config->get_parameter( 'context')|| 1e6;
     $EXTENT        = 1e6 if $EXTENT eq 'FULL';
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

    # Alleles (if same as ref, draw empty box )---------------------
    my $aa_change =  $conseq_type->aa_alleles || []; 
    my $label  = join "/", @$aa_change; 
    my $S =  ( $allele_ref->[0]+$allele_ref->[1] )/2;
    my $width = $font_w_bp * length( $label );

    # Note: due to some bizarre API caching, the allele->allele_string is incorrect here
    # The alleles from conseq_type need to be used instead. 
    my $ref_allele = $allele->ref_allele_string();
    my @conseq_alleles = @{$conseq_type->alleles || [] };
    if ($allele->strand != $transcript->strand) {
      map {tr/ACGT/TGCA/} @conseq_alleles;
    }
    warn "Consequence alleles has more than one alt allele" if $#conseq_alleles > 0;


    # Type and colour -------------------------------------------
    my $type = lc($conseq_type->display_consequence); 
    my $colour;
    if ($type eq 'sara') {
      $colour = $colour_map->{$type}->{'border'}; 
    } else {
      $colour = $colour_map->{$type}->{'default'}; 
    }

    my @tmp;

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
	push @tmp, ("17:resequencing coverage: $coverage" => '');
      }
    }


    # SARA snps ----------------------------------------------------
    if ($ref_allele eq $conseq_alleles[0]) { # if 'negative snp'
       my $bglyph = $self->Rect({
      'x'         => $S - $font_w_bp / 2,
      'y'         => $height + 2,
      'height'    => $height,
      'width'     => $width + $font_w_bp +4,
      'bordercolour' => 'grey70',
      'absolutey' => 1,
      'zmenu'     => $self->zmenu($allele, $type, $ref_allele, $conseq_alleles[0], \@tmp),
      'zindex'    => -4,
     });
      my $bump_start = int($bglyph->{'x'} * $pix_per_bp);
      $bump_start = 0 if ($bump_start < 0);
      my $bump_end = $bump_start + int($bglyph->width()*$pix_per_bp) +1;
      $bump_end = $bitmap_length if ($bump_end > $bitmap_length);
      my $row = & Sanger::Graphics::Bump::bump_row( $bump_start, $bump_end, $bitmap_length, \@bitmap );
      $bglyph->y( $voffset + $bglyph->{'y'} + ( $row * (2+$height) ) + 1 );
      $self->push( $bglyph );
      next;
    }

    # Normal SNPs
    push @tmp, ("13:amino acid: $aa_change->[0] to $aa_change->[1]", '' ) if $aa_change->[1];

    # Codon - make the letter for the SNP position in the codon bold
    my $codon = $conseq_type->codon;
    if ( $codon ) {
      my $pos = ($conseq_type->cds_start % 3 || 3) - 1;
      $codon =~ s/(\w{$pos})(\w)(.*)/$1<b>$2<\/b>$3/;
      my $strand = $transcript->strand > 0 ? "+" : "-";
      push @tmp, ("11:transcript codon ($strand strand) ".$codon => '');
    }


    # Draw ------------------------------------------------
    my @res = $self->get_text_width( 0, $label, '', 'font'=>$fontname, 'ptsize' => $fontsize );
    my $W = ($res[2]+4)/$pix_per_bp;

    my $tglyph = $self->Text({
      'x'         => $S-$res[2]/$pix_per_bp/2,
      'y'         => $height + 3,
      'height'    => $font_h_bp,
      'width'     => $res[2]/$pix_per_bp,
      'textwidth' => $res[2],
      'font'      => $fontname,
      'ptsize'    => $fontsize,
      'colour'    => 'black',
      'text'      => $label,
      'absolutey' => 1,
    });

    my $bglyph = $self->Rect({
      'x'         => $S - $W / 2,
      'y'         => $height + 2,
      'height'    => $height,
      'width'     => $W,
      'colour'    => $colour,
      'absolutey' => 1,
      'zmenu'     => $self->zmenu($allele, $type, $ref_allele, $conseq_alleles[0], \@tmp),
    });

    my $bump_start = int($bglyph->{'x'} * $pix_per_bp);
       $bump_start = 0 if ($bump_start < 0);
    my $bump_end = $bump_start + int($bglyph->width()*$pix_per_bp) +1;
       $bump_end = $bitmap_length if ($bump_end > $bitmap_length);
    my $row = & Sanger::Graphics::Bump::bump_row( $bump_start, $bump_end, $bitmap_length, \@bitmap );

    $tglyph->y( $voffset + $tglyph->{'y'} + ( $row * (2+$height) ) + 1 );
    $bglyph->y( $voffset + $bglyph->{'y'} + ( $row * (2+$height) ) + 1 );
    $self->push( $bglyph, $tglyph );
  }
}

sub error_track_name { return $_[0]->species_defs->AUTHORITY.' transcripts'; }

sub zmenu {
  my ($self, $allele, $type, $ref_allele, $alt_allele, $tmp)  = @_;
  # Href
  my $offset = $self->{'container'}->strand > 0 ? $self->{'container'}->start - 1 :  $self->{'container'}->end + 1;
  my $chr_start = $allele->start() + $offset;
  my $chr_end   = $allele->end() + $offset;
  my $pos =  $chr_start;
  if( $chr_end < $chr_start ) {
    $pos = "between&nbsp;$chr_end&nbsp;&amp;&nbsp;$chr_start";
    } elsif($chr_end > $chr_start ) {
      $pos = "$chr_start&nbsp;-&nbsp;$chr_end";
    }
  my $seq_region_name = $self->{'container'}->seq_region_name();
  my $href = "/@{[$self->{container}{web_species}]}/snpview?snp=@{[$allele->variation_name]};source=@{[$allele->source]};chr=$seq_region_name;vc_start=$chr_start";
	
  my $strain = $self->species_defs->translate("strain");
  my $zmenu = {
	       'caption'               => 'SNP '.$allele->variation_name,
	       "19:".$type             => '',
	       @$tmp,
               "09:reference allele: ".( length($ref_allele) <16 ? $ref_allele : substr($ref_allele,0,14).'..') 
                                       => '',
	       "10:$strain genotype: ".(length($alt_allele)<16 ? $alt_allele : substr($alt_allele,0,14).'..')
                                       => '',
	       '01:SNP properties'     => $href,
	       "03:bp $pos"            => '',
	       "05:class: ".&variation_class(join "|", $ref_allele, $alt_allele) 
                                       => '',
	       "15:source: ". (join ", ", @{$allele->get_all_sources ||[]}) 
	                               => '',
	      };

 $zmenu->{"11:ambiguity code: ".&ambiguity_code(join "|", $ref_allele, $alt_allele)} = "" unless $type eq 'SARA';

  return ($zmenu || {});
}


1;
