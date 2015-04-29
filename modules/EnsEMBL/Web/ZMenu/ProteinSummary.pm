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

package EnsEMBL::Web::ZMenu::ProteinSummary;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $db          = $hub->param('db') || 'core';
  my $pfa         = $hub->database(lc $db)->get_ProteinFeatureAdaptor;
  my $pf          = $pfa->fetch_by_dbID($hub->param('pf_id'));
  my $hit_db      = $pf->analysis->db;
  my $hit_name    = $pf->display_id;
  my $interpro_ac = $pf->interpro_ac;
  
  $self->caption("$hit_name ($hit_db)");
  
  $self->add_entry({
    type  => 'View record',
    label => $hit_name,
    link  => $hub->get_ExtURL($hit_db, $hit_name)
  });
  
  if ($interpro_ac) {
    $self->add_entry({
      type  => 'View InterPro',
      label => $interpro_ac,
      link  => $hub->get_ExtURL('interpro', $interpro_ac)
    });
  }
  
  $self->add_entry({
    type  => 'Description',
    label => $pf->idesc
  });
  
  $self->add_entry({
    type  => 'Position',
    label => $pf->start . '-' . $pf->end . ' aa'
  });
}

1;
