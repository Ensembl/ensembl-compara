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

  my $type = $feature->display_consequence;
  my @entries = ([ 'Consequence', $self->variant_consequence_label($type) ]);
  
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
  
  $self->caption('Variant Information');
  
  $self->add_entry({
    type       =>  'Variant ID',
    label_html => $feature->variation_name,
    link       => $hub->url({
      type   => 'Variation', 
      action => 'Explore',
      v      => $feature->variation_name,
      vf     => $feature->dbID,
      source => $feature->source_name
    })
  });
  
  foreach (grep $_->[1], @entries) {
    $self->add_entry({
      type       => $_->[0],
      label_html => $_->[1]
    });
  }
}

1;
  
