=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ZMenu::Xref;
### NAME: EnsEMBL::Web::ZMenu::Xref
### Base class - wrapper around a EnsEMBL::Web::ZMenu API object 

### STATUS: Done but Can add more entry
### Creation of new file for Zmenu display 

### DESCRIPTION:
### This module will display the Zmenu on the vertical code for Xref pointers

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self    = shift;
  my $hub     = $self->hub;
  my $data    = $self->object->features('Xref')->data_objects;
  my $ftype = $hub->param('ftype');
  my $id    = $hub->param('id');
  my $xref = $self->object->get_feature_by_id('Xref', 'primary_id', $id);

  if ($xref) {
    my $caption = 'Xref: '.$xref->db_display_name;
    my $name    = $hub->param('name');
    $caption   .= " ($name)" if $name; 
    $self->caption($caption);
    
    my $r = $hub->param('r');
    my $g = $hub->param('g');

    $self->add_entry({
      type  => 'Linked Gene',
      label => $g,
      link  => $hub->url({ type => 'Gene', action => 'Matches', g => $g })
    });      

    $self->add_entry({
      type  => 'Location',
      label => 'Chromosome '.$r,
      link  => $hub->url({type   => 'Location', action => 'View', g => undef, r => $r, h => $xref->db_display_name }),
    });

    $self->add_entry({
      type  => 'Description',
      label => $hub->param('desc'),
    });      

  } 
}

1;
