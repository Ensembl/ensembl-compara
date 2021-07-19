=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ZMenu::TextSequence;

use strict;
use Bio::EnsEMBL::Utils::Sequence qw(reverse_comp);
use Bio::EnsEMBL::Variation::Utils::Constants;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self    = shift;
  my $hub     = $self->hub;
  my $object  = $self->object;
  my @vf      = $hub->param('vf');
  my $lrg     = $hub->param('lrg');
  my $adaptor = $hub->get_adaptor('get_VariationAdaptor', 'variation');
  
  $object = $self->hub->core_object('LRG') unless defined $object;

  if ($lrg && $hub->referer->{'ENSEMBL_TYPE'} eq 'LRG') {
    eval { $self->{'lrg_slice'} = $hub->get_adaptor('get_SliceAdaptor')->fetch_by_region('LRG', $lrg); };
  } elsif (($hub->referer->{'ENSEMBL_TYPE'} eq 'Transcript' || $hub->param('_transcript')) && !$hub->param('flanking_variant')) {
    $self->{'transcript'} = $hub->get_adaptor('get_TranscriptAdaptor')->fetch_by_stable_id($hub->param('_transcript') || $hub->param('t'));
  }
 
  my $vfa = $hub->get_adaptor('get_VariationFeatureAdaptor','variation'); 
  foreach (@vf) {
    my $feature = $vfa->fetch_by_dbID($_);
    my $variation = $feature->variation();
    my $variation_object = $self->new_object('Variation', $variation, $object->__data);
    $self->variation_content($variation_object, $feature);
    $self->new_feature;
  }
}

sub variation_content {
  my ($self, $object, $feature) = @_;
  my $hub        = $self->hub;
  my $variation  = $object->Obj;  
  my $seq_region = $feature->seq_region_name . ':';  
  my $chr_start  = $feature->seq_region_start;
  my $chr_end    = $feature->seq_region_end;
  my $allele     = $feature->allele_string;
  my @failed     = @{$feature->variation->get_all_failed_descriptions};
  my $position   = "$seq_region$chr_start";

  my ($lrg_position, %population_data, %population_allele);
 
  my $v = $feature->variation()->name(); 
  my %url_params = (
    type   => 'Variation',
    v      => $v,
    vf     => $feature->dbID(),
    source => $feature->source_name,
  );
  
  if ($chr_end < $chr_start) {
    $position = "between $seq_region$chr_end & $seq_region$chr_start";
  } elsif ($chr_end > $chr_start) {
    $position = "$seq_region$chr_start-$chr_end";
  }
  
  my $lrg_allele = $allele;
 
  $allele = substr($allele, 0, 10) . '...' if length $allele > 10; # truncate very long allele strings

  my $allele_strand = ($feature->seq_region_strand == 1) ? '(Forward strand)' : '(Reverse strand)';

  $self->caption(sprintf('%s: <a href="%s">%s</a>', $feature->variation->is_somatic ? 'Somatic mutation' : 'Variation', $hub->url({ action => 'Explore', %url_params }), $v), 1);
  
  my @entries = ({ type => 'Class',  label => $feature->var_class });
  push @entries, { type => 'Source', label => $feature->source_name };
 
  if (scalar @failed) {
    push @entries, { type => 'Failed status', label_html => sprintf '<span style="color:red">%s</span>', shift @failed };
    push @entries, { type => '',              label_html => sprintf '<span style="color:red">%s</span>', shift @failed } while @failed;
  }
  push @entries, { type => 'Location', label => $position };
  push @entries, { type => 'Alleles',  label => "$allele $allele_strand" };


  # If we have an LRG in the URL, get the LRG coordinates as well
  if ($self->{'lrg_slice'}) {
    my $lrg_feature = $feature->transfer($self->{'lrg_slice'});
    my $lrg_start   = $lrg_feature->seq_region_start;
    my $lrg_end     = $lrg_feature->seq_region_end;
    my $lrg_mapping_strand = $self->{'lrg_slice'}->feature_Slice->strand;

    $lrg_position = $lrg_feature->seq_region_name . ":$lrg_start";

    if ($lrg_end < $lrg_start) {
      $lrg_position = "between $lrg_end & $lrg_start on " . $lrg_feature->seq_region_name;
    } elsif ($lrg_end > $lrg_start) {
      $lrg_position = $lrg_feature->seq_region_name . ":$lrg_start-$lrg_end";
    }

    push @entries, { type => 'LRG location', label => $lrg_position } if ($lrg_position);


    # Flip the LRG alleles if it maps to the reverse strand
    if ($lrg_mapping_strand == -1) {
      my @alleles = split('/',$lrg_allele);
      foreach my $l_allele (@alleles) {
        next if ($l_allele !~ /^[ATGCN]+$/);
        reverse_comp(\$l_allele);
      }
      $lrg_allele = join('/',@alleles);
    }
    $lrg_allele = substr($lrg_allele, 0, 10) . '...' if length $lrg_allele > 10; # truncate very long allele strings
    
    if ($lrg_allele ne $allele) {
      push @entries, { type => 'LRG alleles', label => $lrg_allele };
    }
  }

  
  if ($self->{'transcript'}) {
    my $tv = $feature->get_all_TranscriptVariations([$self->{'transcript'}])->[0];
    
    if ($tv) {
      my $pep_alleles = $tv->pep_allele_string;
      my $codons      = $tv->codons;
      my $cdna_pos    = $tv->cdna_start;
      my $aa_pos      = $tv->translation_start;
      ## Also truncate long peptides
      if (length $pep_alleles > 10) {
        $pep_alleles =~ /(\w{10})\w+(\w\/\w)(\w+)/;
        $pep_alleles = $1.'...'.$2;
        $pep_alleles .= '...' if $3;
      }
      if (length $codons > 10) {
        $codons =~ /(\w{10})\w+(\w\/\w)(\w+)/;
        $codons = $1.'...'.$2;
        $codons .= '...' if $3;
      }

      push @entries, { type => 'cDNA position', 'label' => $cdna_pos} if $cdna_pos; 
      push @entries, { type => 'Protein position', 'label' => $aa_pos} if $aa_pos; 
      
      push @entries, { type => 'Amino acids', label => $pep_alleles} if $pep_alleles && $pep_alleles =~ /\//;
      push @entries, { type => 'Codons',      label => $codons}      if $codons      && $codons      =~ /\//;
    }
  }

  # Consequence terms and display
  my %feature_cons = map { $_ => 1 } @{($self->{'transcript'} ? $feature->get_all_TranscriptVariations([$self->{'transcript'}])->[0] : $feature)->consequence_type};
  my @feature_cons = map $self->variant_consequence_label($_), grep { $feature_cons{$_} } map { $_->SO_term } sort { $a->rank <=> $b->rank } values %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;

  push @entries, (
    { type  => 'Consequences',                                 label_html => sprintf('<ul>%s</ul>', join('', map("<li>$_<li>", @feature_cons))) },
    { link  => $hub->url({ action => 'Explore', %url_params}), label      => 'Explore this variant' }
  );

  # Check that the variant overlaps at least one transcript
  if ($object->count_transcripts) {
    push @entries, { link => $hub->url({ action => 'Mappings', %url_params }), label => 'Gene/Transcript Locations' };
  }

  push @entries, { link => $hub->url({ action => 'Phenotype', %url_params }), label => 'Phenotype Data' } if scalar @{$object->get_external_data};

  foreach my $pop (sort { $a->{'pop_info'}{'Name'} cmp $b->{'pop_info'}{'Name'} } grep { $_->{'pop_info'}{'Name'} =~ /^1000genomes.+phase_\d/i } values %{$object->freqs($feature)}) {

    next if (!scalar keys %{$pop->{'pop_info'}{'Sub-Population'}});

    my $name = [ split /:/, $pop->{'pop_info'}{'Name'} ]->[-1]; # shorten the population name
    
    foreach my $ssid (sort { $a->{'submitter'} cmp $b->{'submitter'} } values %{$pop->{'ssid'}}) {
      my @afreqs = @{$ssid->{'AlleleFrequency'}};
      
      foreach my $allele (@{$ssid->{'Alleles'}}) {
        push @{$population_allele{$name}}, $allele unless grep $_ eq $allele, @{$population_allele{$name}};
        $population_data{$name}{$ssid->{'submitter'}}{$allele} = sprintf '%.3f', shift @afreqs;
      }
    }
  }
    
  push @entries, { class => 'population', link => $hub->url({ action => 'Population', %url_params }), label => 'Population Allele Frequencies' } if scalar keys %population_data;

  my %colours;
  $colours{$_} = "base_$_" for(qw(C G A T));
  foreach my $name (sort { !$a <=> !$b || $b =~ /ALL/ cmp $a =~ /ALL/ || $a cmp $b } keys %population_data) {
    my %display = reverse %{$population_data{$name}};
    my $i       = 0;
    
    foreach my $submitter (keys %{$population_data{$name}}) {
      my (@freqs, $af);
      
      # Keep the alleles order
      foreach my $al (@{$population_allele{$name}}) {
        if ($population_data{$name}{$submitter}{$al}){
          $colours{$al} ||= "base_".(scalar(keys %colours)%4);
          push @freqs, $colours{$al};
          push @freqs, $population_data{$name}{$submitter}{$al};
          $af .= $af ? ', ' : '';
          $af .= "$al: $population_data{$name}{$submitter}{$al}";
        }
      }
      
      my $img;
         $img .= sprintf '<span class="freq %s" style="width:%spx"></span>', shift @freqs, 100 * shift @freqs while @freqs;
         $af   = "<div>$af</div>";
      
      if ($submitter) {
        push @entries, { childOf => 'population', type => $i++ ? ' ' : $name || ' ', label_html => $submitter };
        push @entries, { childOf => 'population', type => ' ', label_html => "$img$af" };
      } else {
        push @entries, { childOf => 'population', type => $name, label_html => "$img$af" };
      }
    }
  }
  
  $self->add_entry($_) for @entries;
}

1;
