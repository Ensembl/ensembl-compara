package EnsEMBL::Web::Component::GeneTree::ComparaTree;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::Gene::ComparaTree);

sub _get_details {
### Override parent method, so we can get the desired objects
### from the tree, not the gene
  my $self = shift;
  return (undef, $self->object->tree);
}

1;
