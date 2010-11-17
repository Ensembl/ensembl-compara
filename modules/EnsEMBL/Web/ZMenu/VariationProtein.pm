# $Id$

package EnsEMBL::Web::ZMenu::VariationProtein;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self             = shift;
  my $hub              = $self->hub;
  my $v_id             = $hub->param('v');
  my $vtype            = $hub->param('vtype');
  my $db_adaptor       = $hub->database('variation');
  my $var_adaptor      = $db_adaptor->get_VariationAdaptor;
  my $var_feat_adaptor = $db_adaptor->get_VariationFeatureAdaptor;
  my $var              = $var_adaptor->fetch_by_name($v_id);
  my $vf               = $var_feat_adaptor->fetch_all_by_Variation($var);
  my $feature;

  if (scalar @$vf == 1) {
    $feature = $vf->[0];
  } else {
    foreach (@$vf) {
      $feature = $_ if $_->dbID eq $hub->param('vf');
    }
  }
  
  my @entries = ([ 'Variation type', $feature->display_consequence ]);
  
  if ($vtype) {
    my $type = lc $vtype;
    $type =~ s/e$//;
    $type .= 'ion';
    
    push @entries, (
      [ ucfirst $type, $hub->param('indel') ],
      [ 'Position',    $hub->param('pos')   ],
      [ 'Length',      $hub->param('len')   ]
    );
  }
  
  push @entries, (
    [ 'Residue',              $hub->param('res') ],
    [ 'Alternative Residues', $hub->param('ar')  ],
    [ 'Codon',                $hub->param('cod') ],
    [ 'Alleles',              $hub->param('al')  ]
  );
  
  $self->caption('Variation Information');
  
  $self->add_entry({
    type       =>  'Variation ID',
    label_html => $feature->variation_name,
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
}

1;
  