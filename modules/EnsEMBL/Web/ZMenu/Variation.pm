=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ZMenu::Variation;

use strict;

use EnsEMBL::Draw::GlyphSet::_variation;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self       = shift;
  my $hub        = $self->hub;
  my $vf         = $hub->param('vf');
  my $db         = $hub->param('vdb') || 'variation';
  my $click_data = $self->click_data;
  my $i          = 0;
  my @features;

  my $vf_adaptor = $hub->database($db)->get_VariationFeatureAdaptor;

  if ($click_data) {
    @features = @{EnsEMBL::Draw::GlyphSet::_variation->new($click_data)->features};
    @features = () unless grep $_->{'dbID'} eq $vf, @features;
    @features = map { $vf_adaptor->fetch_by_dbID($_->{'dbID'}) } @features;
  } elsif (!$vf) {
    my $adaptor         = $hub->database($db)->get_VariationAdaptor;
    my @variation_names = split ',', $hub->param('v');
    my @regions         = split ',', $hub->param('regions');
    
    for (0..$#variation_names) {
      my ($chr, $start, $end) = split /\W/, $regions[$_];
      push @features, grep { $_->seq_region_name eq $chr && $_->seq_region_start == $start && $_->seq_region_end == $end } @{$adaptor->fetch_by_name($variation_names[$_])->get_all_VariationFeatures};
    }
  }
  
  @features = $vf_adaptor->fetch_by_dbID($vf) unless scalar @features;
  
  $self->{'feature_count'} = scalar @features;
  
  $self->feature_content($_, $db, $i++) for @features;
}

sub feature_content {
  my ($self, $feature, $db, $i) = @_;
  my $hub           = $self->hub;
  my $snp_fake      = $hub->param('snp_fake');
  my $var_box       = $hub->param('var_box');
  my $lrg           = $hub->param('lrg');
  my $p_value       = $hub->param('p_value');
  my $transcript_id = $hub->param('t_id');
  my $consequence   = $hub->param('consequence');
  my $ld_r2         = $hub->param('r2');
  my $ld_d_prime    = $hub->param('d_prime');
  my $ld_pop_id     = $hub->param('pop_id');
  my $chr_start     = $feature->seq_region_start;
  my $chr_end       = $feature->seq_region_end;
  my $chr           = $feature->seq_region_name;
  my $name          = $feature->variation_name;
  my $dbID          = $feature->dbID;
  my $source        = $feature->source_name;
  my $bp            = "$chr:$chr_start";
  my $types         = $hub->species_defs->colour('variation');
  my $type          = $consequence && !($snp_fake || $var_box) ? $consequence : $feature->display_consequence;
  my $allele        = $feature->allele_string;
  my $alleles       = length $allele < 16 ? $allele : substr($allele, 0, 14) . '..';
  my $gmaf          = $feature->minor_allele_frequency . ' (' . $feature->minor_allele . ')' if defined $feature->minor_allele;
  my $colourmap     = $hub->colourmap;
  my ($lrg_bp, $codon_change);

  
  $self->new_feature;
  
  if ($chr_end < $chr_start) {
    $bp = "$chr: between $chr_end & $chr_start";
  } elsif ($chr_end > $chr_start) {
    $bp = "$chr:$chr_start-$chr_end";
  }
  
  if ($snp_fake && $lrg) {
    my $lrg_slice;
    
    eval { $lrg_slice = $hub->get_adaptor('get_SliceAdaptor')->fetch_by_region('LRG', $lrg); };
    
    if ($lrg_slice) {
      my $lrg_feature = $feature->transfer($lrg_slice);
      
      $chr_start = $lrg_feature->start;
      $chr_end   = $lrg_feature->end;
      $lrg_bp    = $chr_start;
      
      if ($chr_end < $chr_start) {
        $lrg_bp = "between $chr_end & $chr_start";
      } elsif ($chr_end > $chr_start) {
        $lrg_bp = "$chr_start-$chr_end";
      }
    }
  }

  my $consequence_label = $feature->most_severe_OverlapConsequence->SO_term eq $type ? $self->variant_consequence_label($type) : $types->{lc $type}{'text'};
  my $sources_list      = $feature->get_all_sources;
  my $source_label      = 'Source'.(scalar @$sources_list > 1 ? 's' : ''); 
  my $sources           = join(', ', @$sources_list);

  my @entries = ([ 'Class', $feature->var_class ]);

  push @entries, [
    'Location',
    sprintf('%s<a href="%s" class="_location_mark hidden"></a>',
      $bp,
      $hub->url({
        type    => 'Location',
        action  => 'View',
        r       => "$chr:$chr_start-$chr_end"
      })
    )
  ];

  push @entries, [ 'LRG location',   $lrg_bp                       ] if $lrg_bp;
  push @entries, [ 'Alleles',        $alleles                      ];
  push @entries, [ 'Ambiguity code', $feature->ambig_code          ];
  push @entries, [ 'Global MAF',     $gmaf                         ] if defined $gmaf;
  push @entries, [ 'Consequence',    $consequence_label            ];
  push @entries, [ $source_label,    $sources                      ];
  push @entries, [ 'Description',    $feature->source->description ] if ($db ne 'variation');
  push @entries, [ 'LD r2',          $ld_r2                        ] if defined $ld_r2;
  push @entries, [ 'LD D prime',     $ld_d_prime                   ] if defined $ld_d_prime;
 
  if ($transcript_id) {
    foreach (@{$feature->get_all_TranscriptVariations}) {
      if ($transcript_id eq $_->transcript->stable_id) {
        my $codon = $_->codons;
           $codon =~ s/([A-Z])/<strong>$1<\/strong>/g;
           
        next unless $codon =~ /\w+/;
        
        $codon_change = "<strong>Codon change</strong> $codon";
      }
    }  
  }
  
  $self->caption(sprintf '%s: %s', $feature->variation->is_somatic ? 'Somatic mutation' : 'Variant', $name);

  if ($db eq 'variation') {
    $self->add_entry({
      label_html => "more about $name",
      link       => $hub->url({
        type   => 'Variation',
        action => 'Explore',
        v      => $name,
        vf     => $dbID,
        source => $source
      })
    });

  } else {
    if ($source eq 'LOVD') {
      # http://varcache.lovd.nl/redirect/hg38.chr###ID### , e.g. for ID: 1:808922_808922(FAM41C:n.1101+570C>T)
       my $position = ($chr_start>$chr_end) ? "$chr_end\_$chr_start" : "$chr_start\_$chr_end";
       my $external_url = $hub->get_ExtURL_link("View in $source", 'LOVD', { ID => "$chr:$position($name)" });
       $self->add_entry({
         label_html => $external_url
       });
    }
    elsif ($source =~ /DECIPHER/i) {
      # https://decipher.sanger.ac.uk/browser#q/20:62037542-62103993
      my ($id,$chr,$start,$end) = split('_',$name);
      my $external_url = $hub->get_ExtURL_link("View in $source (GRCh37)", 'DECIPHER_BROWSER', { ID => "$chr:$start-$end" });
      $self->add_entry({
        label_html => $external_url
      });
    }
    elsif ($source =~ /Mastermind/i) {
      my $external_url = $hub->get_ExtURL_link("View in $source", 'Mastermind', { ID => $name });
       $self->add_entry({
         label_html => $external_url
       });
    }
    else {
      my $external_url = $hub->get_ExtURL_link("View in $source", uc($source));
      $self->add_entry({
         label_html => $external_url
      });
    }
  }
  
  $self->add_entry({ type => $_->[0], label_html => $_->[1] }) for grep $_->[1], @entries;
  $self->add_entry({ label_html => $codon_change }) if $codon_change;

  if ($var_box && $var_box ne '-') {
    $self->add_entry({
      type     => 'Amino acid',
      label    => $var_box,
      position => 6
    });
  } elsif ($snp_fake || $hub->type eq 'Variation') {
    my $evidences = $feature->get_all_evidence_values || [];
    my $evidence_label = 'Evidence'.(scalar @$evidences > 1 ? 's' : ''); 
    if (scalar @$evidences) {
      $self->add_entry({
        type     => $evidence_label,
        label    => join(', ', @{$evidences}) || '-',
        position => (scalar @entries)+1 # Above "Source"
      });
    }
  }
  
  if (defined $p_value) {
    if ($p_value =~ /,/) {
      my @p_values = split /,/, $p_value;
      
      for (my $j = $i; $j >= 0; $j--) {
        $p_value = $p_values[$j];
        last if $p_value;
      }
    }
    
    $self->add_entry({
      type  => $hub->param('ftype') eq 'Phenotype' ? 'p-value (negative log)' : 'p-value',
      label => $p_value,
    });
  }
  
  return if $self->{'feature_count'} > 5;
  
  foreach (@{$feature->get_all_Alleles}) {
    my $population = $_->population;
    
    if ($population && $population->{'freqs'}) {
      $self->add_entry({
        label_html => 'Population genetics',
        link       => $hub->url({
          type   => 'Variation',
          action => 'Population',
          v      => $name,
          vf     => $dbID,
          source => $source
        }),
      });
      
      last;
    }
  }

  # LD Manhattan plot
  if ($ld_pop_id) {
    $self->add_entry({
      label_html => 'LD Manhattan plot',
      link       => $hub->url({
        type   => 'Variation',
        action => 'LDPlot',
        v      => $name,
        vf     => $dbID,
        pop1   => $ld_pop_id
      })
    });
  }

  my $pfs = $hub->database($db)->get_PhenotypeFeatureAdaptor->fetch_all_by_VariationFeature_list([ $feature ]) || [];
  if (scalar @{$pfs}) {
    # Display associated phenotype for private database
    if ($hub->param('vdb') ne 'variation') {
      my $phenotypes = join(', ', map { $_->phenotype->description } @$pfs);
      $self->add_entry({
        type  => 'Phenotype'.(scalar @$pfs > 1 ? 's' : ''),
        label => $phenotypes,
      });
    }
    else {
      $self->add_entry({
        label_html => 'Phenotype data',
        link       => $hub->url({
            type   => 'Variation',
            action => 'Phenotype',
            v      => $name,
            vf     => $dbID,
            source => $source
          }),
      });
    }
  }
}

1;
