=head1 NAME

Bio::Search::Hit::EnsembHit - Ensembl-specific implementation of Bio::Search::Hit::HitI

=head1 SYNOPSIS

  use Bio::Search::Hit::EnsemblHit;
  my $hit = Bio::Search::Hit::EnsemblHit();

  # more likely
  use Bio::SearchIO;
  use Bio::Search::Hit::HitFactory;
  my $sio = Bio::SearchIO->new(-format=>'blast', -file=>'report.bla');

  my $class = 'Bio::Search::Hit::EnsemblHit';
  my $factory =  Bio::Search::Hit::HitFactory->new(-type=>$class);
  $sio->_eventHandler->register_factory('hit',$factory);
  
  my $result = $sio->next_result;
  my $hit    = $result->next_hit;

=head1 DESCRIPTION

This object extends Bio::Search::Hit::GenericHit in several respects:
* Provides ensembl-specific 'species' and 'datatabase' methods,
* Provides '_map' hook to allow mapping of Hit from native database to 
  genomic coordinates (uses Bio::EnsEMBL::Adaptor),
* Inherets from Bio::Root::Storable, allowing results to be saved-to
  and retrieved-from disk,
* Overrides the default Bio::Root::Storable behaviour to store object to 
  database using Bio::EnsEMBL::External::BlastAdaptor.
* Provides methods to allow Hits to be retrieved by ID

=cut

#======================================================================
# Let the code begin...

package Bio::Search::Hit::EnsemblHit;

use strict;
#use Data::Dumper qw( Dumper );
use vars qw(@ISA);

use Bio::Root::Storable;
use Bio::Search::Hit::GenericHit;

@ISA = qw(  Bio::Search::Hit::GenericHit 
	    Bio::Root::Storable );

#----------------------------------------------------------------------

=head2 new

  Arg [1]   : -core_adaptor  => Bio::EnsEMBL::Adaptor
  Function  : Builds a new Bio::Search::Hit::EnsemblHit object
  Returntype: Bio::Search::Hit::EnsemblHit
  Exceptions: 
  Caller    : 
  Example   : $hit = Bio::Search::Hit::EnsemblHit->new()

=cut

sub new {
  my($class,@args) = @_;
  my $self = $class->SUPER::new(@args);
  $self->_initialise_storable(@args);

  my(  $blast_adaptor, $core_adaptor ) 
    = $self->_rearrange([qw(BLAST_ADAPTOR CORE_ADAPTOR)]);

  $blast_adaptor && $self->blast_adaptor( $blast_adaptor );
  $core_adaptor  && $self->core_adaptor(  $core_adaptor  );

  return $self;
}

#----------------------------------------------------------------------

=head2 core_adaptor

  Arg [1]   : Bio::EnsEMBL::Adaptor optional
  Function  : Accessor for the core database adaptor
  Returntype: Bio::EnsEMBL::Adaptor
  Exceptions: 
  Caller    : 
  Example   : $hit->blast_adaptor( $core_adpt )
  Example   : $core_adpt = $hit->blast_adaptor()

=cut

sub core_adaptor {
  my $key = '__core_adaptor'; # Don't serialise
  my $self = shift;
  if( @_ ){ $self->{$key} = shift }
  return $self->{$key};
}

#----------------------------------------------------------------------

=head2 _map (rename to genomic_map?)

  Arg [1]   : None
  Function  : Uses Bio::EnsEMBL::Adaptor to map database-native hit 
              locations to genomic locations
  Returntype: boolean
  Exceptions: 
  Caller    : 
  Example   : $hit->_map

=cut

sub _map {
  my $self = shift;

  # Make hit FASTA description available at the HSP level
  my $desc = $self->description;
  foreach my $hsp( $self->hsps ){
    $hsp->hit->annotation->remove_Annotations('description');
    $hsp->hit->seqdesc($desc);
  }
  return 1;
}

#----------------------------------------------------------------------

=head2 next_hsp

  Arg [1]   : none
  Function  : As for SUPER::next_hsp, but also handles 'retrievable' HSPs
  Returntype: Bio::Search::HSP::HSPI
  Exceptions: 
  Caller    : 
  Example   : $hsp = $hit->next_hsp()

=cut

sub next_hsp {
  my $self = shift;
  my $hsp  = $self->SUPER::next_hsp(@_) || return;

  # Handle storable
  if( $hsp->isa('Bio::Root::Storable') && $hsp->retrievable ){
    $hsp->retrieve( '', $self->adaptor );
    $hsp->verbose( $self->verbose ) # Propogate verbosity
  }
  return $hsp
}



#----------------------------------------------------------------------

=head2 hsps

  Arg [1]   : none
  Function  : As for SUPER::hsps, but also handles 'retrievable' hsps
  Returntype: Array of L<Bio::Search::HSP::HSPI> objects
  Exceptions: 
  Caller    : 
  Example   : @hsps = $result->hsps()

=cut

sub hsps {
  my $self = shift;
  my @hsps = $self->SUPER::hsps(@_);
  
  # Handle storable
  map{ $_->retrieve('', $self->adaptor) && $_->verbose($self->verbose) }
  grep{ $_->isa('Bio::Root::Storable') and $_->retrievable } @hsps;
  
  return @hsps;   
}

#----------------------------------------------------------------------

=head2 start

  Arg [1]   : scalar, one of 'query','hit','genomic'
  Function  : As for SUPER::start, but adds 'genomic' option for the
              start in genomic coords
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : $start_genomic = $hit->start('genomic')

=cut

sub start {
  my $key = '_genomic_start';
  my $self = shift;
  my $type = $_[0];
  if( $type ne 'genomic' ){ return $self->SUPER::start(@_) }
  if( ! exists $self->{$key} ){ 
    $self->_initialise_genomic_location;
  }
  return $self->{$key};
}

#----------------------------------------------------------------------

=head2 end

  Arg [1]   : scalar, one of 'query','hit','genomic'
  Function  : As for SUPER::end, but adds 'genomic' option for the
              end in genomic coords
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub end {
  my $key = '_genomic_end';
  my $self = shift;
  my $type = $_[0];
  if( $type ne 'genomic' ){ return $self->SUPER::start(@_) }
  if( ! exists $self->{$key} ){ 
    $self->_initialise_genomic_location;
  }
  return $self->{$key};
}


#----------------------------------------------------------------------

=head2 _initialise_genomic_location

  Arg [1]   : none
  Function  : Internal method;
              Maps hsp genomic_hit min start and max ends to this hit
  Returntype: boolean
  Exceptions: 
  Caller    : $self->start, $self->end
  Example   : $self->_initialise_genomic_location()

=cut

sub _initialise_genomic_location {
  my $self = shift;
  my @hsp_starts;
  my @hsp_ends;

  foreach my $hsp( $self->hsps ){
    $hsp->can('genomic_hit') ||next;
    my $genomic_hit = $hsp->genomic_hit ||next;
    push( @hsp_starts, $genomic_hit->start );
    push( @hsp_ends,   $genomic_hit->end   );
  }
  
  my( $min_start ) = sort{ $a<=>$b } @hsp_starts;
  my( $max_end   ) = sort{ $b<=>$a } @hsp_ends;

  $self->{_genomic_start} = $min_start;
  $self->{_genomic_end}   = $max_end;
  return 1;
}


#----------------------------------------------------------------------

=head2 hsp_tokens

  Arg [1]   : none
  Function  : Returns a list of 'storable' tokens of all hsps registered 
              with this hit
  Returntype: array of scalars
  Exceptions: Only works when all HSPs are of type Bio::Root::Storable
  Caller    : 
  Example   : @hsp_tokens = $hit->hsp_tokens()

=cut

sub hsp_tokens {
  my $self = shift;
  ref( $self->{_hsps} ) eq 'ARRAY' or return ();
  @{$self->{'_hsps'}} or return();

  # Test for HSP storability (assume all of same type)
  if( ! $self->{'_hsps'}->[0]->isa('Bio::Root::Storable') ){
    $self->warn( "Only HSPs of type Bio::Root::Storable have tokens" );
    return ();
  }
  return( map{ $_->token } @{$self->{'_hsps'}} );
}

#----------------------------------------------------------------------

=head2 hsp_by_token

  Arg [1]   : $hsp_token scalar string
  Function  : Retrieves the HSP object corresponding to the 'storable'
              token
  Returntype: Bio::Search::HSP::HSPI object
  Exceptions: Only works when all HSPs are of type Bio::Root::Storable
  Caller    : 
  Example   : $hsp = $hit->hsp_by_token( $hsp_token )

=cut

sub hsp_by_token {
  my $self = shift;
  my $token = shift || return;
  ref( $self->{_hsps} ) eq 'ARRAY' or return;
  scalar( @{$self->{'_hsps'}} ) or return();

  # Test for HSP storability (assume all of same type)
  if( ! $self->{'_hsps'}->[0]->isa('Bio::Root::Storable') ){
    $self->warn( "Only HSPs of type Bio::Root::Storable have tokens" );
    return;
  }
   
  foreach my $hsp( @{$self->{_hsps}} ){
    $hsp->token ne $token and next;
    # Retrieve if required
    if( $hsp->retrievable ){
      $hsp->retrieve( '', $self->adaptor );
      $hsp->verbose( $self->verbose );
    }
    return $hsp;
  }
  # No hit found
  $self->warn('No HSP found for token $token');
  return;
}

#----------------------------------------------------------------------

=head2 token

  Arg [1]   : $token string optional
  Function  : Accessor for 'storable' token. Implementation may change.
  Returntype: $token string
  Exceptions: 
  Caller    : 
  Example   : $hit_token = $hit->token()

=cut

sub token{
  my $self = shift;
  my $token = shift;
  if( $token ){ $self->{_statefile} = $token }
  return $self->{_statefile};
}

#----------------------------------------------------------------------

=head2 group_ticket

  Arg [1]   : none
  Function  : Accessor for EnsemblBlastMulti ticket. Implementation may change.
  Returntype: scalar string
  Exceptions: 
  Caller    : Set by EnsemblResult _map method. Got by whoever.
  Example   : $ticket = $hit->group_ticket()

=cut

sub group_ticket{
  my $key = '_group_ticket';
  my $self = shift;
  if( @_ ){ $self->{$key} = shift }
  return $self->{$key};
}

#----------------------------------------------------------------------

=head2 use_date

  Arg [1]   : scalar string
  Function  : Sets the adaptor 'use_date', used to set the DB table to which 
              hsps and hits are written to 
  Returntype: scalar string
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub use_date {
  my $key = '_use_date';
  my $self = shift;
  if( @_ ){ $self->{$key} = shift }
  return $self->{$key};
}

#----------------------------------------------------------------------

=head2 remove

  Arg [1]   : None
  Function  : Remove the object + any child objects
  Returntype: Boolean
  Exceptions:
  Caller    :
  Example   :

=cut

sub remove {
  my $self = shift;

  # Remove 'child' Hsps
  foreach my $hsp( $self->hsps ){ $hsp->can('remove') && $hsp->remove }

  return $self->SUPER::remove(@_);
}

#======================================================================
1;
