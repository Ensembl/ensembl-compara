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

  # Get reference strain name for start of track:
  my $pop_adaptor = $self->{'container'}->adaptor->db->get_db_adaptor('variation')->get_PopulationAdaptor;
  my $golden_path =  $pop_adaptor->get_reference_strain_name();
  my $reference_name = $Config->{'reference'} || $golden_path;


  # Get allele and coverage data from config -----------------------------
  my %strain_alleles;   # $strain_alleles{strain}{id::start} = allele
  my %coverage;         # $coverage{strain} = [ [start, end, level], [start, end, level]   ];

  foreach my $data ( @{$Config->{'snp_fake_haplotype'}} ) {
    my( $strain, $allele_ref, $coverage_ref ) = @$data;
    $strain_alleles{$strain} = {};  # every strain should be in here
    foreach my $a_ref ( @$allele_ref ) {
      $strain_alleles{$strain}{ join "::", $a_ref->[2]->{'_variation_id'}, $a_ref->[2]->{'start'} } = $a_ref->[2]->allele_string ;
    }
    foreach my $c_ref ( @$coverage_ref ) {
      push @{ $coverage{$strain} }, [ $c_ref->[2]->start, $c_ref->[2]->end, $c_ref->[2]->level ];
    }
  }

  # Default to Ensembl golden path ref strain if chosen "ref" strain isn't selected on the display
  $reference_name = $golden_path unless $strain_alleles{$reference_name};


  # Info text ---------------------------------------------------------
  my $info_text = "Comparison to reference $reference_name strain alleles (green = same allele; purple = different allele)";

  my ($w,$th) = $Config->texthelper()->px2bp($Config->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'});
  my $track_height = $th + 4;
  $self->push(new Sanger::Graphics::Glyph::Space({ 'y' => 0, 'height' => $track_height, 'x' => 1, 'w' => 1, 'absolutey' => 1, }));

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



  # Reference track ----------------------------------------------------
  my $offset = $small_th + 4;
  my @colours       = qw(chartreuse4 darkorchid4);# orange4 deeppink3 dodgerblue4);

  $self->strain_name_text($w, $th, $offset, "Reference $reference_name", $Config);


  # First lets draw the reference SNPs....
  foreach my $snp_ref ( @snps ) {
    my $snp = $snp_ref->[2];
    my $label =  $snp->allele_string;

    my ($golden_path_base) = split "\/", $label;
    my ($reference_base, $colour);

    if ($reference_name eq $golden_path) {
      $reference_base = $golden_path_base;
    }
    else {
      return unless $strain_alleles{$reference_name};
      my $start  = $snp->start;
      $reference_base =  $strain_alleles{$reference_name}{ join "::", $snp->{_variation_id}, $start };

      # If no allele for SNP but there is coverage, allele = golden path allele
      unless ($reference_base) {
	foreach my $cov ( @{$coverage{$reference_name}} ) {
	  if( $start >= $cov->[0] && $start <= $cov->[1] ) {
	    $reference_base = $golden_path_base;
	    last;
	  }
	}
      }
    }

    # Set ref base colour and draw glyphs ----------------------------------
    $colour = $colours[0] if $reference_base;
    $snp_ref->[3] = { $reference_base => $colours[0] }  ;
    $snp_ref->[4] = $reference_base ;
    $self->do_glyphs($offset, $th, $w, $Config, $label, $snp_ref->[0], 
		     $snp_ref->[1], $colour, $reference_base);

  } #end foreach $snp_ref



  # Draw SNPs for each strain -----------------------------------------------
  foreach my $strain ( sort {$a cmp $b} keys %strain_alleles ) {
    next if $strain eq $reference_name;

    $offset += $track_height;
    $self->strain_name_text($w, $th, $offset, $strain, $Config);

    foreach my $snp_ref ( @snps ) {
      my $snp = $snp_ref->[2];
      my $label =  $snp->allele_string;
      my $start  = $snp->start;

      my $allele_string =  $strain_alleles{$strain}{ join "::", $snp->{_variation_id}, $start };

      # If no allele for SNP but there is coverage, allele = reference allele
      unless( $allele_string ) {
	foreach my $cov ( @{$coverage{$strain}} ) {
	  if( $start >= $cov->[0] && $start <= $cov->[1] ) {
	    ($allele_string) = split "\/", $label;
	    last;
	  }
	}
      }

      # Determine colour ------------------------------------
      my $colour = undef;
      my $text = $snp_ref->[4] ? "white" : "black";

      if( $allele_string && $snp_ref->[4] ) {
        $colour = $snp_ref->[3]{ $allele_string };
        unless($colour) {
          $colour = $snp_ref->[3]{ $allele_string } = 
	    $colours[ scalar(values %{ $snp_ref->[3] } )] || $colours[-1];
        }
      }

      # Draw rectangle ------------------------------------
      $self->do_glyphs($offset, $th,$w, $Config, $label, $snp_ref->[0], 
		       $snp_ref->[1], $colour, $allele_string, $text);
    }
  }
  $self->push(new Sanger::Graphics::Glyph::Space({ 'y' => $offset + $track_height, 'height' => $th+2, 'x' => 1, 'width' => 1, 'absolutey' => 1, }));
  return 1;
}



# Glyphs ###################################################################

sub strain_name_text {
  my ($self, $w, $th, $offset, $name, $Config) = @_;
  (my $url_name = $name) =~ s/Reference //;
  my $URL = $Config->{'URL'}."reference=$url_name;";

  my $bp_textwidth = $w * length($name) * 1.2;
  my $textglyph = new Sanger::Graphics::Glyph::Text({
      'x'          => -$w - $bp_textwidth,
      'y'          => $offset+1,
      'width'      => $bp_textwidth,
      'height'     => $th,
      'font'       => $Config->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'},
      'colour'     => 'black',
      'text'       => $name,
      'title'      => "Click to set strain as reference",
      'href'       => $URL,
      'absolutey'  => 1,
    });
  $self->push( $textglyph );
  return 1;
}




sub do_glyphs {
  my ($self, $offset, $th, $w, $Config, $label, $start, $end, $colour, $allele_string, $text_colour) = @_;

  my $length = exists $self->{'container'}{'ref'} ? $self->{'container'}{'ref'}->length : $self->{'container'}->length;

  $start = 1 if $start < 1;
  $end = $length if $end > $length;

  my $alleles_bp_textwidth = $w * length($label);
  my $tmp_width = $alleles_bp_textwidth + $w*4;
  if ( ($end - $start + 1) > $tmp_width ) {
    $start = ( $end + $start-$tmp_width )/2;
    $end =  $start+$tmp_width ;
  }

  my $back_glyph = new Sanger::Graphics::Glyph::Rect({
         'x'         => $start-1,
         'y'         => $offset,
         'colour'    => $colour,
         'bordercolour' => 'black',
         'absolutey' => 1,
         'height'    => $th+2,
         'width'     => $end-$start+1,
         'absolutey' => 1,
 	});
  $self->push( $back_glyph );

  my $strain_bp_textwidth  = $w * length($allele_string || 1) ;
  if ( ($end-$start + 1)  >$strain_bp_textwidth) {
    my $textglyph = new Sanger::Graphics::Glyph::Text({
            'x'          => ( $end + $start - 1 - $strain_bp_textwidth)/2,
            'y'          => 2+$offset,
            'width'      => $alleles_bp_textwidth,
            'height'     => $th,
            'font'       => $Config->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'},
            'colour'     => $text_colour || "white",
            'text'       => $allele_string,
            'absolutey'  => 1,
          }) if $allele_string;
    $self->push( $textglyph ) if defined $textglyph;
  }
  return 1;
}


1;
