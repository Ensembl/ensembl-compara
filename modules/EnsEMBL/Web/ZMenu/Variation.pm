# $Id$

package EnsEMBL::Web::ZMenu::Variation;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self             = shift;
  my $hub              = $self->hub;
  my $v_id             = $hub->param('v');
  my $snp_fake         = $hub->param('snp_fake');
  my $var_box          = $hub->param('var_box');
  my $lrg              = $hub->param('lrg');
  my $db_adaptor       = $hub->database('variation');
  my $var_adaptor      = $db_adaptor->get_VariationAdaptor;
  my $var_feat_adaptor = $db_adaptor->get_VariationFeatureAdaptor;
  my $var              = $var_adaptor->fetch_by_name($v_id);
  my $vf               = $var_feat_adaptor->fetch_all_by_Variation($var);
  my $tvar_adaptor     = $db_adaptor->get_TranscriptVariationAdaptor;
  my $trans_variation  = $tvar_adaptor->fetch_by_dbID($hub->param('vf'));
  my $type;
  my $feature;
  
  my $p_value = $hub->param('p_value');

  if (scalar @$vf == 1) {
    $feature = $vf->[0];
  } else {
    foreach (@$vf) {
      $feature = $_ if $_->dbID eq $hub->param('vf');
    }
  }
  
  # alternate way to retrieve transcript_variation_feature if there are more than one with the same variation_feature id;
  if (!$trans_variation) {
    my $trans_id = $hub->param('vt');
    
    if ($trans_id) {
      my $trans_adaptor = $hub->database('core')->get_TranscriptAdaptor;
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
  } elsif ($hub->param('consequence')) {
    $type = $hub->param('consequence') || '';
  } else {
    $type = $feature->display_consequence;
  }
  
  my $chr_start = $feature->start;
  my $chr_end   = $feature->end;
  my $chr       = $feature->seq_region_name;
  my $bp        = "$chr:$chr_start";
  
  if ($chr_end < $chr_start) {
    $bp = "$chr: between $chr_end &amp; $chr_start";
  } elsif ($chr_end > $chr_start) {
    $bp = "$chr:$chr_start-$chr_end";
  }
  
  my $lrg_bp;
  
  if($snp_fake && $feature && $lrg) {
    my $lrg_slice;
    eval { $lrg_slice = $hub->get_adaptor('get_SliceAdaptor')->fetch_by_region('LRG', $lrg); };
    if($lrg_slice) {
      my $lrg_feature = $feature->transfer($lrg_slice);
      
      $chr_start = $lrg_feature->start;
      $chr_end   = $lrg_feature->end;
      $lrg_bp    = $chr_start;
      
      if ($chr_end < $chr_start) {
        $lrg_bp = "between $chr_end &amp; $chr_start";
      } elsif ($chr_end > $chr_start) {
        $lrg_bp = "$chr_start-$chr_end";
      }
    }
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
  
  unshift @entries, [ 'LRG bp', $lrg_bp ] if $lrg_bp;


 
  my $tc;
  if ($hub->param('t_id')){
    foreach ( @{$feature->get_all_TranscriptVariations()} ){
      if ($hub->param('t_id') eq $_->transcript->stable_id){
        my $codon = $_->codons;
        $codon =~s/([A-Z])/<strong>$1<\/strong>/g;
        next unless $codon =~/\w+/;
        $tc = "<strong>Codon change </strong> ".$codon;
      }
    }  
  }
 
  my $type = $feature->variation->is_somatic ? 'Somatic mutation' : 'Variation'; 
  $self->caption($type .': ' . $feature->variation_name);
  
  $self->add_entry({
    label_html => $type .' Properties',
    link       => $hub->url({
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
      position => ($lrg_bp ? 4 : 3)
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
  } elsif ($hub->type eq 'Variation') {
    my $status = join ', ', @{$feature->get_all_validation_states||[]};
    
    $self->add_entry({
      type     => 'status:',
      label    => $status || '-',
      position => 3
    });
  }
  
  if(defined($p_value)) {
    $self->add_entry({
      type   => 'p-value',
      label  => $p_value,
    });
  }
}

1;
  
