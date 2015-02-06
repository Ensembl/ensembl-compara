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

package EnsEMBL::Web::ZMenu::Variation;

use strict;

use EnsEMBL::Draw::GlyphSet::_variation;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self       = shift;
  my $hub        = $self->hub;
  my $vf         = $hub->param('vf');
  my $db         = $hub->param('vdb');
  my $click_data = $self->click_data;
  my $i          = 0;
  my @features;
  
  if ($click_data) {
    @features = @{EnsEMBL::Draw::GlyphSet::_variation->new($click_data)->features};
    @features = () unless grep $_->dbID eq $vf, @features;
  } elsif (!$vf) {
    my $adaptor         = $hub->database($db)->get_VariationAdaptor;
    my @variation_names = split ',', $hub->param('v');
    my @regions         = split ',', $hub->param('regions');
    
    for (0..$#variation_names) {
      my ($chr, $start, $end) = split /\W/, $regions[$_];
      push @features, grep { $_->seq_region_name eq $chr && $_->seq_region_start == $start && $_->seq_region_end == $end } @{$adaptor->fetch_by_name($variation_names[$_])->get_all_VariationFeatures};
    }
  }
  
  @features = $hub->database($db)->get_VariationFeatureAdaptor->fetch_by_dbID($vf) unless scalar @features;
  
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
  my ($lrg_bp, $codon_change);

  my $var_styles = $self->hub->species_defs->colour('variation');
  my $colourmap  = $self->hub->colourmap;
  
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



  my $color = $var_styles->{$type} ? $colourmap->hex_by_name($var_styles->{$type}->{'default'}) : $colourmap->hex_by_name($var_styles->{'default'}->{'default'});
  my $consequence_label = $types->{$type}{'text'};

  if ($feature->most_severe_OverlapConsequence->SO_term eq $type) {
    my $cons_desc = $feature->most_severe_OverlapConsequence->description;
    $consequence_label = sprintf(
         '<nobr><span class="colour" style="background-color:%s">&nbsp;</span> '.
         '<span class="_ht conhelp coltab_text" title="%s">%s</span></nobr>',
         $color,
         $cons_desc,
         $types->{$type}{'text'}
    );
  }

  my $sources = join(', ', @{$feature->get_all_sources});
  
  my @entries = (
    [ 'Class',    $feature->var_class ],
    [ 'Location', $bp                 ]
  );
  push @entries, [ 'LRG location',   $lrg_bp              ] if $lrg_bp;
  push @entries, [ 'Alleles',        $alleles             ];
  push @entries, [ 'Ambiguity code', $feature->ambig_code ];
  push @entries, [ 'Global MAF',     $gmaf                ] if defined $gmaf;
  push @entries, [ 'Consequence',    $consequence_label   ];
  push @entries, [ 'Source',         $sources             ];
  
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
  
  $self->caption(sprintf '%s: %s', $feature->variation->is_somatic ? 'Somatic mutation' : 'Variation', $name);

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
      # http://varcache.lovd.nl/redirect/hg19.chr###ID### , e.g. for ID: 1:808922_808922(FAM41C:n.1101+570C>T)
      my $tmp_chr_end = ($chr_start>$chr_end) ? $chr_start+1 : $chr_end;
      my $external_url = $hub->get_ExtURL_link("View in $source", 'LOVD', { ID => "$chr:$chr_start\_$tmp_chr_end($name)" });
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
    $self->add_entry({
      type     => 'Evidence',
      label    => join(', ', @{$feature->get_all_evidence_values || []}) || '-',
      position => (scalar @entries)+1 # Above "Source"
    });
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
  
  if (scalar @{$hub->database($db)->get_PhenotypeFeatureAdaptor->fetch_all_by_VariationFeature_list([ $feature ]) || []}) {
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

1;
