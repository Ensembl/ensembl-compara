=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
