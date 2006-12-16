=head1 NAME

Bio::Search::Result::EnsemblResult - Ensembl-specific implementation of Bio::Search::Result::ResultI

=head1 SYNOPSIS

  # Configure SearchIO to generate EnsemblResult objects
  use Bio::SearchIO;
  use Bio::Search::Result::ResultFactory;
  my $class = 'Bio::Search::Result::EnsemblResult';
  my $sio = Bio::SearchIO->new(-format=>'blast', -file=>'report.bla');
  my $factory =  Bio::Search::Result::ResultFactory->new(-type=>$class);
  $sio->_eventHandler->register_factory('result',$factory);

  # Create Ensembl Adaptors required for mapping/storage 
  use Bio::EnsEMBL::Adaptor;
  use Bio::EnsEMBL::External::BlastAdaptor;
  my $core_adpt  =   Bio::EnsEMBL::External::Adaptor->new
    ( -db_name=>'homo_sapiens_core_16_33', -user=>'ro_user' );
  my $blast_adpt = Bio::EnsEMBL::External::BlastAdaptor->new
    ( -db_name=>'ensembl_blast', -user=>'rw_user' );

  my @tokens;
  while( my $result = $sio->next_result){
    # map all search results within the input stream
    $result->adaptor( $blast_adpt );
    $result->core_adaptor( $core_adpt );
    $result->map_to_genome;
    # store results to disk for use later
    push @tokens, $result->store;
  }

  # Retrieve results from disk
  use Bio::Search::Result::EnsemblResult;
  foreach( @tokens ){
    my $result = Bio::Search::Result::EnsemblResult->retrieve($_, $blast_adpt);
    # insert code here for hit processing
  }

=head1 DESCRIPTION

This object extends Bio::Search::Result::GenericResult in several respects:
* Provides ensembl-specific 'species' and 'datatabase' methods,
* Provides '_map' hook to allow post-processing of HitI and HSPI objects.
* Inherets from Bio::Root::Storable, allowing results to be saved-to
  and retrieved-from disk,
* Overrides the default Bio::Root::Storable behaviour to store object to 
  database using Bio::EnsEMBL::External::BlastAdaptor.
* Provides methods to allow Hits to be retrieved by ID

=cut

#======================================================================
# Let the code begin...

package Bio::Search::Result::EnsemblResult;
use strict;
#use Data::Dumper qw( Dumper );
use vars qw(@ISA);

use Bio::Root::Storable;
use Bio::Search::Result::GenericResult;

@ISA = qw(Bio::Search::Result::GenericResult
	  Bio::Root::Storable);

#----------------------------------------------------------------------

=head2 new

  Arg [1]   : -core_adaptor  => Bio::EnsEMBL::Adaptor
  Function  : Builds a new Bio::Search::Result::EnsemblResult object
  Returntype: Bio::Search::Result::EnsemblResult
  Exceptions: 
  Caller    : 
  Example   : $res = Bio::Search::Result::EnsemblResult->new()

=cut

sub new {
  my($class,@args) = @_;
  my $self = $class->SUPER::new(@args);
  $self->_initialise_storable(@args);

  my( $adaptor, $blast_adaptor, $core_adaptor ) 
    = $self->_rearrange([qw(ADAPTOR BLAST_ADAPTOR CORE_ADAPTOR)]);

  $adaptor       && $self->adaptor( $adaptor );
  $blast_adaptor && $self->blast_adaptor( $blast_adaptor );
  $core_adaptor  && $self->core_adaptor(  $core_adaptor  );

  return $self;
}

#----------------------------------------------------------------------

=head2 blast_adaptor

  Arg [1]   : 
  Function  : DEPRECATED. Use adaptor method instead
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 
  Example   : 
=cut
sub blast_adaptor {
  my $self = shift;
  my $caller = join( ', ', (caller(0))[1..2] );
  $self->warn( "Deprecated: use adaptor method instead: $caller" ); 
  return $self->adaptor(@_);
}

#----------------------------------------------------------------------

=head2 core_adaptor

  Arg [1]   : Bio::EnsEMBL::Adaptor optional
  Function  : Accessor for the core database adaptor
  Returntype: Bio::EnsEMBL::Adaptor
  Exceptions: 
  Caller    : 
  Example   : $result->core_adaptor( $core_adpt )
  Example   : $core_adpt = $result->core_adaptor()

=cut

sub core_adaptor {
  my $self = shift;
  $self->{ '__core_adaptor' } = shift if @_;
  return $self->{ '__core_adaptor' };
}

#----------------------------------------------------------------------

=head2 database_name

  Arg [1]   : $name string optional 
  Function  : Accessor for the name of the sequence database used 
              in the query. The name is parsed to retrieve, and then set,
              Ensembl-specific database and species attributes.
              Database name typically something like:
              homo_sapiens_latestgp, whereas database names are, in reality,
              like:  Homo_sapiens.NCBI33.contig.fa, or localhost:50003.
              Would be nice to deprecate this method of setting 
              species/database
  Returntype: $name string
  Exceptions: 
  Caller    : 
  Example   : $result->database_name( $dbname )
  Example   : $dbname = $result->database_name()

=cut

sub database_name {
  my $self = shift;
#  if( @_ ){
#    my $dbname = $_[0];
#    if( $dbname =~ /([^\/]+)$/ ){ $dbname = $1 }
#    my @bits = split( /[_\.]/, $dbname, 3 ); 
#    if( @bits < 3 ){ 
#      $self->warn("Bad format for Ensembl search DB: ".$dbname );
#      return $dbname;
#    }
#    $self->species( ucfirst( $bits[0] ) . '_' . lc( $bits[1] ) );
#    $self->database( uc( $bits[2] ) ); 
#  }
  return $self->SUPER::database_name(@_);
}

#----------------------------------------------------------------------

=head2 database_species

  Arg [1]   : $species string optional
  Function  : Get/set accessor for database species (e.g. Homo_sapiens). 
              This is an Ensembl specific method.
  Returntype: $species string
  Exceptions: 
  Caller    : 
  Example   : $result->species( $species )
  Example   : $species = $result->species()

=cut

sub species {
  warn( "Deprecated; use database_species instead", 
	join( ', ', (caller(0))[1..2] ) );
  my $self = shift; return $self->database_species(@_);
}

sub database_species {
  my $self = shift;
  $self->{ '_species' } = shift if @_;
  return $self->{ '_species' };
}

#----------------------------------------------------------------------

=head2 database_type

  Arg [1]   : $database string optional
  Function  : Standard get/set accessor for database_type. This is an Ensembl
              specific method.
  Returntype: $database string
  Exceptions: 
  Caller    : 
  Example   : $result->database( $database )
  Example   : $database = $result->database()

=cut

sub database_type {
  my $self = shift;
  $self->{ '_database' } = shift if @_;
  return $self->{ '_database' };
}

#----------------------------------------------------------------------

=head2 map_to_genome

  Arg [1]   : none
  Function  : For each Hit and HSP object contained in the result;
                Sets ensembl-specific Hit and HSP attributes,
                Calls ensembl-specific Hit and HSP _map method.
              If the database is labeled LATESTGP (likely to be deprecated);
                Removes HSPs that do not align with the genome assembly,
                Removes Hits with no genomic HSPs.
              Should be called only after the entire search report has 
              been parsed.
  Returntype: boolean 
  Exceptions: 
  Caller    : 
  Example   : $result->map_to_genome()

=cut

sub map_to_genome{
  my $self = shift;

#warn "GETTING CORE ADAPTOR...";
  my $core_adpt = $self->core_adaptor ||
    ( $self->warn( "Core adaptor not set; can't propogate" ) && return );

  # This is to keep results, hits and HSPs  stored to tables with the
  # same date stamp
  my $use_date;
#warn "GETTING ADAPTOR...";
  if( my $adpt = $self->adaptor ){
#warn "ADAPTOR GOT $adpt ",ref($adpt);
    my $d = $adpt->use_date('Hit');
#warn "DATE $d";
    $use_date = $self->use_date( $d );
#warn "DATE GOT";
  }

#warn "GETTING TYPE...";
  my $database_type = $self->database_type;
#warn "GETTING HITS...";
  foreach my $hit( $self->hits ){
#warn "Hit.... $hit";
    $core_adpt     && $hit->core_adaptor( $core_adpt );
    $use_date      && $hit->use_date($use_date);
    $hit->_map($database_type);

    foreach my $hsp( $hit->hsps ){
#warn "  HSP.... $hsp";
      $core_adpt     && $hsp->core_adaptor( $core_adpt );
      $use_date      && $hsp->use_date($use_date);
      $hsp->_map($database_type);
    }
  }
#warn "MAPPED....";
  return 1;
}

#----------------------------------------------------------------------

=head2 next_hit

  Arg [1]   : none
  Function  : As for SUPER::next_hit, but also handles 'retrievable' hits
  Returntype: Bio::Search::Hit::HitI object
  Exceptions: 
  Caller    : 
  Example   : $hit = $result->next_hit()

=cut

sub next_hit {
  my $self = shift;
  my $hit  = $self->SUPER::next_hit(@_) || return;

  # Handle storable
  if( $hit->isa('Bio::Root::Storable') && $hit->retrievable ){
    $hit->retrieve( '', $self->adaptor );
    $hit->verbose( $self->verbose ) # Propogate verbosity
  }
  return $hit
}

#----------------------------------------------------------------------

=head2 hits

  Arg [1]   : none
  Function  : As for SUPER::hits, but also handles 'retrievable' hits
  Returntype: Array of L<Bio::Search::Hit::HitI> objects
  Exceptions: 
  Caller    : 
  Example   : @hits = $result->hits()

=cut

sub hits{
  my $self = shift;
  my @hits = $self->SUPER::hits(@_);

  # Handle storable
  map{ $_->retrieve('', $self->adaptor) && $_->verbose($self->verbose) }
  grep{ $_->isa('Bio::Root::Storable') and $_->retrievable } @hits;

  return @hits;   
}

#----------------------------------------------------------------------

=head2 hit_tokens

  Arg [1]   : none
  Function  : Returns a list of 'storable' tokens of all hits registered 
              with this result
  Returntype: array of scalars
  Exceptions: Only works when all Hits are of type Bio::Root::Storable
  Caller    : 
  Example   : @hit_tokens = $result->hit_tokens()

=cut

sub hit_tokens {
  my $self = shift;
  ref( $self->{_hits} ) eq 'ARRAY' or return ();
  scalar( @{$self->{'_hits'}} ) or return();

  # Test for Hit storability (assume all of same type)
  if( ! $self->{'_hits'}->[0]->isa('Bio::Root::Storable') ){
    $self->warn( "Only Hits of type Bio::Root::Storable have tokens" );
    return ();
  }
  return( map{ $_->token } @{$self->{'_hits'}} );
}

#----------------------------------------------------------------------

=head2 hit_by_token

  Arg [1]   : $token string
  Function  : Retrieves the Hit object corresponding to the 'storable'
              token
  Returntype: Bio::Search::Hit::HitI object
  Exceptions: Only works when all Hits are of type Bio::Root::Storable
  Caller    : 
  Example   : $hit = $result->hit_by_token( $hit_token )

=cut

sub hit_by_token {
  my $self = shift;
  my $token = shift || ( $self->warn('Need a Hit token') && return );
  ref( $self->{_hits} ) eq 'ARRAY' or return;
  scalar( @{$self->{'_hits'}} ) or return();

  # Test for Hit storability (assume all of same type)
  if( ! $self->{'_hits'}->[0]->isa('Bio::Root::Storable') ){
    $self->warn( "Only Hits of type Bio::Root::Storable have tokens" );
    return;
  }
   
  foreach my $hit( @{$self->{_hits}} ){
    $hit->token ne $token and next;
    # Retrieve if required
    if( $hit->retrievable ){
      $hit->retrieve( '', $self->adaptor );
      $hit->verbose( $self->verbose );
    }
    return $hit;
  }
  # No hit found
  $self->warn('No Hit found for token $token');
  return;
}


#----------------------------------------------------------------------

=head2 token

  Arg [1]   : $token string optional
  Function  : Accessor for 'storable' token. Implementation may change.
  Returntype: $token string
  Exceptions: 
  Caller    : 
  Example   : $result_token = $result->token()

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
  Caller    : 
  Example   : $ticket = $hsp->ticket()

=cut

sub group_ticket{
  my $key = '_group_ticket';
  my $self = shift;
  if( ! $self->{$key} ){
    my $workdir = $self->workdir || $self->warn( "workdir not set" ) && return;
    my @bits = split( $Bio::Root::IO::PATHSEP, $workdir );
    my $ticket = join( '', reverse( pop( @bits ), pop( @bits ) ) );
    $self->{$key} = $ticket;
    
    # Propogate to Hits and HSPs
    foreach my $hit( $self->hits ){
      $hit->group_ticket( $ticket );
      foreach my $hsp( $hit->hsps ){
	$hsp->group_ticket( $ticket );
      }
    }

# if( $self->workdir =~ /\/([^\/]+)$/ ){ $self->{$key} = $1 }  
# else{ $self->warn( "workdir $workdir contains no group ticket" ) && return}
  }
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

  # Remove 'child' Hits
  foreach my $hit( $self->hits ){
    $hit->remove if $hit->can('remove');
  }
  return $self->SUPER::remove(@_);
}

#----------------------------------------------------------------------
1;
