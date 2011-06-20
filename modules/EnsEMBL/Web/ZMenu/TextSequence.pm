# $Id$

### A light-weight menu used on text sequence pages.
### Skips the standard rendering method in favour of raw content and speed

package EnsEMBL::Web::ZMenu::TextSequence;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub render {
  my $self = shift; 
  $self->_content;
  print $self->jsonify($self->{'entries'});
}

sub _content {
  my $self    = shift;
  my $hub     = $self->hub;
  my $object  = $self->object;
  my @v       = $hub->param('v');
  my @vf      = $hub->param('vf');
  my $lrg     = $hub->param('lrg');
  my $adaptor = $hub->database('variation')->get_VariationAdaptor;
  my $lrg_slice;
  
  if ($lrg) {
    eval { $lrg_slice = $hub->get_adaptor('get_SliceAdaptor')->fetch_by_region('LRG', $lrg); };
  }
  
  for (0..$#v) {
    my $variation_object = $self->new_object('Variation', $adaptor->fetch_by_name($v[$_]), $object->__data);
    $self->variation_content($variation_object, $lrg_slice, $v[$_], $vf[$_]);
  }
}

sub variation_content {
  my ($self, $object, $lrg, $v, $vf) = @_;
  my $hub        = $self->hub;
  my $variation  = $object->Obj;
  my $genes      = $variation->get_all_Genes;  
  my $feature    = $variation->get_VariationFeature_by_dbID($vf);
  my $seq_region = $feature->seq_region_name . ':';  
  my $chr_start  = $feature->start;
  my $chr_end    = $feature->end;
  my $allele     = $feature->allele_string;
  my $link       = '<a href="%s">%s</a>';
  my $position   = "$seq_region$chr_start";
  my $lrg_position;
  my %population_data;
  
  my %url_params  = (
    type   => 'Variation',
    v      => $v,
    vf     => $vf,
    source => $feature->source
  );
  
  if ($chr_end < $chr_start) {
    $position = "between $seq_region$chr_end &amp; $seq_region$chr_start";
  } elsif ($chr_end > $chr_start) {
    $position = "$seq_region$chr_start-$chr_end";
  }
  
  # Get a hash with HGVS names as URLs
  my $hgvs_urls  = $object->get_hgvs_names_url($vf, $hub->referer->{'ENSEMBL_TYPE'});
  my $hgvs_count = scalar keys %$hgvs_urls;
  my @hgvs_html;
  
  # Loop over and format the URLs
  foreach my $allele (keys %$hgvs_urls) {
    if ($hgvs_count > 1) {
      push @hgvs_html, '' if scalar @hgvs_html;
      push @hgvs_html, "<b>Variant allele $allele</b>";
    }
    
    push @hgvs_html, @{$hgvs_urls->{$allele}};
    push @hgvs_html, '' if $hgvs_count > 1;
  }
  
  # If we have an LRG in the URL, get the LRG coordinates as well
  if ($lrg) {
    my $lrg_feature = $feature->transfer($lrg);
    my $lrg_start   = $lrg_feature->start;
    my $lrg_end     = $lrg_feature->end;
    $lrg_position   = $lrg_feature->seq_region_name . ":$lrg_start";
    
    if ($lrg_end < $lrg_start) {
      $lrg_position = "between $lrg_end &amp; $lrg_start on " . $lrg_feature->seq_region_name;
    } elsif ($lrg_end > $lrg_start) {
      $lrg_position = $lrg_feature->seq_region_name . ":$lrg_start-$lrg_end";
    }
  }
   
  $allele = substr($allele, 0, 10) . '...' if length $allele > 10; # truncate very long allele strings
  
  my @entries = (
    { caption => 'Variation', entry => sprintf $link, $hub->url({ action => 'Summary', %url_params }), $v},
    { caption => 'Position',  entry => $position },
  );
  
  push @entries, { caption => 'LRG position',  entry => $lrg_position } if $lrg_position;
  
  if (scalar @hgvs_html) {
    if (scalar @hgvs_html > 1) {
      push @entries, { cls     => 'hgvs', entry => 'HGVS notation' };
      push @entries, { childOf => 'hgvs', entry => [ '', $_ ]} for @hgvs_html;
    } else {
      push @entries, { caption => 'HGVS notation', entry => $hgvs_html[0] };
    }
  }
  
  push @entries, (
    { caption => 'Alleles', entry => $allele },
    { caption => 'Type',    entry => $feature->display_consequence },
    { entry => sprintf $link, $hub->url({ action => 'Mappings', %url_params }), 'Gene/Transcript Locations' }
  );
  
  push @entries, { entry => sprintf $link, $hub->url({ action => 'Phenotype', %url_params }), 'Phenotype Data' } if scalar @{$object->get_external_data};
  
  foreach my $pop (
    sort { $a->{'pop_info'}->{'Name'} cmp $b->{'pop_info'}->{'Name'} }
    sort { $a->{'submitter'} cmp $b->{'submitter'} }
    grep { $_->{'pop_info'}->{'Name'} =~ /^1000genomes.+pilot_\d/i }
    map  { values %$_ }
    values %{$object->freqs($feature)}
  ) {
    my $key  = join ', ', map { "$pop->{'Alleles'}->[$_]: " . sprintf '%.3f', $pop->{'AlleleFrequency'}->[$_] } 0..$#{$pop->{'Alleles'}}; # $key is the allele frequencies in the form C: 0.400, T: 0.600
    my $name = [ split /:/, $pop->{'pop_info'}->{'Name'} ]->[-1]; # shorten the population name
       $name =~ s/pilot_\d_//;
       $name =~ s/_panel//;
       $name =~ s/_/ /g;
    
    $population_data{$name}{$key} .= ($population_data{$name}{$key} ? ' / ' : '') . $pop->{'submitter'}; # concatenate population submitters if they provide the same frequencies
  }
  
  push @entries, { cls => 'population', entry => sprintf $link, $hub->url({ action => 'Population', %url_params }), 'Population Allele Frequencies' } if scalar keys %population_data;
  
  foreach my $name (keys %population_data) {
    my %display = reverse %{$population_data{$name}};
    my $i       = 0;
    
    foreach my $submitter (keys %display) {
      my @freqs = map { split /: /, $_ } split /, /, $display{$submitter};
      my $img;
      $img .= sprintf '<span class="freq %s" style="width:%spx"></span>', shift @freqs, 100 * shift @freqs while @freqs;
      
      push @entries, { childOf => 'population', entry => [ $i++ ? '' : $name, $submitter ]};
      push @entries, { childOf => 'population', entry => [ '', $img, "<div>$display{$submitter}</div>" ]};
    }
  }
  
  push @{$self->{'entries'}}, \@entries;
}

1;
