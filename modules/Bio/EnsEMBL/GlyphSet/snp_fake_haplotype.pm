package Bio::EnsEMBL::GlyphSet::snp_fake_haplotype;
use strict;
use vars qw(@ISA);

use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);

use Bio::EnsEMBL::GlyphSet;
use Data::Dumper;  
our @ISA = qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) = @_;

  my $Config        = $self->{'config'};
  my $conf_colours  = $self->my_config('colours' );

  my @snps = @{$Config->{'snps'}};
  return unless scalar @snps;
  return unless $Config->{'snp_fake_haplotype'};

  # Get reference strain name for start of track:
  my $individual_adaptor = $self->{'container'}->adaptor->db->get_db_adaptor('variation')->get_IndividualAdaptor;
  my $golden_path =  $individual_adaptor->get_reference_strain_name();
  my $reference_name = $Config->{'reference'};
  
  # Put allele and coverage data from config into hashes -----------------------
  my %strain_alleles;   # $strain_alleles{strain}{id::start} = allele
  my %coverage;         # $coverage{strain} = [ [start, end, level], [start, end, level]   ];

  my $fully_inbred;
  foreach my $data ( @{$Config->{'snp_fake_haplotype'}} ) { 
    my( $strain, $allele_ref, $coverage_ref ) = @$data;

    # find out once if this species is inbred or not. Then apply to all
    unless (defined $fully_inbred) {
      my ($individual) = @{$individual_adaptor->fetch_all_by_name($strain)};
      if ($individual) {
	      $fully_inbred = $individual->type_individual eq 'Fully_inbred' ? 1 : 0;
      }
    }
    $strain_alleles{$strain} = {};  # every strain should be in here
    foreach my $a_ref ( @$allele_ref ) { 
      next unless $a_ref->[2];

      # strain_alleles{strain_name}{snp_id::start} = allele
      $strain_alleles{$strain}{ join "::", $a_ref->[2]->{'_variation_id'}, $a_ref->[2]->{'start'} } = $a_ref->[2]->allele_string ;
    }
    foreach my $c_ref ( @$coverage_ref ) { 
      push @{ $coverage{$strain} }, [ $c_ref->[2]->start, $c_ref->[2]->end, $c_ref->[2]->level ];
    }
  }

  # Default to Ensembl golden path ref strain if chosen "ref" strain isn't selected on the display
  $reference_name = $golden_path unless $strain_alleles{$reference_name};

  # Info text 
  my $info_text = "Comparison to $reference_name alleles";

  my( $fontname_c, $fontsize_c ) = $self->get_font_details( 'caption' );
  my @res_c = $self->get_text_width( 0, 'X|X', '', 'font'=>$fontname_c, 'ptsize' => $fontsize_c );
  my $th_c = $res_c[3];

  my( $fontname, $fontsize ) = $self->get_font_details( 'innertext' );
  my @res = $self->get_text_width( 0, 'X|X', '', 'font'=>$fontname, 'ptsize' => $fontsize );
  my $w  = $res[2];
  my $th = $res[3];
  my $pix_per_bp    = $Config->transform->{'scalex'};

  my $track_height = $th + 4;

  $self->push($self->Space({ 'y' => 0, 'height' => $track_height, 'x' => 1, 'w' => 1, 'absolutey' => 1, }));

  my $offset = $track_height;
  my $textglyph = $self->Text({
    'x'          => -$self->get_parameter('__left_hand_margin'),
    'y'          => 2+$offset,
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
  $offset += $th_c + 6;

  # Reference track ----------------------------------------------------
  my @ref_name_size = $self->get_text_width( 80, $reference_name, '', 'font'=>$fontname, 'ptsize' => $fontsize );
  if ($ref_name_size[0] eq '') {
    $self->strain_name_text($th, $fontname, $fontsize, $offset, "Compare to", $Config, $fully_inbred);
    $offset += $track_height;
    $self->strain_name_text($th, $fontname, $fontsize, $offset, "    $reference_name", $Config, $fully_inbred);
  }
  else {
    $self->strain_name_text($th, $fontname, $fontsize, $offset, "Compare to $reference_name", $Config, $fully_inbred);
  }



  # First lets draw the reference SNPs....
  my @golden_path;
  my @widths = ();
  foreach my $snp_ref ( @snps ) {
    my $start = $snp_ref->[0];
    my $end   = $snp_ref->[1];
    my $snp   = $snp_ref->[2];

    my @res = $self->get_text_width( ($end-$start+1)*$pix_per_bp, 'X|X', 'X|X', 'font'=>$fontname, 'ptsize' => $fontsize );
    my $tmp_width = ($w*2+$res[2])/$pix_per_bp;
    $tmp_width =  $end-$start+1 if  $end-$start+1 < $tmp_width;
    push @widths, $tmp_width;
    my $label =  $snp->allele_string; 

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

      # Golden path ne reference but still need the golden path track in there somewhere
      my $golden_colour = undef;

      if ($reference_base) { # determine colours for golden path row dp on reference colours
      	$conf_colours->{$self->bases_match($golden_path_base, $reference_base) }->{'default'};
      }
      push @golden_path, {
			  label   => $label,
			  snp_ref => $snp_ref,
			  colour  => $golden_colour,
			  base    => $golden_path_base,
			 };
    }

    # Set ref base colour and draw glyphs ----------------------------------
    $colour = $conf_colours->{'same'}->{'default'} if $reference_base; 
    $snp_ref->[3] = {};

    # If ref base is like "G", have to define "G|G" as also having ref base colour
    if (length $reference_base ==1) {
      $snp_ref->[3]{ "$reference_base|$reference_base"} = $conf_colours->{'same'}{'default'};
      $snp_ref->[3]{ $reference_base} = $conf_colours->{'same'}{'default'};
    }
    elsif ($reference_base =~/(\w)\|(\w)/) {
      if ($1 ne $2) { # heterozygous it should be stripy
	      $snp_ref->[3]{ $reference_base} = $conf_colours->{'het'}{'default'};
	      $snp_ref->[3]{ $2.$1} = $conf_colours->{'het'}{'deafult'};
      }
      else {
	      $snp_ref->[3]{ $reference_base } = $conf_colours->{'same'}{'default'};
      }
    }

    $snp_ref->[4] = $reference_base ;
    $self->do_glyphs($offset, $th, $tmp_width, $pix_per_bp, $fontname, $fontsize, $Config, $label, $snp_ref->[0],  $snp_ref->[1], $colour, $reference_base);

  } #end foreach $snp_ref

  # Make sure the golden path one is in there somewhere
  my $c = 0;
  if ( $reference_name ne $golden_path && !$strain_alleles{$golden_path} ) {
    $offset += $track_height;
    $self->strain_name_text( $th, $fontname, $fontsize, $offset, $golden_path, $Config, $fully_inbred);
    foreach my $hash (@golden_path) {
      my $snp_ref = $hash->{snp_ref};
      my $text_colour = $hash->{colour} ? "white" : "black";
      $self->do_glyphs($offset, $th, $widths[$c], $pix_per_bp, $fontname, $fontsize, $Config, $hash->{label}, $snp_ref->[0], $snp_ref->[1], $hash->{colour}||"white", $hash->{base}, $text_colour);
      $c++;
    }
  }

  # Draw SNPs for each strain -----------------------------------------------
  foreach my $strain ( sort {$a cmp $b} keys %strain_alleles ) {
    next if $strain eq $reference_name; 
                                            
    $offset += $track_height;
    $self->strain_name_text($th,$fontname, $fontsize, $offset, $strain, $Config, $fully_inbred);

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
      my $text = $snp_ref->[4] ? "white" : "black"; # text colour white if ref base defined
      if( $allele_string && $snp_ref->[4] ) {      # only fill in colour if ref base is defined
        $colour = $snp_ref->[3]{ $allele_string };
	
        unless($colour) {                           # allele not the same as reference
	  if (length $allele_string ==1 ) {
	    $colour =  $snp_ref->[3]{ $allele_string } = $conf_colours->{'different'}{'default'};
	  }
	  else{ # must be a het or must be different
	    my $type = $self->bases_match((split /\|/, $allele_string), "one_allele");
	    $colour = $snp_ref->[3]{ $allele_string } = $conf_colours->{$type}{'default'};
	    #$colours[ scalar(values %{ $snp_ref->[3] } )] || $colours[-1];
	  }

        }
      }

      # Draw rectangle ------------------------------------
      $self->do_glyphs($offset, $th,$widths[$c], $pix_per_bp, $fontname, $fontsize, $Config, $label, $snp_ref->[0], 
		       $snp_ref->[1], $colour, $allele_string, $text);
      $c++;
    }
  }
  $self->push($self->Space({ 'y' => $offset + $track_height, 'height' => $th+2, 'x' => 1, 'width' => 1, 'absolutey' => 1, }));

  # Colour legend stuff
  foreach (keys %$conf_colours) { 
    push @{ $Config->{'tsv_haplotype_legend_features'}->{'variations'}->{'legend'}}, $conf_colours->{$_}->{'text'},   $conf_colours->{$_}->{'default'};
  }
  return 1;
}



# Glyphs ###################################################################

sub strain_name_text {
  my ($self, $th, $fontname, $fontsize, $offset, $name, $Config, $fully_inbred) = @_;
  (my $url_name = $name) =~ s/Compare to |^\s+//;
  my $URL = $self->_url({'action' => 'ref',  'reference' => $url_name});
  my $textglyph = $self->Text({
      'x'          => -$self->get_parameter('__left_hand_margin'),
      'y'          => $offset+1,
      'height'     => $th,
      'font'       => $fontname,
      'ptsize'     => $fontsize,
      'colour'     => 'black',
      'text'       => $name,
      'halign'     => 'left',
      'width'      => 105,
      'absolutex'  => 1,
      'absolutey'  => 1,
      'absolutewidth'  => 1,
      'href'      => $URL,
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

  # Heterozygotes should be stripey
  my @stripes;
  if ($colour eq 'stripes') {
    my $Config        = $self->{'config'};
    my $conf_colours  = $self->my_config('colours');
    $colour = $conf_colours->{'same'}{'default'};
    @stripes = ( 'pattern'       => 'hatch_thick',
		 'patterncolour' => $conf_colours->{'different'}{'default'},
	       );
  }

  my $back_glyph = $self->Rect({
    'x'         => ($end+$start-1-$tmp_width)/2,
    'y'         => $offset,
    'colour'    => $colour,
    'bordercolour' => 'black',
    'absolutey' => 1,
    'height'    => $th+2,
    'width'     => $tmp_width,
    'absolutey' => 1,
    @stripes,
  });
  $self->push( $back_glyph );

  
  if ( ($end-$start + 1) > $res[2]/$pix_per_bp) {
    if( $res[0] eq 'A' and $res[0] ne $allele_string ) {
      @res = $self->get_text_width( 0, $allele_string, '', 'font'=>$fontname, 'ptsize' => $fontsize );
    }

    my $tmp_width = $res[2]/$pix_per_bp;
    my $textglyph = $self->Text({
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

sub bases_match {
  my ($self, $one, $two, $one_allele) = @_;
  $one .= "|$one" if length $one == 1;
  $two .= "|$two" if length $two == 1;

  my $same = $one_allele ? "different" : "same";
  my $different = $one_allele ? "het"  : "different";
  return $same if ($one eq $two);

  foreach (split /\|/, $one) {
    return "het" if $_ eq substr $two, 0, 1;
    return "het" if $_ eq substr $two, 2, 1;
  }
  return $different;
}
1;

