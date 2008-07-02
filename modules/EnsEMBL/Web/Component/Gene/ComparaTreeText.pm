package EnsEMBL::Web::Component::Gene::ComparaTreeText;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  my $self           = shift;
  my $object         = $self->object;

  #----------
  # Get the ProteinTree object 
  my $tree   = $object->get_ProteinTree;

  #----------
  # Return the text representation of the tree
  my $htmlt = qq(
<p>The following is a representation of the tree in 
<a href=http://en.wikipedia.org/wiki/Newick_format>newick</a> format</p>
<p>The species included in the tree can be configured using the
'configure tree' link in the left panel.<p> 
<pre>%s</pre>);

  my $newick_mode = "full"; # Todo: user-selectable mode
                            # Todo: support nhx in addition to newick
  return sprintf( $htmlt,$tree->newick_format($newick_mode));

}

1;
