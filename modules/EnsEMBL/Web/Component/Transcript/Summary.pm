# $Id$

package EnsEMBL::Web::Component::Transcript::Summary;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self = shift;
  my $object = $self->object;

  return sprintf '<p>%s</p>', $object->Obj->description if $object->Obj->isa('EnsEMBL::Web::Fake');
  return '<p>This transcript is not in the current gene set</p>' unless $object->Obj->isa('Bio::EnsEMBL::Transcript');
  
  my $html = $self->transcript_table;
  
  if ($object->gene) {
    $html .= $self->_hint('transcript', 'Transcript and Gene level displays', sprintf('
      <p>
        In %s a gene is made up of one or more transcripts. 
        Views in Ensembl are separated into Gene based views and Transcript based views according to which level the information is more appropriately associated with. 
        This view is a transcript level view. To flip between the two sets of views you can click on the Gene and Transcript tabs in the menu bar at the top of the page.
      </p>', $object->species_defs->ENSEMBL_SITETYPE
    ));
  }
  
  return $html;
}

1;
