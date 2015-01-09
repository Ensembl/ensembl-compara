=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Draw::GlyphSet::vcf;

### Module for drawing data in VCF format (either user-attached, or
### internally configured via an ini file or database record

use strict;

use HTML::Entities qw(encode_entities);

use Bio::EnsEMBL::ExternalData::VCF::VCFAdaptor;
use Bio::EnsEMBL::Variation::DBSQL::VariationFeatureAdaptor;
use Bio::EnsEMBL::Variation::Utils::Constants;

use base qw(EnsEMBL::Draw::GlyphSet::_variation);

sub reset {
  my $self = shift;
  $self->{'glyphs'} = [];
  delete $self->{$_} for qw(x y width minx miny maxx maxy bumped);
}

sub vcf_adaptor {
## get a vcf adaptor
  my $self = shift;
  my $url  = $self->my_config('url');
  
  if ($url =~ /###CHR###/) {
    my $region = $self->{'container'}->seq_region_name;
       $url    =~ s/###CHR###/$region/g;
  }
  
  return $self->{'_cache'}{'_vcf_adaptor'} ||= Bio::EnsEMBL::ExternalData::VCF::VCFAdaptor->new($url);
}

sub render_compact { return $_[0]->render_normal; }

sub render_histogram {
  my $self  = shift;
  my $slice = $self->{'container'};
  return scalar @{$self->vcf_adaptor->fetch_variations($slice->seq_region_name, $slice->start, $slice->end)} > 200 ? $self->render_density_bar : $self->render_normal;
}

sub render_density_bar {
  my $self        = shift;
  my $h           = 20;
  my $colour      = $self->my_config('col')  || 'gray50';
  my $line_colour = $self->my_config('line') || 'red';
  my $slice       = $self->{'container'};
  my $vclen       = $slice->length;
  my $im_width    = $self->{'config'}->image_width;
  my $divs        = $im_width;
  my $divlen      = $vclen / $divs;
  my $density     = $self->features_density;
  my ($maxvalue)  = sort { $b <=> $a } values %$density;

  foreach my $pos (sort {$a <=> $b} keys %$density) {
    my $v  = $density->{$pos};
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
    
  my ($fontname_i, $fontsize_i) = $self->get_font_details('innertext');
  my @res_i        = $self->get_text_width(0, $maxvalue, '', font => $fontname_i, ptsize => $fontsize_i);
  my $textheight_i = $res_i[3];

  $self->push($self->Text({
    text          => $maxvalue,
    width         => $res_i[2],
    textwidth     => $res_i[2],
    font          => $fontname_i,
    ptsize        => $fontsize_i,
    halign        => 'right',
    valign        => 'top',
    colour        => $line_colour,
    height        => $textheight_i,
    y             => 0,
    x             => -4 - $res_i[2],
    absolutey     => 1,
    absolutex     => 1,
    absolutewidth => 1,
  }));
  
  $maxvalue     = ' 0';
  @res_i        = $self->get_text_width(0, $maxvalue, '', font => $fontname_i, ptsize => $fontsize_i);
  $textheight_i = $res_i[3];
    
  $self->push($self->Text({
    text          => $maxvalue,
    width         => $res_i[2],
    textwidth     => $res_i[2],
    font          => $fontname_i,
    ptsize        => $fontsize_i,
    halign        => 'right',
    valign        => 'bottom',
    colour        => $line_colour,
    height        => $textheight_i,
    y             => $textheight_i + 4,
    x             => -4 - $res_i[2],
    absolutey     => 1,
    absolutex     => 1,
    absolutewidth => 1,
  }));
}

sub features_density {
  my $self     = shift;
  my $slice    = $self->{'container'};
  my $start    = $slice->start - 1;
  my $vclen    = $slice->length;
  my $im_width = $self->{'config'}->image_width;
  my $divs     = $im_width;
  my $divlen   = $vclen / $divs;
     $divlen   = 10 if $divlen < 10; # Increase the number of points for short sequences
  my $density  = {};
     $density->{int(($_->{'POS'} - $start) / $divlen)}++ for @{$self->vcf_adaptor->fetch_variations($slice->seq_region_name, $slice->start, $slice->end) || []};
  
  return $density;
}

sub features {
  my $self = shift;

  if (!$self->{'_cache'}{'features'}) {
    my $ppbp        = $self->scalex;
    my $slice       = $self->{'container'};
    my $start       = $slice->start;
    my $vcf_adaptor = $self->vcf_adaptor;
    my $consensus   = $vcf_adaptor->fetch_variations($slice->seq_region_name, $slice->start, $slice->end);
    my $fnum        = scalar @$consensus;
    my $calc_type   = $fnum > 200 ? 0 : 1;
    my $config      = $self->{'config'};
    my $species     = $slice->adaptor->db->species;
    my @features;

    # Can we actually draw this many features?
    unless ($calc_type) {
      return 'too_many';
    } 

    # If we have a variation db attached we can try and find a known SNP mapped at the same position
    # But at the moment we do not display this info so we might as well just use the faster method 
    #     my $vfa = $slice->_get_VariationFeatureAdaptor()->{list}->[0];
    
    my $vfa = Bio::EnsEMBL::Variation::DBSQL::VariationFeatureAdaptor->new_fake($species);
    
    foreach my $a (@$consensus) {
      my $unknown_type = 1;
      my $vs           = $a->{'POS'} - $start + 1;
      my $ve           = $vs;
      my $info;
         $info .= ";  $_: $a->{'INFO'}{$_}" for sort keys %{$a->{'INFO'} || {}};

      if (my $sv = $a->{'INFO'}{'SVTYPE'}) {
        $unknown_type = 0;
        
        if ($sv eq 'DEL') {
          my $svlen = $a->{'INFO'}{'SVLEN'} || 0;
             $ve    = $vs + abs $svlen;
             
          $a->{'REF'} = substr($a->{'REF'}, 0, 30) . ' ...' if length $a->{'REF'} > 30;
        } elsif ($sv eq 'TDUP') {
          my $svlen = $a->{'INFO'}{'SVLEN'} || 0;
             $ve    = $vs + $svlen + 1;
        } elsif ($sv eq 'INS') {
          $ve = $vs -1;
        }
      } else {
        my ($reflen, $altlen) = (length $a->{'REF'}, length $a->{'ALT'}[0]);
        
        if ($reflen > 1) {
          $ve = $vs + $reflen - 1;
        } elsif ($altlen > 1) {
          $ve = $vs - 1;
        }
      }
      
      my $allele_string = join '/', $a->{'REF'}, @{$a->{'ALT'} || []};
      my $vf_name       = $a->{'ID'} eq '.' ? "$a->{'CHROM'}_$a->{'POS'}_$allele_string" : $a->{'ID'};

      if ($slice->strand == -1) {
        my $flip = $slice->length + 1;
        ($vs, $ve) = ($flip - $ve, $flip - $vs);
      }
      
      my $snp = {
        start            => $vs, 
        end              => $ve, 
        strand           => 1, 
        slice            => $slice,
        allele_string    => $allele_string,
        variation_name   => $vf_name,
        map_weight       => 1, 
        adaptor          => $vfa, 
        seqname          => $info ? "; INFO: --------------------------$info" : '',
        consequence_type => $unknown_type ? ['INTERGENIC'] : ['COMPLEX_INDEL']
      };

      bless $snp, 'Bio::EnsEMBL::Variation::VariationFeature';
      
      # if user has defined consequence in VE field of VCF
      # no need to look up via DB
      if(defined($a->{'INFO'}->{'VE'})) {
        my $con = (split /\|/, $a->{'INFO'}->{'VE'})[0];
        
        if(defined($Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES{$con})) {
          $snp->{consequence_type} = [$con];
          $snp->{overlap_consequences} = [$Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES{$con}];
          $calc_type = 0;
        }
      }
      
      # otherwise look up via DB
      $snp->get_all_TranscriptVariations if $calc_type && $unknown_type;
      
      push @features, $snp;
      
      $self->{'legend'}{'variation_legend'}{$snp->display_consequence} ||= $self->get_colour($snp);
    }

    $self->{'_cache'}{'features'} = \@features;
  }
  
  return $self->{'_cache'}{'features'};
}

sub title {
  my ($self, $f) = @_;
  my $slice  = $self->{'container'};
  my $seq_id = $slice->seq_region_name;
  my $start  = $slice->start;
  my $vs     = $f->start + $start-1;
  my $ve     = $f->end + $start-1;
  my $x      = ($vs == $ve) ? $vs : "$vs-$ve";
  
  return $f->variation_name . "; Location: $seq_id:$x; Allele: " . encode_entities($f->allele_string) . $f->id;
}

sub href { return undef; }

1;
