# $Id$

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
