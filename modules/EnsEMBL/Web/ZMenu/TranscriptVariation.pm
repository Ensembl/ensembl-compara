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

package EnsEMBL::Web::ZMenu::TranscriptVariation;

use strict;

use Bio::EnsEMBL::Variation::Utils::Sequence qw(ambiguity_code);

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self             = shift;
  my $hub              = $self->hub; 
  my $v_id             = $hub->param('v');
  my $alt_allele       = $hub->param('alt_allele');
  my $aa_change        = $hub->param('aa_change');
  my $cov              = $hub->param('cov');
  my $codon            = $hub->param('codon');
  my $is_sara          = $hub->param('sara');
  my $db_adaptor       = $hub->database('variation');
  my $var_adaptor      = $db_adaptor->get_VariationAdaptor;
  my $var_feat_adaptor = $db_adaptor->get_VariationFeatureAdaptor;
  my $var              = $var_adaptor->fetch_by_name($v_id); 
  my $vf               = $var_feat_adaptor->fetch_all_by_Variation($var);  
  my $strain           = $hub->species_defs->translate('strain');
  my $trans_id         = $self->object->stable_id;
  my $feature;
 
  if (scalar @$vf == 1) {
    $feature = $vf->[0];
  } else {
    foreach (@$vf) {
      $feature = $_ if $_->dbID eq $vf;
    }
  }

  my $tc;
  
  if(!$is_sara && $codon) {
    my @codons = split /\s|\|/, $codon;
    $codons[1] =~ s/([A-Z])/<strong>$1<\/strong>/g;
    $codons[1] =~ tr/acgt/ACGT/;
    $codons[2] =~ s/([A-Z])/<strong>$1<\/strong>/g;
    $codons[2] =~ tr/acgt/ACGT/;
    $tc = "$codons[0] to $codons[1]\|$codons[2]";
  }
  
  my $chr_start  = $feature->start;
  my $chr_end    = $feature->end;
  my $ref_allele = $feature->ref_allele_string;
  my $type       = $is_sara ? 'SARA' : $feature->display_consequence('label');
  my $bp         = $chr_start;
  
  if ($chr_end < $chr_start) {
    $bp = "between $chr_end & $chr_start";
  } elsif ($chr_end > $chr_start) {
    $bp = "$chr_start - $chr_end";
  }
  
  $ref_allele = length $ref_allele < 16 ? $ref_allele : substr($ref_allele, 0, 14) . '..';
  
  my $ambig_code = $type eq 'SARA' ? '' : ambiguity_code(join '|', $alt_allele);
  my $class      = $feature->var_class;

  $self->caption($feature->variation_name);
  
  $self->add_entry({
    label_html => 'Variant properties',
    link       => $hub->url({
      type   => 'Variation', 
      action => 'Explore',
      v      => $feature->variation_name,
      vf     => $feature->dbID,
      source => $feature->source
    })
  });
  
  $self->add_entry({
    type  => 'bp',
    label => $bp
  });
  
  $self->add_entry({
    type  => 'Class',
    label => $class
  });
  
  $self->add_entry({
    type  => 'Reference allele',
    label => $ref_allele
  });
  
  $self->add_entry({
    type  => $strain . ' genotype',
    label => $alt_allele
  });
  
  if ($ambig_code) {
    $self->add_entry({
      type => 'Ambiguity code', 
      label => $ambig_code
    });
  }
  
  if ($aa_change) {
    $self->add_entry({
      type  => 'Amino acid change',
      label => $aa_change
    });
  }

  if ($tc) {
    $self->add_entry({
      type => 'Codon change',
      label_html => "$tc"
    });
  }
  
  if ($cov) {
    $self->add_entry({
      type  => 'Resequencing coverage',
      label => $cov
    });
  }
  
  $self->add_entry({
    type  => 'Source',
    label => join ', ', @{$feature->get_all_sources ||[]}
  });

  $self->add_entry({
    type  =>  'Type',
    label => $type
  });
}

1;
