# $Id$

### A light-weight menu used on text sequence pages.
### Skips the standard rendering method in favour of raw content and speed

package EnsEMBL::Web::ZMenu::TextSequence;

use strict;

use Bio::EnsEMBL::Variation::Utils::Constants;

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
  my $adaptor = $hub->get_adaptor('get_VariationAdaptor', 'variation');
  
  if ($lrg && $hub->referer->{'ENSEMBL_TYPE'} eq 'LRG') {
    eval { $self->{'lrg_slice'} = $hub->get_adaptor('get_SliceAdaptor')->fetch_by_region('LRG', $lrg); };
  } elsif ($hub->referer->{'ENSEMBL_TYPE'} eq 'Transcript') {
    $self->{'transcript'} = $hub->get_adaptor('get_TranscriptAdaptor')->fetch_by_stable_id($hub->param('t'));
  }
  
  for (0..$#v) {
    my $variation_object = $self->new_object('Variation', $adaptor->fetch_by_name($v[$_]), $object->__data);
    $self->variation_content($variation_object, $v[$_], $vf[$_]);
  }
}

sub variation_content {
  my ($self, $object, $v, $vf) = @_;
  my $hub        = $self->hub;
  my $variation  = $object->Obj;  
  my $feature    = $variation->get_VariationFeature_by_dbID($vf);
  my $seq_region = $feature->seq_region_name . ':';  
  my $chr_start  = $feature->start;
  my $chr_end    = $feature->end;
  my $allele     = $feature->allele_string;
  my @failed     = @{$feature->variation->get_all_failed_descriptions};
  my $link       = '<a href="%s">%s</a>';
  my $position   = "$seq_region$chr_start";
  my ($lrg_position, %population_data, %population_allele);
  
  my %url_params = (
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
  
  # If we have an LRG in the URL, get the LRG coordinates as well
  if ($self->{'lrg_slice'}) {
    my $lrg_feature = $feature->transfer($self->{'lrg_slice'});
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
  
  if (scalar @failed) {
    push @entries, { caption => 'Failed status', entry => sprintf '<span style="color:red">%s</span>',shift @failed };
    push @entries, { caption => '',              entry => sprintf '<span style="color:red">%s</span>',shift @failed } while @failed;
  }
  
  #push @entries, { caption => 'Failed status', entry => join ', ', @failed } if scalar @failed;
  push @entries, { caption => 'LRG position', entry => $lrg_position } if $lrg_position;
  
  my %ct    = map { $_->SO_term => [ $_->label, $_->rank ] } values %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
  my %types = map @{$ct{$_}}, @{($self->{'transcript'} ? $feature->get_all_TranscriptVariations([$self->{'transcript'}])->[0] : $feature)->consequence_type};
  
  push @entries, (
    { caption => 'Alleles', entry => $allele },
    { caption => 'Types',   entry => sprintf '<ul>%s</ul>', join '', map "<li>$_</li>", sort { $types{$a} <=> $types{$b} } keys %types },
    { entry   => sprintf $link, $hub->url({ action => 'Mappings', %url_params }), 'Gene/Transcript Locations' }
  );
  
  push @entries, { entry => sprintf $link, $hub->url({ action => 'Phenotype', %url_params }), 'Phenotype Data' } if scalar @{$object->get_external_data};
  
  foreach my $pop (
    sort { $a->{'pop_info'}{'Name'} cmp $b->{'pop_info'}{'Name'} }
    sort { $a->{'submitter'} cmp $b->{'submitter'} }
    grep { $_->{'pop_info'}{'Name'} =~ /^1000genomes.+phase_\d/i }
    map  { values %$_ }
    values %{$object->freqs($feature)}
  ) {
    my $name = [ split /:/, $pop->{'pop_info'}{'Name'} ]->[-1]; # shorten the population name
       $name =~ /phase_1_(.+)/;
       $name = $1;

    my @afreqs = @{$pop->{'AlleleFrequency'}};
    foreach my $allele (@{$pop->{Alleles}}) {
    
      push (@{$population_allele{$name}}, $allele) if (!grep {$_ eq $allele} @{$population_allele{$name}});
      
      my $freq = sprintf '%.3f',shift(@afreqs);
      $population_data{$name}{$pop->{submitter}}{$allele} = $freq;
    }
  }
    
  push @entries, { cls => 'population', entry => sprintf $link, $hub->url({ action => 'Population', %url_params }), 'Population Allele Frequencies' } if scalar keys %population_data;
  
  foreach my $name (sort {($a !~ /ALL/) cmp ($b !~ /ALL/) || $a cmp $b} keys %population_data) {
    my $i = 0;
    
    foreach my $submitter (keys %{$population_data{$name}}) {
 
      my @freqs;
      my $af;
      # Keep the alleles order
      foreach my $al (@{$population_allele{$name}}) {
        if ($population_data{$name}{$submitter}{$al}){
          push @freqs, $al;
          push @freqs, $population_data{$name}{$submitter}{$al};
          $af .= $af ? ', ' : '';
          $af .= "$al: ".$population_data{$name}{$submitter}{$al};
        }
      }

      my $img;
         $img .= sprintf '<span class="freq %s" style="width:%spx"></span>', shift @freqs, 100 * shift @freqs while @freqs;

      $af = qq{<div>$af</div>};
      if ($submitter) {
        push @entries, { childOf => 'population', entry => [ $i++ ? '' : $name, $submitter ]};
        push @entries, { childOf => 'population', entry => [ '', $img, $af ]};
      } else {
        push @entries, { childOf => 'population', entry => [ $name, $img, $af ]};
      }
    }
  }
  unshift @{$self->{'entries'}}, \@entries;
}

1;
