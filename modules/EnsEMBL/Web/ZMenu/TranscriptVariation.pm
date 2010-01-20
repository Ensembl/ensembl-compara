# $Id$

package EnsEMBL::Web::ZMenu::TranscriptVariation;

use strict;

use Bio::EnsEMBL::Variation::Utils::Sequence qw(ambiguity_code variation_class);

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  my $object           = $self->object; 
  my $v_id             = $object->param('v');
  my $vf               = $object->param('vf');
  my $alt_allele       = $object->param('alt_allele');
  my $aa_change        = $object->param('aa_change');
  my $cov              = $object->param('cov');
  my $db_adaptor       = $object->database('variation');
  my $var_adaptor      = $db_adaptor->get_VariationAdaptor;
  my $var_feat_adaptor = $db_adaptor->get_VariationFeatureAdaptor;
  my $var              = $var_adaptor->fetch_by_name($v_id); 
  my $vf               = $var_feat_adaptor->fetch_all_by_Variation($var);  
  my $strain           = $object->species_defs->translate('strain');
  my $feature;
  my $trans_id         = $object->stable_id;
 
  if (scalar @$vf == 1) {
    $feature = $vf->[0];
  } else {
    foreach (@$vf) {
      $feature = $_ if $_->dbID eq $object->param('vf');
    }
  }

  my $tc;
  foreach ( @{$feature->get_all_TranscriptVariations()} ){
    if ($trans_id eq $_->transcript->stable_id){
      my $codon = $_->codons;
      my @bases = split(//, $codon);
      foreach my $base (@bases){
        if( $base =~/[A-Z]/){
          $base = "<strong>$base</strong>";
        }  
        $tc .= $base;
      }
      $tc = "<strong>Codon change </strong> $tc"; 
    }
  }
  
  my $chr_start  = $feature->start;
  my $chr_end    = $feature->end;
  my $ref_allele = $feature->ref_allele_string;
  my $type       = $object->param('sara') ? 'SARA' : $feature->display_consequence;
  my $bp         = $chr_start;
  
  if ($chr_end < $chr_start) {
    $bp = "between $chr_end & $chr_start";
  } elsif ($chr_end > $chr_start) {
    $bp = "$chr_start - $chr_end";
  }
  
  $ref_allele = length $ref_allele < 16 ? $ref_allele : substr($ref_allele, 0, 14) . '..';
  
  my $ambig_code = $type eq 'SARA' ? '' : ambiguity_code(join '|', $ref_allele, $alt_allele);
  my $class      = variation_class(join '|', $ref_allele, $alt_allele);

  $self->caption($feature->variation_name);
  
  $self->add_entry({
    label_html => 'Variation properties',
    link       => $object->_url({
      type   => 'Variation', 
      action => 'Summary',
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
      type  => 'Amino acid',
      label => $aa_change
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

  if ($tc) {
    $self->add_entry({
      label_html => "$tc"
    });
  }
}

1;
