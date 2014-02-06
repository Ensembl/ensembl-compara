=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

#----------------------------------------------------------------------
#
#----------------------------------------------------------------------

package EnsEMBL::Web::BlastView::PanelCache;

use strict;

#----------------------------------------------------------------------

=head2 new

  Arg [1]   : 
  Function  : Minimalistic object creator
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub new{
  my $class = shift;
  my $self = {};
  bless $self, $class;
  return $self;
}

#----------------------------------------------------------------------

=head2 update_cache

  Arg [1]   : arrayref; pointing to the cache location to update/retrieve
              scalar (optional); the value to set at the location. 
  Function  : gets/sets values in the cache
  Returntype: value at the cache location 
  Exceptions: 
  Caller    : 
  Example   : $self->update_cache( \( $stage, $species ), 'My text' )

=cut

sub update_cache{
  my $self   = shift;
  my $locref = shift;
  my $text   = shift;

  my @location = @{$locref};

  my $tmp = $self;
  while( my $loc = shift @location ){
    if( $text){
      if( ! $tmp->{$loc} ){
	$tmp->{$loc} = {};
      }
      if( ! $location[0] ){
	$tmp->{$loc} = $text 
      }
    }
    $tmp = $tmp->{$loc};
  }
  return $tmp;
}

#----------------------------------------------------------------------

=head2 get_cached

  Arg [1]   : arrayref; pointing to the cache location to retrieve
  Function  : Wrapper for 'update_cache'. 
  Returntype: scalar; whatever is found at the cache location
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub get_cached{
  my $value = $_[0]->update_cache( $_[1] );
  return $value;
}

1;
