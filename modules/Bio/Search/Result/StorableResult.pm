
# Let the code begin...


package Bio::Search::Result::StorableResult;
use vars qw(@ISA);
use strict;

use Bio::Root::Storable;
use Bio::Search::Result::GenericResult;

@ISA = qw(Bio::Search::Result::GenericResult Bio::Root::Storable);


=head2 next_hit

 Title   : next_hit
 Usage   : while( $hit = $result->next_hit()) { ... }
 Function: Returns the next available Hit object, representing potential
           matches between the query and various entities from the database.
 Returns : a Bio::Search::Hit::HitI object or undef if there are no more.
 Args    : none


=cut

sub next_hit {
  my ($self,@args) = @_;
  my $index = $self->_nexthitindex;
  
  my $hit = $self->{'_hits'}->[$index] || return undef;
  
  # Handle storable
  if( $hit->isa('Bio::Root::Storable') and $hit->retrievable ){
    $hit->retrieve;
  }

  return $hit
}


=head2 hits

 Title   : hits
 Usage   : my @hits = $result->hits
 Function: Returns the available hits for this Result
 Returns : Array of L<Bio::Search::Hit::HitI> objects
 Args    : none


=cut

sub hits{
  my $self = shift;
  ref( $self->{_hits} ) eq 'ARRAY' or return ();
  my @hits = @{$self->{'_hits'}};

  # Handle storable
  map{ $_->retrieve }
  grep{ $_->isa('Bio::Root::Storable') and $_->retrievable } @hits;

  return @hits;   
}

1;
