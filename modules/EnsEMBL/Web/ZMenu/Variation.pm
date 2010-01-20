# $Id$

package EnsEMBL::Web::ZMenu::Variation;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  my $object           = $self->object;
  my $v_id             = $object->param('v');
  my $snp_fake         = $object->param('snp_fake');
  my $var_box          = $object->param('var_box');
  my $db_adaptor       = $object->database('variation');
  my $var_adaptor      = $db_adaptor->get_VariationAdaptor;
  my $var_feat_adaptor = $db_adaptor->get_VariationFeatureAdaptor;
  my $var              = $var_adaptor->fetch_by_name($v_id);
  my $vf               = $var_feat_adaptor->fetch_all_by_Variation($var);
  my $tvar_adaptor     = $db_adaptor->get_TranscriptVariationAdaptor;
  my $trans_variation  = $tvar_adaptor->fetch_by_dbID($object->param('vf'));
  my $type;
  my $feature;

  if (scalar @$vf == 1) {
    $feature = $vf->[0];
  } else {
    foreach (@$vf) {
      $feature = $_ if $_->dbID eq $object->param('vf');
    }
  }
  
  # alternate way to retrieve transcript_variation_feature if there are more than one with the same variation_feature id;
  if (!$trans_variation) {
    my $trans_id = $object->param('vt');
    
    if ($trans_id) {
      my $trans_adaptor = $object->database('core')->get_TranscriptAdaptor;
      my $transcript   = $trans_adaptor->fetch_by_stable_id($trans_id);
      
      foreach my $trv (@{$tvar_adaptor->fetch_all_by_Transcripts([$transcript])}) {
        $trans_variation = $trv if $trv->variation_feature->variation_name eq $feature->variation_name;
      }
    }
  }
  
  if (($snp_fake || $var_box) && $feature) {
    $type = $feature->display_consequence;
  } elsif ($trans_variation) {
    $type =  join ', ', @{$trans_variation->consequence_type||[]};
  } elsif ($object->param('consequence')) {
    $type = $object->param('consequence') || '';
  } else {
    $type = $feature->display_consequence;
  }

  my $chr_start = $feature->start;
  my $chr_end   = $feature->end;
  my $bp        = $chr_start;
  
  if ($chr_end < $chr_start) {
    $bp = "between $chr_end & $chr_start";
  } elsif ($chr_end > $chr_start) {
    $bp = "$chr_start - $chr_end";
  }
  
  my $source  = join ', ', @{$feature->get_all_sources||[]};
  my $allele  = $feature->allele_string;
  my $alleles = length $allele < 16 ? $allele : substr($allele, 0, 14) . '..';
  
  my @entries = (
    [ 'bp',             $bp                  ],
    [ 'Class',          $feature->var_class  ],
    [ 'Ambiguity code', $feature->ambig_code ],
    [ 'Alleles',        $alleles             ],
    [ 'Source',         $source              ],
    [ 'Type',           $type                ],
  );


 
  my $tc;
  if ($object->param('t_id')){
    foreach ( @{$feature->get_all_TranscriptVariations()} ){
      if ($object->param('t_id') eq $_->transcript->stable_id){
        my $codon = $_->codons;
        my @bases = split(//, $codon);
        foreach my $base (@bases){
          if( $base =~/[A-Z]/){
            $base = "<strong>$base</strong>";
          }
          $tc .= $base;
        }
        next unless $tc =~/\w+/;
        $tc = "<strong>Codon change </strong> $tc";
      }
    }  
  }
  
  $self->caption('Variation: ' . $feature->variation_name);
  
  $self->add_entry({
    label_html => 'Variation Properties',
    link       => $object->_url({
      type   => 'Variation', 
      action => 'Summary',
      v      => $feature->variation_name,
      vf     => $feature->dbID,
      source => $feature->source
    })
  });
  
  foreach (grep $_->[1], @entries) {
    $self->add_entry({
      type  => $_->[0],
      label => $_->[1]
    });
  }

  if ($tc =~/\w+/) {
    $self->add_entry({
      label_html => "$tc"
    });
  }

  if ($snp_fake) {
    my $status = join ', ', @{$feature->get_all_validation_states||[]};
    $self->add_entry({
      type     =>  'Status',
      label    => $status || '-',
      position => 3
    });
    
    $self->add_entry({
      type     => 'Mapweight',
      label    => $feature->map_weight,
      position => 6
    });
  } elsif ($var_box) {
    if ($var_box ne '-') {
      $self->add_entry({
        type     => 'Amino acid',
        label    => $var_box,
        position => 5
      });
    }
  } elsif ($object->type eq 'Variation') {
    my $status = join ', ', @{$feature->get_all_validation_states||[]};
    
    $self->add_entry({
      type     => 'status:',
      label    => $status || '-',
      position => 3
    });
  }
}

1;
  
