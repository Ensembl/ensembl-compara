package Bio::EnsEMBL::GlyphSet::TSV_snps;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Composite;
use Sanger::Graphics::Glyph::Line;
use Sanger::Graphics::Bump;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end);
use Data::Dumper;
use Bio::EnsEMBL::Variation::Utils::Sequence qw(ambiguity_code variation_class);

sub init_label {
  my ($self) = @_;
  return; 
}

sub _init {
  my ($self) = @_;
  my $type = $self->check();
  return unless defined $type;
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
  my $bitmap_length = $Config->image_width(); #int($Config->container_width() * $pix_per_bp);
  my $voffset = 0;
  my @bitmap;

  # Data stuff
  my $colour_map = $Config->get('TSV_snps','colours' );
  my $EXTENT        = $Config->get('_settings','context')|| 1e6;
     $EXTENT        = 1e6 if $EXTENT eq 'FULL';
  my $seq_region_name = $self->{'container'}->seq_region_name();
  my @consequences =  @$consequences_ref;
  warn "######## ERROR arrays should be same length" unless length @$alleles == length @$consequences_ref;


  my $raw_coverage_obj  = $Config->{'transcript'}->{'coverage_obj'};
  my $coverage_level  = $Config->{'transcript'}->{'coverage_level'};
  my @coverage_obj;
  if ( @$raw_coverage_obj ){
    @coverage_obj = sort {$a->[2]->start <=> $b->[2]->start} @$raw_coverage_obj;
  }

  foreach my $allele_ref (  @$alleles ) {
    my $allele = $allele_ref->[2];
    my $conseq_type = shift @consequences;
    next unless $conseq_type;
    next if $allele->end < $transcript->start - $EXTENT;
    next if $allele->start > $transcript->end + $EXTENT;
    if( $transcript->strand != $allele->strand ) {
      my $tmp = join "", @{$conseq_type->alleles};
      $tmp =~tr/ACGT/TGCA/;
      warn "ERROR: Allele call on alleles ", $allele->allele_string, " Allele call on ConsequenceType is different: $tmp" if $allele->allele_string ne $tmp;
    }

    # Alleles (if same as ref, draw empty box )---------------------
    my $aa_change =  $conseq_type->aa_alleles || [];
    my $label  = join "/", @$aa_change;
    my $S =  ( $allele_ref->[0]+$allele_ref->[1] )/2;
    my $width = $font_w_bp * length( $label );
    my $ref_allele = $allele->ref_allele_string();


    if ($ref_allele eq $allele->allele_string) { # if 'negative snp'
       my $bglyph = new Sanger::Graphics::Glyph::Rect({
      'x'         => $S - $font_w_bp / 2,
      'y'         => $height + 2,
      'height'    => $height,
      'width'     => $width + $font_w_bp +4,
      'bordercolour' => 'grey70',
      'absolutey' => 1,
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


    # Type and colour -------------------------------------------
    my $type = $conseq_type->display_consequence;
    my $colour = $colour_map->{$type}->[0];
    my @tmp;
    push @tmp, ("13:amino acid: $aa_change->[0] to $aa_change->[1]", '' ) if $aa_change->[1];

    # Codon - make the letter for the SNP position in the codon bold
    my $codon = $conseq_type->codon;
    if ( $codon ) {
      my $pos = ($conseq_type->cds_start % 3 || 3) - 1;
      $codon =~ s/(\w{$pos})(\w)(.*)/$1<b>$2<\/b>$3/;
      my $strand = $transcript->strand > 0 ? "+" : "-";
      push @tmp, ("11:transcript codon ($strand strand) ".$codon => '');
    }

    # Coverage -------------------------------------------------
    if ($allele->source eq 'Sanger') {
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


    # Draw ------------------------------------------------
    my @res = $self->get_text_width( 0, $label, '', 'font'=>$fontname, 'ptsize' => $fontsize );
    my $W = ($res[2]+4)/$pix_per_bp;

    my $tglyph = new Sanger::Graphics::Glyph::Text({
      'x'         => $S,
      'y'         => $height + 3,
      'height'    => $font_h_bp,
      'width'     => 0,
      'font'      => $fontname,
      'ptsize'    => $fontsize,
      'colour'    => 'black',
      'text'      => $label,
      'absolutey' => 1,
    });
 
    my $offset = $self->{'container'}->strand > 0 ? $self->{'container'}->start - 1 :  $self->{'container'}->end + 1;
    my $chr_start = $allele->start() + $offset;
    my $chr_end   = $allele->end() + $offset;
    my $pos =  $chr_start;
    if( $chr_end < $chr_start ) {
      $pos = "between&nbsp;$chr_end&nbsp;&amp;&nbsp;$chr_start";
    } elsif($chr_end > $chr_start ) {
      $pos = "$chr_start&nbsp;-&nbsp;$chr_end";
    }

    my $href = "/@{[$self->{container}{_config_file_name_}]}/snpview?snp=@{[$allele->variation_name]};source=@{[$allele->source]};chr=$seq_region_name;vc_start=$chr_start";

    my $bglyph = new Sanger::Graphics::Glyph::Rect({
      'x'         => $S - $W / 2,
      'y'         => $height + 2,
      'height'    => $height,
      'width'     => $W,
      'colour'    => $colour,
      'absolutey' => 1,
      'zmenu' => {
        'caption' => 'SNP '.$allele->variation_name,
        "19:".$type => '',
        @tmp,
        "09:alleles: ".( length($ref_allele) <16 ? $ref_allele : substr($ref_allele,0,14).'..')."/".
		  (length($allele->allele_string)<16 ? $allele->allele_string : substr($allele->allele_string,0,14).'..')
		  => '',
	"07:ambiguity code: ".&ambiguity_code(join "|", $allele->ref_allele_string(), $allele->allele_string) => '',
       '01:SNP properties' => $href,
       "03:bp $pos" => '',
       "05:class: ".&variation_class(join "|", $allele->ref_allele_string(), $allele->allele_string) => '',
       "15:source: ". $allele->source => '',
      }
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

1;
