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
