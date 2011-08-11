package Bio::EnsEMBL::GlyphSet::vcf;
use strict;

#use base qw(Bio::EnsEMBL::GlyphSet_simple);

use base qw(Bio::EnsEMBL::GlyphSet::_variation);
use Bio::EnsEMBL::ExternalData::VCF::VCFAdaptor;
use Bio::EnsEMBL::Variation::DBSQL::VariationFeatureAdaptor;
use Data::Dumper;
use HTML::Entities qw(encode_entities);

sub reset {
  my ($self) = @_;
  $self->{'glyphs'} = [];
  foreach (qw(x y width minx miny maxx maxy bumped)) {
      delete $self->{$_};
  }
}

# get a bam adaptor
sub vcf_adaptor {
  my $self = shift;
  
  my $url = $self->my_config('url');
  if ($url =~ /\#\#\#CHR\#\#\#/) {
      my $region = $self->{'container'}->seq_region_name;
      $url =~ s/\#\#\#CHR\#\#\#/$region/g;
  }
  $self->{_cache}->{_vcf_adaptor} ||= Bio::EnsEMBL::ExternalData::VCF::VCFAdaptor->new($url);
  
  return $self->{_cache}->{_vcf_adaptor};
}

sub render_compact {
    my $self = shift;
    return $self->render_normal;
}

sub render_histogram {
    my $self = shift;
    my $slice = $self->{'container'};
    my $snps = $self->vcf_adaptor->fetch_variations($slice->seq_region_name, $slice->start, $slice->end);
    
    
#    warn "COUNT : ", scalar(@$snps);
    if (my $snum = scalar(@$snps) > 200) {
	return $self->render_density_bar;
    }
    return $self->render_normal;
}

sub render_density_bar {
    my $self = shift;

    my $h           = 20;
    my $colour      = $self->my_config('col')  || 'gray50';
    my $line_colour = $self->my_config('line') || 'red';

    my $slice = $self->{'container'};
    my $vclen    = $slice->length;
    my $im_width = $self->{'config'}->image_width;
    my $divs     = $im_width;
    my $divlen   = $vclen / $divs;

    
    my $density = $self->features_density();

    my $maxvalue = (sort {$b <=> $a} values %$density)[0];
    
#    warn "MAX $maxvalue";

    foreach my $pos (sort {$a <=> $b} keys %$density) {
	my $v = $density->{$pos};
	my $h1 = int(($v / $maxvalue) * $h);
	$self->push($self->Line({
	    x         => $pos * $divlen,
	    y         => $h - $h1,
	    width     => 0,
	    height    => $h1,
	    colour    => $colour,
	    absolutey => 1,
	})); 
    }
      
    my( $fontname_i, $fontsize_i ) = $self->get_font_details( 'innertext' );
    my @res_i = $self->get_text_width(0, $maxvalue, '', 'font'=>$fontname_i, 'ptsize' => $fontsize_i );
    my $textheight_i = $res_i[3];

   $self->push( $self->Text({
	'text'          => $maxvalue,
	'width'         => $res_i[2],
	'textwidth'     => $res_i[2],
	'font'          => $fontname_i,
	'ptsize'        => $fontsize_i,
	'halign'        => 'right',
	'valign'        => 'top',
	'colour'        => $line_colour,
	'height'        => $textheight_i,
	'y'             => 0,
	'x'             => -4 - $res_i[2],
	'absolutey'     => 1,
	'absolutex'     => 1,
	'absolutewidth' => 1,
    }));

    $maxvalue = ' 0';
    @res_i = $self->get_text_width(0, $maxvalue, '', 'font'=>$fontname_i, 'ptsize' => $fontsize_i );
    $textheight_i = $res_i[3];
    
   $self->push( $self->Text({
	'text'          => $maxvalue,
	'width'         => $res_i[2],
	'textwidth'     => $res_i[2],
	'font'          => $fontname_i,
	'ptsize'        => $fontsize_i,
	'halign'        => 'right',
	'valign'        => 'bottom',
	'colour'        => $line_colour,
	'height'        => $textheight_i,
	'y'             => $textheight_i + 4,
	'x'             => -4 - $res_i[2],
	'absolutey'     => 1,
	'absolutex'     => 1,
	'absolutewidth' => 1,
    }));
}

sub features_density {
    my $self = shift;
    my $slice = $self->{'container'};
    my $START = $self->{'container'}->start - 1;
    my $snps = $self->vcf_adaptor->fetch_variations($slice->seq_region_name, $slice->start, $slice->end);

    my $density = {};

    my $vclen    = $slice->length;
    my $im_width = $self->{'config'}->image_width;
    my $divs     = $im_width;
    my $divlen   = $vclen / $divs;
    $divlen = 10 if $divlen < 10; # Increase the number of points for short sequences

    foreach my $snp (@{$snps||[]}) {
	my $vs = int(($snp->{POS}- $START) / $divlen);
	$density->{$vs}++;
    }
    return $density;
}

sub features {
  my $self = shift;
  my $t1 = time;

  unless ($self->{_cache}->{features}) {
      my $ppbp = $self->scalex;
      warn "SCALE $ppbp \n";

      my $slice = $self->{'container'};
      my $START = $self->{'container'}->start;
      my $consensus = $self->vcf_adaptor->fetch_variations($slice->seq_region_name, $slice->start, $slice->end);
      warn "COUNT :", scalar @{$consensus || []};

      my @features;
      my $config  = $self->{'config'};
      my $species = $slice->adaptor->db->species;

# If we have a variation db attached we can try and find a known SNP mapped at the same position
# But at the moment we do not display this info so we might as well just use the faster method 
#     my $vfa = $slice->_get_VariationFeatureAdaptor()->{list}->[0];

      my $vfa = Bio::EnsEMBL::Variation::DBSQL::VariationFeatureAdaptor->new_fake($species);
      my $fnum =  scalar(@$consensus);

      my $calc_type = $fnum > 200 ? 0 : 1;
      
      foreach my $a (@$consensus) {
#	  warn Dumper $a;

	  my $unknown_type = 1;
	  my $vs = $a->{POS}- $START+1;
	  my $ve = $vs;

	  my $info ='';
	  foreach my $i (sort keys %{$a->{INFO}||{}}) {
	      $info .= ";  $i: $a->{INFO}->{$i}";
	  }

	  if (my $sv = $a->{INFO}->{SVTYPE}) {
	      if (0) {
		  warn '-'x40, "\n";
		  foreach my $k (sort keys %$a) {
		      warn "$k => $a->{$k} \n";
		  }
		  foreach my $k (sort keys %{$a->{INFO}}) {
		      warn "\t$k => $a->{INFO}->{$k} \n";
		  }
		  warn join ' * ' , @{$a->{ALT}||[]}, "\n";
		  warn '-'x40, "\n";
	      }
	      $unknown_type = 0;
	      if ($sv eq 'DEL') {
		  my $svlen = $a->{INFO}->{SVLEN} || 0;
		  $ve = $vs + abs($svlen);
		  if (length($a->{REF}) > 30) {
		      $a->{REF} = substr($a->{REF}, 0, 30)." ...";
		  }
	      } elsif ($sv eq 'TDUP') {
		  my $svlen = $a->{INFO}->{SVLEN} || 0;
		  $ve = $vs + $svlen + 1;
	      } elsif ($sv eq 'INS') {
		  $ve = $vs -1;
	      }
	  } else {
#	      warn Dumper $a;
	      my ($reflen, $altlen) = (length($a->{REF}), length($a->{ALT}->[0]));
	      if ($reflen > 1) {
		  $ve = $vs + $reflen -1;
	      } elsif ($altlen > 1) {
		  $ve = $vs - 1;
	      }
	  }


	  my $allele_string = join '/', $a->{REF},  @{$a->{ALT}||[]};
	  my $vf_name = $a->{ID} eq '.' ? $a->{CHROM}.'_'.$a->{POS}.'_'.$allele_string : $a->{ID};

          #vcf BOF
	  my $seq_id = $slice->seq_region_name();
          my $genotype_info =  defined $a->{'gtypes'} ?
                               (keys %{$a->{'gtypes'}} ? "<a href='/Export/VCFView?pos=$seq_id:$vs-$ve;&vcf=".$self->vcf_adaptor->{'_url'}."' class='modal_link'>Genotype Info</a>" : "")  
                               : "";
          #vcf EOF 

    if ($slice->strand == -1) {
      my $flip = $slice->length + 1;
      ($vs, $ve) = ($flip - $ve, $flip - $vs);
    }
          
#	warn join "\t", $a->{CHROM}, $a->{POS}, $a->{POS}, $allele_string, '+', "\n";
	  my $f1 =       {
	      'start'    => $vs, 
	      'end'      => $ve, 
	      'strand'   => 1, 
	      'slice'    => $slice,
	      'allele_string' => $allele_string,
	      #'variation_name' => $vf_name, 
              'variation_name' => $genotype_info ne "" ? $vf_name."; ".$genotype_info : $vf_name,
	      'map_weight' => 1, 
	      'adaptor' => $vfa, 
	      'seqname' => $info ? "; INFO: --------------------------$info" : '',
	      'consequence_type' => $unknown_type ? ['INTERGENIC'] : ['COMPLEX_INDEL']
	      };

	  bless $f1, 'Bio::EnsEMBL::Variation::VariationFeature';
	  
	  if ($calc_type && $unknown_type) {
	      my $tvars = $f1->get_all_TranscriptVariations();
	  }
	  push @features, $f1;
	  
	  my $type    = lc $f1->display_consequence;

	  if (!$config->{'variation_types'}{$type}) {
	      my $colours = $self->my_config('colours');
	      push @{$config->{'variation_legend_features'}->{'variations'}->{'legend'}}, $colours->{$type}->{'text'}, $colours->{$type}->{'default'};
	      $config->{'variation_types'}{$type} = 1;
	  }
      }
   
    $self->{_cache}->{features} = \@features;
  }
#  warn "TIME :", time - $t1;
  return $self->{_cache}->{features};
}



sub title {
  my ($self, $f) = @_;
  my $slice = $self->{'container'};
  my $seq_id = $slice->seq_region_name();
  my $START = $slice->start;

  my $vs = $f->start + $START-1;
  my $ve = $f->end + $START-1;
  
  my $x = ($vs == $ve) ? $vs : "$vs-$ve";

  my $title = $f->variation_name .
      "; Location: $seq_id:$x; Allele: ". encode_entities($f->allele_string). $f->id;

  return $title;
}

sub href {
  return undef;
}


1;
