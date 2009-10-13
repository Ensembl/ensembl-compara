# $Id$

package EnsEMBL::Web::ZMenu::VariationProtein;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  my $object           = $self->object;
  my $v_id             = $object->param('v');
  my $vtype            = $object->param('vtype');
  my $db_adaptor       = $object->database('variation');
  my $var_adaptor      = $db_adaptor->get_VariationAdaptor;
  my $var_feat_adaptor = $db_adaptor->get_VariationFeatureAdaptor;
  my $var              = $var_adaptor->fetch_by_name($v_id);
  my $vf               = $var_feat_adaptor->fetch_all_by_Variation($var);
  my $feature;
  my @entries;

  if (scalar @$vf == 1) {
    $feature = $vf->[0];
  } else {
    foreach (@$vf) {
      $feature = $_ if $_->dbID eq $object->param('vf');
    }
  }
  
  if ($vtype) {
    my $type = lc $vtype;
    $type =~ s/e$//;
    $type .= 'ion'; 
    
    @entries = (
      [ ucfirst $type, $object->param('indel') ],
      [ 'Position',    $object->param('pos')   ],
      [ 'Length',      $object->param('len')   ]
    );
  } else {
    @entries = ([ 'Variation type', $feature->display_consequence ]);  
  }
  
  push @entries, (
    [ 'Residue',              $object->param('res') ],
    [ 'Alternative Residues', $object->param('ar')  ],
    [ 'Codon',                $object->param('cod') ],
    [ 'Alleles',              $object->param('al')  ]
  );
  
  $self->caption('Variation Information');
  
  $self->add_entry({
    type       =>  'Variation ID',
    label_html => $feature->variation_name,
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
}

1;
  