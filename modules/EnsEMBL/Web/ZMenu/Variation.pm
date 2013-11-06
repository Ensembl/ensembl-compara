# $Id$

package EnsEMBL::Web::ZMenu::Variation;

use strict;

use Bio::EnsEMBL::GlyphSet::_variation;

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
    @features = @{Bio::EnsEMBL::GlyphSet::_variation->new($click_data)->features};
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
  my $source        = $feature->source;
  my $bp            = "$chr:$chr_start";
  my $types         = $hub->species_defs->colour('variation');
  my $type          = $consequence && !($snp_fake || $var_box) ? $consequence : $feature->display_consequence;
  my $allele        = $feature->allele_string;
  my $alleles       = length $allele < 16 ? $allele : substr($allele, 0, 14) . '..';
  my $gmaf          = $feature->minor_allele_frequency . ' (' . $feature->minor_allele . ')' if defined $feature->minor_allele;
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
  
  my @entries = (
    [ 'bp',             $bp                                      ],
    [ 'Class',          $feature->var_class                      ],
    [ 'Ambiguity code', $feature->ambig_code                     ],
    [ 'Alleles',        $alleles                                 ],
    [ 'Source',         join(', ', @{$feature->get_all_sources}) ],
    [ 'Type',           $types->{$type}{'text'}                  ],
  );
  
  unshift @entries, [ 'LRG bp',     $lrg_bp ] if $lrg_bp;
  push    @entries, [ 'Global MAF', $gmaf   ] if defined $gmaf;
  
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
  
  $self->add_entry({
    label_html => "$name properties",
    link       => $hub->url({
      type   => 'Variation', 
      action => 'Summary',
      v      => $name,
      vf     => $dbID,
      source => $source
    })
  });
  
  $self->add_entry({ type => $_->[0], label => $_->[1] }) for grep $_->[1], @entries;
  $self->add_entry({ label_html => $codon_change }) if $codon_change;

  if ($var_box && $var_box ne '-') {
    $self->add_entry({
      type     => 'Amino acid',
      label    => $var_box,
      position => 5
    });
  } elsif ($snp_fake || $hub->type eq 'Variation') {    
    $self->add_entry({
      type     => 'Status',
      label    => join(', ', @{$feature->get_all_evidence_values || []}) || '-',
      position => $snp_fake && $lrg_bp ? 4 : 3
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
