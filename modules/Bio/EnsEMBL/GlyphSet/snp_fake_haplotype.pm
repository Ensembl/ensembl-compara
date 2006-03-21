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
  my @snps = @{$Config->{'snps'}};
  return unless scalar @snps;

  my ($w,$th) = $Config->texthelper()->px2bp($Config->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'});

  my $track_height = $th + 4;
  $self->push(new Sanger::Graphics::Glyph::Space({ 'y' => 0, 'height' => $track_height, 'x' => 1, 'w' => 1, 'absolutey' => 1, }));

  # Get reference strain name for start of track:
  my $pop_adaptor = $self->{'container'}->adaptor->db->get_db_adaptor('variation')->get_PopulationAdaptor;
  my $reference_name = $Config->{'reference'} || $pop_adaptor->get_reference_strain_name();

  my $info_text = "Comparison to reference $reference_name strain alleles (green = same allele; purple = different allele)";

  my ($small_w, $small_th) = $Config->texthelper()->px2bp('Small');
  my $textglyph = new Sanger::Graphics::Glyph::Text({
    'x'          => - $small_w*1.2 *17.5,
    'y'          => 1,
    'width'      => $small_w * length($info_text) * 1.2,
    'height'     => $small_th,
    'font'       => 'Small',
    'colour'     => 'black',
    'text'       => $info_text,
    'absolutey'  => 1,
   });
  $self->push( $textglyph );


  $reference_name = "Reference $reference_name"; 
  my $ref_bp_textwidth = $w * length($reference_name) * 1.2;
  my $offset = $small_th + 4;
  my $textglyph = new Sanger::Graphics::Glyph::Text({
      'x'          => -$w - $ref_bp_textwidth,
      'y'          => $offset+1,
      'width'      => $ref_bp_textwidth,
      'height'     => $th,
      'font'       => $Config->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'},
      'colour'     => 'black',
      'text'       => $reference_name,
      'absolutey'  => 1,
    });
  $self->push( $textglyph );


  ## First lets draw the reference SNPs....
  my $length     = exists $self->{'container'}{'ref'} ? $self->{'container'}{'ref'}->length : $self->{'container'}->length;
  my @colours       = qw(chartreuse4 darkorchid4);# orange4 deeppink3 dodgerblue4);s

  foreach my $snp_ref ( @snps ) { 
    my $snp = $snp_ref->[2];
    my( $start, $end ) = ($snp_ref->[0], $snp_ref->[1] );
    $start = 1 if $start < 1;
    $end = $length if $end > $length;

    my $label = $snp->allele_string;
    my @alleles = split "\/", $label;
    my $reference_base = $alleles[0];
    $snp_ref->[3] = { $reference_base => $colours[0] };
    $snp_ref->[4] = $reference_base;


    my $alleles_bp_textwidth = $w * length("$label");
    my $strain_bp_textwidth  = $w * length($alleles[0]) ;

    my $tmp_width = $alleles_bp_textwidth + $w*4;
    if ( ($end - $start + 1) > $tmp_width ) {
      $start = ( $end + $start-$tmp_width )/2;
      $end =  $start+$tmp_width ;
    }

    my $back_glyph = new Sanger::Graphics::Glyph::Rect({
     'x'         => $start-1,
     'y'         => $offset,
     'colour'    => $snp_ref->[3]{$reference_base},
     'bordercolour' => 'black',
     'absolutey' => 1,
     'height'    => $th+2,
     'width'     => $end-$start+1
    });
    $self->push( $back_glyph );

    if ( ($end-$start+1) > $strain_bp_textwidth ) {
      my $textglyph = new Sanger::Graphics::Glyph::Text({
        'x'          => ( $end + $start - 1 - $strain_bp_textwidth)/2,
        'y'          => $offset+1,
        'width'      => $alleles_bp_textwidth,
        'height'     => $th,
        'font'       => $Config->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'},
        'colour'     => 'white',
        'text'       => $reference_base,
        'absolutey'  => 1,
      });
      $self->push( $textglyph );
    }
  } #end foreach $snp_ref


   # Now draw SNPs for each strain
   my %strain_alleles;   # $strain_alleles{strain}{id::start} = allele
   my %coverage;         # $coverage{strain} = [ [start, end, level], [start, end, level]   ];

  foreach my $data ( @{$Config->{'snp_fake_haplotype'}} ) {
    my( $strain, $allele_ref, $coverage_ref ) = @$data;
    foreach my $a_ref ( @$allele_ref ) {
      $strain_alleles{$strain}{ join "::", $a_ref->[2]->{'_variation_id'}, $a_ref->[2]->{'start'} } = $a_ref->[2]->allele_string ;
    }
    foreach my $c_ref ( @$coverage_ref ) {
      push @{ $coverage{$strain} }, [ $c_ref->[2]->start, $c_ref->[2]->end, $c_ref->[2]->level ];
    }
  }
   foreach my $data ( reverse @{$Config->{'snp_fake_haplotype'}} ) {
     $offset += $track_height;
     my( $strain ) = @$data;

    # Write strain names
    my $strain_bp_textwidth = $w * length($strain) * 1.2;
    my $textglyph = new Sanger::Graphics::Glyph::Text({
      'x'          => -$w - $strain_bp_textwidth,
      'y'          => 1+$offset,
      'width'      => $strain_bp_textwidth,
      'height'     => $th,
      'font'       => $Config->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'},
      'colour'     => 'black',
      'text'       => $strain,
      'absolutey'  => 1,
    });
    $self->push( $textglyph );

     foreach my $snp_ref ( @snps ) {
       my $snp = $snp_ref->[2];
       my $start  = $snp->start;
       my $allele_string =  $strain_alleles{$strain}{ join "::", $snp->{_variation_id}, $start };
       unless( $allele_string ) {
         foreach my $cov ( @{$coverage{$strain}} ) {
           if( $start >= $cov->[0] && $start <= $cov->[1] ) {
             $allele_string = $snp_ref->[4];
             last;
           }
         }
       }
       my $alleles_bp_textwidth = $w * length($snp->allele_string);
       my $strain_bp_textwidth = $w * length($allele_string||1) ;
       my $colour = undef;
      if( $allele_string ) {
        $colour = $snp_ref->[3]{ $allele_string };
        unless($colour) {
          $colour = $snp_ref->[3]{ $allele_string } = $colours[ scalar(values %{$snp_ref->[3]} )] || $colours[-1];
        }
       }
      my( $S,$E ) = ($snp_ref->[0], $snp_ref->[1] );
      $S = 1 if $S < 1;
      $E = $length if $E > $length;

       my $tmp_width = $alleles_bp_textwidth + $w*4;
       if ( ($E - $S + 1) > $tmp_width ) {
	 $S = ( $E + $S-$tmp_width )/2;
	 $E =  $S+$tmp_width ;
       }
       my $back_glyph = new Sanger::Graphics::Glyph::Rect({
         'x'         => $S-1,
         'y'         => $offset,
         'colour'    => $colour,
         'bordercolour' => 'black',
         'absolutey' => 1,
         'height'    => $th+2,
         'width'     => $E-$S+1,
         'absolutey' => 1,
 	});
       $self->push( $back_glyph );

       if ( ($E-$S+1)  >$strain_bp_textwidth) {
	 my $textglyph = new Sanger::Graphics::Glyph::Text({
            'x'          => ( $E + $S - 1 - $strain_bp_textwidth)/2,
            'y'          => 2+$offset,
            'width'      => $alleles_bp_textwidth,
            'height'     => $th,
            'font'       => $Config->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'},
            'colour'     => 'white',
            'text'       => $allele_string,
            'absolutey'  => 1,
          }) if $allele_string;
	 $self->push( $textglyph ) if defined $textglyph;
       }
     }
   }
   $self->push(new Sanger::Graphics::Glyph::Space({ 'y' => $offset + $track_height, 'height' => $th+2, 'x' => 1, 'width' => 1, 'absolutey' => 1, }));
}

1;
