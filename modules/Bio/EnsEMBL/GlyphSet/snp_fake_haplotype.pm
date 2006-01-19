package Bio::EnsEMBL::GlyphSet::snp_fake_haplotype;
use strict;
use vars qw(@ISA);

use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);

use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Space;
use Sanger::Graphics::Glyph::Rect;
use Bio::EnsEMBL::GlyphSet;
  
our @ISA = qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) = @_;

  my $Config        = $self->{'config'};
  my $container     = exists $self->{'container'}{'ref'} ? $self->{'container'}{'ref'} : $self->{'container'};
  my @bitmap        = undef;
  my @colours       = qw(chartreuse4 darkorchid4 orange4 deeppink3 dodgerblue4);

  my $pix_per_bp    = $Config->transform->{'scalex'};
  my $strand  = $self->strand();
  my $length  = $container->length;
  my %exons = ();
  my ($w,$th) = $Config->texthelper()->px2bp($Config->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'});
  my ($w2,$th2) = $Config->texthelper()->px2bp('Small');

## First lets draw the reference strand....

  my @snps = @{$Config->{'snps'}};
  my $start = $container->start();
  my $offset = 0;

  my $track_height = $th + 4;

  $self->push(new Sanger::Graphics::Glyph::Space({ 'y' => 0, 'height' => $track_height, 'x' => 1, 'w' => 1, 'absolutey' => 1, }));
  my $strain = "Comparison to reference strain alleles";
  my $bp_textwidth = $w2 * length($strain) * 1.2;
  my $textglyph = new Sanger::Graphics::Glyph::Text({
    'x'          => - $w2*1.2 *17.5,
    'y'          => 1,
    'width'      => $bp_textwidth,
    'height'     => $th2,
    'font'       => 'Small',
    'colour'     => 'black',
    'text'       => $strain,
    'absolutey'  => 1,
   });
  $self->push( $textglyph );
  my $offset+= $th2+4;


  # Get reference strain name:
  my $pop_adaptor = $self->{'container'}->adaptor->db->get_db_adaptor('variation')->get_PopulationAdaptor;
  my $reference_strain_name = $pop_adaptor->get_reference_strain_name();

  foreach my $snp_ref ( @snps ) { 
    my $snp = $snp_ref->[2];
    my( $S,$E ) = ($snp_ref->[0], $snp_ref->[1] );
    $S = 1 if $S < 1;
    $E = $length if $E > $length;

    my $label = $snp->allele_string;
    my @alleles = split "\/", $label;
    my $reference_base = $alleles[0];
    $snp_ref->[3] = { $reference_base => $colours[0] };
    $snp_ref->[4] = $reference_base;
    my $strain = "Reference";
    $strain .= " $reference_strain_name" if $reference_strain_name;
    my $bp_textwidth = $w * length($strain) * 1.2;
    my $textglyph = new Sanger::Graphics::Glyph::Text({
      'x'          => -$w - $bp_textwidth,
      'y'          => $offset+1,
      'width'      => $bp_textwidth,
      'height'     => $th,
      'font'       => $Config->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'},
      'colour'     => 'black',
      'text'       => $strain,
      'absolutey'  => 1,
    });
    $self->push( $textglyph );
    my $bp_textwidth = $w * length($reference_base);
    my $back_glyph = new Sanger::Graphics::Glyph::Rect({
     'x'         => $S-1,
     'y'         => $offset,
     'colour'    => $snp_ref->[3]{$reference_base},
     'bordercolour' => 'black',
     'absolutey' => 1,
     'height'    => $th+2,
     'width'     => $E-$S+1
    });
    $self->push( $back_glyph );
    if( $bp_textwidth < $E-$S+1 ) {
      my $textglyph = new Sanger::Graphics::Glyph::Text({
        'x'          => ( $E + $S - 1 - $bp_textwidth)/2,
        'y'          => $offset+1,
        'width'      => $bp_textwidth,
        'height'     => $th,
        'font'       => $Config->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'},
        'colour'     => 'white',
        'text'       => $reference_base,
        'absolutey'  => 1,
      });
      $self->push( $textglyph );
    }
#    warn join " ", "SNP", keys %{$snp}, "\n";
  }
  my %T; my %C;
  foreach my $t_ref ( @{$Config->{'extra'}} ) {
    my( $strain, $allele_ref, $coverage_ref ) = @$t_ref;
    foreach my $a_ref ( @$allele_ref ) {
      $T{$strain}{ join "::", $a_ref->[2]->{'_variation_id'}, $a_ref->[2]->{'start'} } = $a_ref->[2]->allele_string ;
    }
    foreach my $c_ref ( @$coverage_ref ) {
      push @{ $C{$strain} }, [ $c_ref->[2]->start, $c_ref->[2]->end, $c_ref->[2]->level ];
    }
  }
  foreach my $t_ref ( reverse @{$Config->{'extra'}} ) {
    $offset += $track_height;
    my( $strain, $allele_ref, $coverage_ref ) = @$t_ref;
    my $bp_textwidth = $w * length($strain) * 1.2;
    my $textglyph = new Sanger::Graphics::Glyph::Text({
      'x'          => -$w - $bp_textwidth,
      'y'          => 1+$offset,
      'width'      => $bp_textwidth,
      'height'     => $th,
      'font'       => $Config->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'},
      'colour'     => 'black',
      'text'       => $strain,
      'absolutey'  => 1,
    });
    $self->push( $textglyph );
    foreach my $snp_ref ( @snps ) {
      my $snp = $snp_ref->[2];
      my $st  = $snp->start;
      my $allele_string =  $T{$strain}{ join "::", $snp->{_variation_id}, $st };
      unless( $allele_string ) {
        foreach my $cov ( @{$C{$strain}} ) {
          if( $st >= $cov->[0] && $st <= $cov->[1] ) {
            $allele_string = $snp_ref->[4];
            last;
          }
        }
      }
      my $bp_textwidth = $w * length($allele_string);
      my $colour = undef;
      if( $allele_string ) {
        $colour = $snp_ref->[3]{ $allele_string };
        unless($colour) {
          $colour = $snp_ref->[3]{ $allele_string } = $colours[ scalar(values %{$snp_ref->[3]} )];
        }
      }
      my( $S,$E ) = ($snp_ref->[0], $snp_ref->[1] );
      $S = 1 if $S < 1;
      $E = $length if $E > $length;
      my $back_glyph = new Sanger::Graphics::Glyph::Rect({
        'x'         => $S-1,
        'y'         => $offset,
        'colour'    => $colour,
        'bordercolour' => 'black',
        'absolutey' => 1,
        'height'    => $th+2,
        'width'     => $E-$S+1
      });
      $self->push( $back_glyph );
      if( $allele_string ) {
        if( $bp_textwidth < $E-$S+1 ) {
          my $textglyph = new Sanger::Graphics::Glyph::Text({
            'x'          => ( $E + $S - 1 - $bp_textwidth)/2,
            'y'          => 2+$offset,
            'width'      => $bp_textwidth,
            'height'     => $th,
            'font'       => $Config->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'},
            'colour'     => 'white',
            'text'       => $allele_string,
            'absolutey'  => 1,
          });
          $self->push( $textglyph );
        }
      }
    }
  }
  $self->push(new Sanger::Graphics::Glyph::Space({ 'y' => $offset + $track_height, 'height' => $th+2, 'x' => 1, 'width' => 1, 'absolutey' => 1, }));
}

1;
