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
  my $fontname      = $Config->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'};
  my($font_w_bp, $font_h_bp) = $Config->texthelper->px2bp($fontname);
  my $height = $font_h_bp + 4;  #Single transcript mode: height= 30, width=8

  # Bumping params
  my $pix_per_bp    = $Config->transform->{'scalex'};
  my $bitmap_length = $Config->image_width(); #int($Config->container_width() * $pix_per_bp);
  my $voffset = 0;
  my @bitmap;
  my $max_row = -1;

  # Data stuff
  my $colour_map = $Config->get('TSV_snps','colours' );
  my $EXTENT        = $Config->get('_settings','context');
     $EXTENT        = 1e6 if $EXTENT eq 'FULL';
  my $seq_region_name = $self->{'container'}->seq_region_name();
  my @consequences =  @$consequences_ref;
  warn "######## ERROR arrays should be same length" unless length @$alleles == length @$consequences_ref;


  my $raw_coverage_obj  = $Config->{'transcript'}->{'coverage_obj'};
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

    # Type and colour -------------------------------------------
    my $type = $conseq_type->type;
    my $colour = $colour_map->{$type}->[0];

    my $aa_change =  $conseq_type->aa_alleles || [];
    my @tmp;
    if ( my $aa2 = $aa_change->[1] ) {
      #$aa_change->[1] = lc( $aa2 ) if $type eq 'SYNONYMOUS_CODING';
      push @tmp, ("05:Amino acid: $aa_change->[0] to $aa_change->[1]", '' );
    }

    # Codon - make the letter for the SNP position in the codon bold
    my $codon = $conseq_type->codon;
    if ( $codon ) {
      my $pos = ($conseq_type->cds_start % 3 || 3) - 1;
      $codon =~ s/(\w{$pos})(\w)(.*)/$1<b>$2<\/b>$3/;
      my $strand = $transcript->strand > 0 ? "+" : "-";
      push @tmp, ("04:Transcript codon ($strand strand) ".$codon => '');
    }

    # Coverage -------------------------------------------------
    my $coverage = 0;
    foreach ( @coverage_obj ) {
      next if $allele->start >  $_->[2]->end;
      last if $allele->start < $_->[2]->start;
      $coverage = $_->[2]->level if $_->[2]->level > $coverage;
    }
    push @tmp, ("07:Read coverage: $coverage" => '') if $coverage;

    my $label  = join "/", @$aa_change;
    if ( (my $splice = $conseq_type->splice_site) =~ s/_/ /g) {
      $type .= "- $splice";
      $colour = $colour_map->{'SPLICE_SITE'}->[0] if $conseq_type->type eq "INTRONIC";
    }
    if ($conseq_type->regulatory_region()) {
      $type .= "- Regulatory region SNP";
      $colour = $colour_map->{'REG_REGION'}->[0];
    }

    # Draw ------------------------------------------------
    my $S =  ( $allele_ref->[0]+$allele_ref->[1] - $font_w_bp * length( $label ) )/2;
    my $width = $font_w_bp * length( $label );
    my $tglyph = new Sanger::Graphics::Glyph::Text({
      'x'         => $S,
      'y'         => $height + 3,
      'height'    => $font_h_bp,
      'width'     => $width,
      'font'      => $fontname,
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
    my $ref_allele = $allele->ref_allele_string();
    my $bglyph = new Sanger::Graphics::Glyph::Rect({
      'x'         => $S - $font_w_bp / 2,
      'y'         => $height + 2,
      'height'    => $height,
      'width'     => $width + $font_w_bp + 4,
      'colour'    => $colour,
      'absolutey' => 1,
      'zmenu' => {
        'caption' => 'SNP '.$allele->variation_name,
        "01:".$type => '',
        @tmp,
        "02:Ref/sample allele: ".( length($ref_allele) <16 ? $ref_allele : substr($ref_allele,0,14).'..')."/".
		  (length($allele->allele_string)<16 ? $allele->allele_string : substr($allele->allele_string,0,14).'..')
		  => '',
	"03:Ambiguity code: ".&ambiguity_code(join "|", $allele->ref_allele_string(), $allele->allele_string) => '',
       '11:SNP properties' => $href,
       "12:bp $pos" => '',
       "13:class: ".&variation_class(join "|", $allele->ref_allele_string(), $allele->allele_string) => '',
      }
    });
    my $bump_start = int($bglyph->{'x'} * $pix_per_bp);
       $bump_start = 0 if ($bump_start < 0);
    my $bump_end = $bump_start + int($bglyph->width()*$pix_per_bp) +1;
       $bump_end = $bitmap_length if ($bump_end > $bitmap_length);
    my $row = & Sanger::Graphics::Bump::bump_row( $bump_start, $bump_end, $bitmap_length, \@bitmap );
    $max_row = $row if $row > $max_row;
    $tglyph->y( $voffset + $tglyph->{'y'} + ( $row * (2+$height) ) + 1 );
    $bglyph->y( $voffset + $bglyph->{'y'} + ( $row * (2+$height) ) + 1 );
    $self->push( $bglyph, $tglyph );
  }
}

sub error_track_name { return $_[0]->species_defs->AUTHORITY.' transcripts'; }

1;
