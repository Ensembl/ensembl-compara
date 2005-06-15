package Bio::EnsEMBL::GlyphSet::GSV_snps;
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

sub init_label {
  my ($self) = @_;
  return; 
}

sub _init {
  my ($self) = @_;
  my $type = $self->check();
  return unless defined $type;

  return unless $self->strand() == -1;
  my $offset = $self->{'container'}->strand > 0 ? $self->{'container'}->start - 1 :  $self->{'container'}->end + 1;
  my $dir    = $self->{'container'}->strand > 0 ? 1 : -1;
  my $Config        = $self->{'config'};
  my $EXTENT        = $Config->get('_settings','context');
     $EXTENT        = 1e6 if $EXTENT eq 'FULL';
  my $seq_region_name = $self->{'container'}->seq_region_name();
    
  my @transcripts   = $Config->{'transcripts'};
  my $y             = 0;
  my $h             = 8;   #Single transcript mode - set height to 30 - width to 8!
    
  my %highlights;
  @highlights{$self->highlights} = ();    # build hashkeys of highlight list

  my $fontname      = "Tiny";    
  my $pix_per_bp    = $Config->transform->{'scalex'};
  my $bitmap_length = $Config->image_width(); #int($Config->container_width() * $pix_per_bp);

  my $length  = $Config->container_width();
  my $transcript_drawn = 0;
    
  my $voffset = 0;
  my($font_w_bp, $font_h_bp) = $Config->texthelper->px2bp($fontname);
  my $trans_ref = $Config->{'transcript'};
  my $strand = $trans_ref->{'exons'}[0][2]->strand;
  my $transcript = $trans_ref->{'transcript'};

  my @bitmap;
  my $max_row = -1;
  my @tmp;
  foreach my $snpref ( @{$Config->{'snps'}} ) {
    my $location = int( ($snpref->[0]+$snpref->[1])/2 );
    my $snp = $snpref->[2];
    my $cod_snp = $trans_ref->{'snps'}->{$snp->dbID()};
    next unless $cod_snp;
    next if $snp->end < $transcript->start - $EXTENT - $offset;
    next if $snp->start > $transcript->end + $EXTENT - $offset;
    my( $colour, $label );

    if( $cod_snp->consequence_type eq 'SYNONYMOUS_CODING' ) { ## Synonymous
      $colour = 'chartreuse1';
      if( $cod_snp->{'aa_alternatives'} ) {
        @tmp = ( "02:Amino acid: $cod_snp->{'aa_wildtype'} -> $cod_snp->{'aa_alternatives'}", '' );
        $label  = $cod_snp->pep_allele_string;
      } else {
        @tmp = ( "02:Amino acid: $cod_snp->{'aa_wildtype'}", '' );
        $label  = $cod_snp->pep_allele_string;
      }
    } elsif( $cod_snp->consequence_type eq 'NON_SYNONYMOUS_CODING' ) { ## Non-synonymous 
      $colour = 'coral';
      $label  = $cod_snp->pep_allele_string;
      @tmp = ( "02:Amino acid: $cod_snp->{'aa_wildtype'} -> $cod_snp->{'aa_alternatives'}",'' );
    } elsif( $cod_snp->consequence_type eq '01:prem-stop' || $cod_snp->consequence_type eq '01:no-stop' ) { ## Prem-stop
      $colour = 'red';
      $label  = "$cod_snp->{'aa_wildtype'}-$cod_snp->{'aa_alternatives'}";
      @tmp = ( "02:Amino acid: $cod_snp->{'aa_wildtype'} -> $cod_snp->{'aa_alternatives'}",'' );
    } elsif( $cod_snp->consequence_type eq 'FRAMESHIFT_CODING' ) { ## Coding SNP
      $colour = 'gold';
      $label = ' ';
    } elsif( $cod_snp->consequence_type =~ 'UTR' ) { ## UTR SNP
      $colour = 'cadetblue3';  
      $label = ' ';
    } elsif( $cod_snp->consequence_type eq 'INTRONIC' ) {
      $colour = 'grey65';
      $label = ' ';
    } else {
      $colour = 'grey80';
      $label = ' ';
    }
    my $S =  ( $snpref->[0]+$snpref->[1] - $font_w_bp * length( $label ) )/2;
    my $W = $font_w_bp * length( $label );
    my $tglyph = new Sanger::Graphics::Glyph::Text({
      'x'         => $S,
      'y'         => $h + 3,
      'height'    => $font_h_bp,
      'width'     => $W,
      'font'      => $fontname,
      'colour'    => 'black',
      'text'      => $label,
      'absolutey' => 1,
    });
    my $allele =  $snp->allele_string;
    my $chr_start = $snp->start() + $offset;
    my $chr_end   = $snp->end() + $offset;
    my $pos =  $chr_start;
    if( $chr_end < $chr_start ) {
      $pos = "between&nbsp;$chr_end&nbsp;&amp;&nbsp;$chr_start";
    } elsif($chr_end > $chr_start ) {
      $pos = "$chr_start&nbsp;-&nbsp;$chr_end";
    }
    my $href = "/@{[$self->{container}{_config_file_name_}]}/snpview?snp=@{[$snp->variation_name]};source=@{[$snp->source]};chr=$seq_region_name;vc_start=$chr_start";
    my $bglyph = new Sanger::Graphics::Glyph::Rect({
      'x'         => $S - $font_w_bp / 2,
      'y'         => $h + 2,
      'height'    => $h,
      'width'     => $W + $font_w_bp,
      'colour'    => $colour,
      'absolutey' => 1,
      'zmenu' => {
        'caption' => 'SNP '.$snp->variation_name,
        "01:".$cod_snp->consequence_type => '',
        @tmp,
        '11:SNP properties' => $href,
        "12:bp $pos" => '',
        "13:class: ".$snp->var_class => '',
        "14:ambiguity code: ".$snp->ambig_code => '',
        "15:alleles: ".(length($allele)<16 ? $allele : substr($allele,0,14).'..') => ''
      }
    });
    my $bump_start = int($bglyph->{'x'} * $pix_per_bp);
       $bump_start = 0 if ($bump_start < 0);
    my $bump_end = $bump_start + int($bglyph->width()*$pix_per_bp) +1;
       $bump_end = $bitmap_length if ($bump_end > $bitmap_length);
    my $row = & Sanger::Graphics::Bump::bump_row( $bump_start, $bump_end, $bitmap_length, \@bitmap );
    $max_row = $row if $row > $max_row;
    $tglyph->y( $voffset + $tglyph->{'y'} + ( $row * (2+$h) ) + 1 );
    $bglyph->y( $voffset + $bglyph->{'y'} + ( $row * (2+$h) ) + 1 );
    $self->push( $bglyph, $tglyph );
  }
}

sub error_track_name { return EnsWeb::species_defs->AUTHORITY.' transcripts'; }

1;
