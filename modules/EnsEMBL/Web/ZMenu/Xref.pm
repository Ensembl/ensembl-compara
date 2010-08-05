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
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object;
  my $data = $object->features('Xref')->data_objects;
  my $ftype = $hub->param('ftype');

  foreach my $array (@$data) {
    my $xref = shift @$array;
      $self->caption('Xref: '.$xref->db_display_name);
    
      foreach my $g (@$array) {        
        my $r = 'Chromosome '.$g->seq_region_name.': '.$self->thousandify($g->start).'-'.$self->thousandify($g->end);        
        
        $self->add_entry({
          type  => 'Linked Gene',
          label => $g->stable_id,
          link  => $hub->url({ type => 'Gene', action => 'Summary' })
        });      
      
        $self->add_entry({
          type  => 'Location',
          label => $r,
          link  => $hub->url({type   => 'Location', action => 'View', g => undef, r => ($g->seq_region_name . ':' . $g->seq_region_start . '-' . $g->seq_region_end), h => $xref->db_display_name }),
        });
      }
    
    } 
}

1;