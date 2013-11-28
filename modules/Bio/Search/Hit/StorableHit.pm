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


package Bio::Search::Hit::StorableHit;
use vars qw(@ISA);
use strict;

use Bio::Root::Storable;
use Bio::Search::Hit::GenericHit;

@ISA = qw(  Bio::Search::Hit::GenericHit Bio::Root::Storable );


=head2 next_hsp

 Title    : next_hsp
 Usage    : while( $hsp = $obj->next_hsp()) { ... }
 Function : Returns the next available High Scoring Pair
 Example  : 
 Returns  : Bio::Search::HSP::HSPI object or null if finished
 Args     : none

=cut

sub next_hsp {
  my ($self) = @_;
  $self->{'_iterator'} = 0 unless defined $self->{'_iterator'};

  my $hsp = $self->{'_hsps'}->[$self->{'_iterator'}++] || return undef;
  
  # Handle storable
  if( $hsp->isa('Bio::Root::Storable') and $hsp->retrievable ){
    $hsp->retrieve;
  }

  return $hsp;
}


=head2 hsps

 Usage     : $hit_object->hsps();
 Purpose   : Get a list containing all HSP objects.
           : Get the numbers of HSPs for the current hit.
 Example   : @hsps = $hit_object->hsps();
           : $num  = $hit_object->hsps();  # alternatively, use num_hsps()
 Returns   : Array context : list of Bio::Search::HSP::BlastHSP.pm objects.
           : Scalar context: integer (number of HSPs).
           :                 (Equivalent to num_hsps()).
 Argument  : n/a. Relies on wantarray
 Throws    : Exception if the HSPs have not been collected.

See Also   : L<hsp()|hsp>, L<num_hsps()|num_hsps>

=cut

sub hsps {

   my $self = shift;
   ref( $self->{_hsps} ) eq 'ARRAY' or return ();
   my @hsps = @{$self->{_hsps}};
   
   # Handle storable
   map{ $_->retrieve }
   grep{ $_->isa('Bio::Root::Storable') and $_->retrievable } @hsps;

   return @hsps;
}


1;
