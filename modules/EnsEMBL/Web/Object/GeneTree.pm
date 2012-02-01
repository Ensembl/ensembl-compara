package EnsEMBL::Web::Object::GeneTree;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Object);

sub caption        { return $_[0]->short_caption('global'); }
sub short_caption  { return $_[1] eq 'global' ? 'GeneTree: ' . $_[0]->tree->tree->stable_id : 'Genetree-based displays'; }
sub default_action { return 'Image'; }

sub tree { 
  my $self = shift;
  return $self->Obj;
}

1;
