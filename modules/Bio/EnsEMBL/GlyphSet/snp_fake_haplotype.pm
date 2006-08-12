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
  my $info_text = "Comparison to $reference_name alleles (green = same allele; purple = different allele; white = data missing)";

  my( $fontname_c, $fontsize_c ) = $self->get_font_details( 'caption' );
  my @res_c = $self->get_text_width( 0, 'X', '', 'font'=>$fontname_c, 'ptsize' => $fontsize_c );
  my $th_c = $res_c[3];

  my( $fontname, $fontsize ) = $self->get_font_details( 'innertext' );
  my @res = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );
  my $w  = $res[2];
  my $th = $res[3];
  my $pix_per_bp    = $Config->transform->{'scalex'};

  my $track_height = $th + 4;

  $self->push(new Sanger::Graphics::Glyph::Space({ 'y' => 0, 'height' => $track_height, 'x' => 1, 'w' => 1, 'absolutey' => 1, }));

  my $textglyph = new Sanger::Graphics::Glyph::Text({
    'x'          => - 115,
    'y'          => 2,
    'width'      => 0,
    'height'     => $th_c,
    'font'       => $fontname_c,
    'ptsize'     => $fontsize_c,
    'colour'     => 'black',
    'text'       => $info_text,
    'absolutey'  => 1,
    'absolutex'  => 1,
    'halign'     => 'left'
   });
  $self->push( $textglyph );



  # Reference track ----------------------------------------------------
  my $offset = $th_c + 4;
  my @colours       = qw(chartreuse4 darkorchid4);# orange4 deeppink3 dodgerblue4);


    my @ref_name_size = $self->get_text_width( 80, $reference_name, '', 'font'=>$fontname, 'ptsize' => $fontsize );
  if ($ref_name_size[0] eq '') {
    $self->strain_name_text($th, $fontname, $fontsize, $offset, "Compare to", $Config);
    $offset += $track_height;
    $self->strain_name_text($th, $fontname, $fontsize, $offset, "    $reference_name", $Config);
  }
  else {
    $self->strain_name_text($th, $fontname, $fontsize, $offset, "Compare to $reference_name", $Config);
  }



  # First lets draw the reference SNPs....
  my @golden_path;
  my @widths = ();
  foreach my $snp_ref ( @snps ) {
    my $start = $snp_ref->[0];
    my $end   = $snp_ref->[1];
    my $snp   = $snp_ref->[2];
    my $label =  $snp->allele_string;

    my @res = $self->get_text_width( ($end-$start+1)*$pix_per_bp, $label, 'X', 'font'=>$fontname, 'ptsize' => $fontsize );
    my $tmp_width = ($w*2+$res[2])/$pix_per_bp;
    my $two = $tmp_width;
       $tmp_width =  $end-$start+1 if  $end-$start+1 < $tmp_width;
    #warn "$end - $start - $tmp_width - $two";
    push @widths, $tmp_width;

    my ($golden_path_base) = split "\/", $label;
    my $reference_base;
    my $colour = "white";

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
      my $golden_colour = undef;

      if ($reference_base) {
	$golden_colour = $golden_path_base eq $reference_base ? $colours[0] : $colours[1],
      }
      push @golden_path, {
			  label   => $label,
			  snp_ref => $snp_ref,
			  colour  => $golden_colour,
			  base    => $golden_path_base,
			 };
    }

    # Set ref base colour and draw glyphs ----------------------------------
    $colour = $colours[0] if $reference_base;
    $snp_ref->[3] = { $reference_base => $colours[0] }  ;
    $snp_ref->[4] = $reference_base ;
    $self->do_glyphs($offset, $th, $tmp_width, $pix_per_bp, $fontname, $fontsize, $Config, $label, $snp_ref->[0], 
		     $snp_ref->[1], $colour, $reference_base);

  } #end foreach $snp_ref

  # Make sure the golden path one is in there somewhere
  my $c = 0;
  if ( $reference_name ne $golden_path && !$strain_alleles{$golden_path} ) {
    $offset += $track_height;
    $self->strain_name_text( $th, $fontname, $fontsize, $offset, $golden_path, $Config);
    foreach my $hash (@golden_path) {
      my $snp_ref = $hash->{snp_ref};
      my $text_colour = $hash->{colour} ? "white" : "black";
      $self->do_glyphs($offset, $th, $widths[$c], $pix_per_bp, $fontname, $fontsize, $Config, $hash->{label}, 
			$snp_ref->[0], $snp_ref->[1], 
			$hash->{colour}||"white", $hash->{base}, $text_colour);
      $c++;
    }
  }

  # Draw SNPs for each strain -----------------------------------------------
  foreach my $strain ( sort {$a cmp $b} keys %strain_alleles ) {
    next if $strain eq $reference_name;

    $offset += $track_height;
    $self->strain_name_text($th,$fontname, $fontsize, $offset, $strain, $Config);

    my $c = 0;
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
      my $colour = "white";#undef;
      my $text = $snp_ref->[4] ? "white" : "black";

      if( $allele_string && $snp_ref->[4] ) {
        $colour = $snp_ref->[3]{ $allele_string };
        unless($colour) {
          $colour = $snp_ref->[3]{ $allele_string } = 
	    $colours[ scalar(values %{ $snp_ref->[3] } )] || $colours[-1];
        }
      }

      # Draw rectangle ------------------------------------
      $self->do_glyphs($offset, $th,$widths[$c], $pix_per_bp, $fontname, $fontsize, $Config, $label, $snp_ref->[0], 
		       $snp_ref->[1], $colour, $allele_string, $text);
      $c++;
    }
  }
  $self->push(new Sanger::Graphics::Glyph::Space({ 'y' => $offset + $track_height, 'height' => $th+2, 'x' => 1, 'width' => 1, 'absolutey' => 1, }));
  return 1;
}



# Glyphs ###################################################################

sub strain_name_text {
  my ($self, $th, $fontname, $fontsize, $offset, $name, $Config) = @_;
  (my $url_name = $name) =~ s/Compare to |^\s+//;
  my $URL = $Config->{'URL'}."reference=$url_name;";

  my $textglyph = new Sanger::Graphics::Glyph::Text({
      'x'          => -115,
      'y'          => $offset+1,
      'height'     => $th,
      'font'       => $fontname,
      'ptsize'     => $fontsize,
      'colour'     => 'black',
      'text'       => $name,
      'title'      => "Click to compare to $url_name",
      'href'       => $URL,
      'halign'     => 'left',
      'width'      => 205,
      'absolutex'  => 1,
      'absolutey'  => 1,
      'absolutewidth'  => 1,
  });
  $self->push( $textglyph );
  return 1;
}




sub do_glyphs {
  my ($self, $offset, $th, $tmp_width, $pix_per_bp, $fontname, $fontsize, $Config, $label, $start, $end, $colour, $allele_string, $text_colour) = @_;

  my $length = exists $self->{'container'}{'ref'} ? $self->{'container'}{'ref'}->length : $self->{'container'}->length;

  $start = 1 if $start < 1;
  $end = $length if $end > $length;

  my @res = $self->get_text_width( 0, length($allele_string)==1 ? "A" : $allele_string, '', 'font'=>$fontname, 'ptsize' => $fontsize );

  my $back_glyph = new Sanger::Graphics::Glyph::Rect({
    'x'         => ($end+$start-1-$tmp_width)/2,
    'y'         => $offset,
    'colour'    => $colour,
    'bordercolour' => 'black',
    'absolutey' => 1,
    'height'    => $th+2,
    'width'     => $tmp_width,
    'absolutey' => 1,
  });
  $self->push( $back_glyph );

  
  if ( ($end-$start + 1) > $res[2]/$pix_per_bp) {
    if( $res[0] eq 'A' and $res[0] ne $allele_string ) {
      @res = $self->get_text_width( 0, $allele_string, '', 'font'=>$fontname, 'ptsize' => $fontsize );
    }

    my $tmp_width = $res[2]/$pix_per_bp;
    my $textglyph = new Sanger::Graphics::Glyph::Text({
      'x'          => ( $end + $start - 1 - $tmp_width)/2,
      'y'          => 1+$offset,
      'width'      => $tmp_width,
      'textwidth'  => $res[2],
      'height'     => $th,
      'font'       => $fontname,
      'ptsize'     => $fontsize,
      'colour'     => $text_colour || "white",
      'text'       => $allele_string,
      'absolutey'  => 1,
    }) if $res[0];
    $self->push( $textglyph ) if defined $textglyph;
  }
  return 1;
}


1;
