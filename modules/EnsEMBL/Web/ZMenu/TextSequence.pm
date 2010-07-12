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
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object;
  my @v       = $hub->param('v');
  my @vf      = $hub->param('vf');
  my $lrg     = $hub->param('lrg')
  my $adaptor = $hub->database('variation')->get_VariationAdaptor;
  my $lrg_slice;
  
  if ($lrg) {
    my $core_adaptor = $hub->database('core')->get_SliceAdaptor;
    eval { $lrg_slice = $core_adaptor->fetch_by_region('LRG', $lrg); };
  }
  
  for (0..$#v) {
    my $variation_object = $self->new_object('Variation', $adaptor->fetch_by_name($v[$_]), $object->__data);
    $self->variation_content($variation_object, $lrg_slice, $v[$_], $vf[$_]);
  }
}  

sub variation_content {
  my ($self, $object, $lrg, $v, $vf) = @_;
  
  my $hub         = $self->hub;
  my $variation   = $object->Obj;
  my $genes       = $variation->get_all_Genes;  
  my $feature     = $variation->get_VariationFeature_by_dbID($vf);
  my $allele      = $feature->allele_string;
  my $seq_region  = $feature->seq_region_name;
  my $chr_start   = $feature->start;
  my $chr_end     = $feature->end;
  my $position    = "$seq_region:$chr_start";
  my $link        = '<a href="%s">%s</a>';

  if ($lrg) {
    my $fSlice    = $lrg->feature_Slice;
    my $lrg_start = $fSlice->start - 1;
    $chr_start   -= $lrg_start;
    $chr_end     -= $lrg_start;
    $position     = $chr_start;
  }
  
  my %url_params  = (
    type   => 'Variation',
    v      => $v,
    vf     => $vf,
    source => $feature->source
  );
  
  my %population_data;
  
  if ($chr_end < $chr_start) {
    $position = "between $seq_region:$chr_end &amp; $seq_region:$chr_start";
  } elsif ($chr_end > $chr_start) {
    $position = "$seq_region:$chr_start-$chr_end";
  }
  
  $allele = substr($allele, 0, 10) . '...' if length $allele > 10; # truncate very long allele strings
  
  my @entries = (
    { caption => 'Variation', entry => sprintf $link, $hub->url({ action => 'Summary', %url_params }), $v},
    { caption => 'Position',  entry => $position },
    { caption => 'Alleles',   entry => $allele   },
    { entry => sprintf $link, $hub->url({ action => 'Mappings', %url_params }), 'Gene/Transcript Locations' }
  );
  
  push @entries, { entry => sprintf $link, $hub->url({ action => 'Phenotype', %url_params }), 'Phenotype Data' } if scalar @{$object->get_external_data};
  
  foreach my $pop (
    sort { $a->{'pop_info'}->{'Name'} cmp $b->{'pop_info'}->{'Name'} }
    sort { $a->{'submitter'} cmp $b->{'submitter'} }
    grep { $_->{'pop_info'}->{'Name'} =~ /HapMap/ }
    map  { values %$_ }
    values %{$object->freqs($feature)}
  ) {
    my $name = [ split /:/, $pop->{'pop_info'}->{'Name'} ]->[-1]; # shorten the population name
    my $key  = join ', ', map { "$pop->{'Alleles'}->[$_]: " . sprintf '%.3f', $pop->{'AlleleFrequency'}->[$_] } 0..$#{$pop->{'Alleles'}}; # $key is the allele frequencies in the form C: 0.400, T: 0.600
    
    $population_data{$name}{$key} .= ($population_data{$name}{$key} ? ' / ' : '') . $pop->{'submitter'}; # concatenate population submitters if they provide the same frequencies
  }
  
  push @entries, { cls => 'population', entry => sprintf $link, $hub->url({ action => 'Population', %url_params }), 'Population Allele Frequencies' } if scalar keys %population_data;
  
  foreach my $name (keys %population_data) {
    my %display = reverse %{$population_data{$name}};
    my $i = 0;
    
    foreach my $submitter (keys %display) {
      my @freqs = map { split /: /, $_ } split /, /, $display{$submitter};
      my $img;
      
      $img .= sprintf '<img class="freq %s" width="%s" src="/i/blank.gif" />', shift @freqs, 100 * shift @freqs while @freqs;
      
      push @entries, { childOf => 'population', entry => [ $i++ ? '' : $name, $submitter ]};
      push @entries, { childOf => 'population', entry => [ '', $img, "<div>$display{$submitter}</div>" ]};
    }
  }
  
  push @{$self->{'entries'}}, \@entries;
}

1;
