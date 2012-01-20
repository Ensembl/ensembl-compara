=head1 NAME

Bio::Root::Storable - object serialisation methods

=head1 SYNOPSIS

  my $storable = Bio::Root::Storable->new();

  # Store/retrieve using class retriever
  my $token     = $storable->store();
  my $storable2 = Bio::Root::Storable->retrieve( $token );

  # Store/retrieve using object retriever
  my $storable2 = $storable->new_retrievable();
  $storable2->retrieve();


=head1 DESCRIPTION

Generic module that allows objects to be safely stored/retrieved from
disk.  Can be inhereted by any BioPerl object. As it will not usually
be the first class in the inheretence list, _initialise_storable()
should be called during object instantiation.

Object storage is recursive; If the object being stored contains other
storable objects, these will be stored seperately, and replaced by a
skeleton object in the parent heirarchy. When the parent is later
retrieved, its children remain in the skeleton state until explicitly
retrieved by the parent. This lazy-retrieve approach has obvious
memory efficiency benefits for certain applications.

By default, objects are stored in binary format (using the Perl
Storable module). Earlier versions of Perl5 do not include Storable as
a core module. If this is the case, ASCII object storage (using the
Perl Data::Dumper module) is used instead.

ASCII storage can be enabled by default by setting the value of
$Bio::Root::Storable::BINARY to false.

By default, objects are stored to the file system. It is possible to
change this to, for example, save objects to a database. This mode
requires an appropriate adaptor to be set. The adaptor must implement
the following methods: 'store', 'retrieve' and 'remove'. A new
interface, Bio::Root:StorableAdaptorI, will be implemented shortly.

=cut

# Let the code begin...
package Bio::Root::Storable;

use strict;
use Data::Dumper qw( Dumper );

use vars qw(@ISA);

use Bio::Root::Root;
use Bio::Root::IO;

use vars qw( $BINARY );
@ISA = qw( Bio::Root::Root );

BEGIN{
  if( eval "require Storable" ){
    Storable->import( 'freeze', 'nfreeze', 'thaw' );
    $BINARY = 1;
  }
}

#----------------------------------------------------------------------

=head2 new

  Arg [1]   : -workdir  => filesystem path,
              -template => tmpfile template,
              -suffix   => tmpfile suffix,
              -adaptor  => Bio::Root::StorableAdaptorI object
  Function  : Builds a new Bio::Root::Storable inhereting object
  Returntype: Bio::Root::Storable inhereting object
  Exceptions: 
  Caller    : 
  Example   : $storable = Bio::Root::Storable->new()

=cut

sub new {
  my ($caller, @args) = @_;
  my $self = $caller->SUPER::new(@args);
  $self->_initialise_storable;
  return $self;
}

#----------------------------------------------------------------------

=head2 _initialise_storable

  Arg [1]   : See 'new' method
  Function  : Initialises storable-specific attributes
  Returntype: boolean
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub _initialise_storable {
  my $self = shift;
  my( $workdir, $template, $suffix, $adaptor ) = 
    $self->_rearrange([qw(WORKDIR TEMPLATE SUFFIX ADAPTOR)], @_ );
  $workdir  && $self->workdir ( $workdir  );
  $template && $self->template( $template );
  $suffix   && $self->suffix  ( $suffix   );
  $adaptor  && $self->adaptor ( $adaptor  );
  return 1;
}

#----------------------------------------------------------------------

=head2 statefile

  Arg [1]   : string (optional)
  Function  : Accessor for the file to write state into.
              Should not normaly use as a setter - let Root::IO
              do this for you.
  Returntype: string
  Exceptions: 
  Caller    : Bio::Root::Storable->store
  Example   : my $statefile = $obj->statefile();

=cut

sub statefile{

  my $key = '_statefile';
  my $self  = shift;

  if( @_ ){ $self->{$key} = shift }

  if( ! $self->{$key} ){ # Create a new statefile

    my $workdir  = $self->workdir;
    my $template = $self->template;
    my $suffix   = $self->suffix;

    # TODO: add cleanup and unlink methods. For now, we'll keep the 
    # statefile hanging around.
    my @args = ( CLEANUP=>0, UNLINK=>0 );
    if( $template ){ push( @args, 'TEMPLATE' => $template )};
    if( $workdir  ){ push( @args, 'DIR'      => $workdir  )};
    if( $suffix   ){ push( @args, 'SUFFIX'   => $suffix   )};
    my( $fh, $file ) = Bio::Root::IO->new->tempfile( @args );

    $self->{$key} = $file;
  }

  return $self->{$key};
}

#----------------------------------------------------------------------

=head2 workdir

  Arg [1]   : string (optional) (TODO - convert to array for x-platform)
  Function  : Accessor for the statefile directory. Defaults to 
              $Bio::Root::IO::TEMPDIR
  Returntype: string
  Exceptions: 
  Caller    : 
  Example   : $obj->workdir('/tmp/foo');

=cut

sub workdir {
  my $key = '_workdir';
  my $self = shift;
  if( @_ ){ 
    #$self->{$key} && $self->debug("Overwriting workdir: probably bad!\n");
    $self->{$key} = shift 
  }
  $self->{$key} ||= $Bio::Root::IO::TEMPDIR;
  return $self->{$key};
}

#----------------------------------------------------------------------

=head2 template

  Arg [1]   : string (optional)
  Function  : Accessor for the statefile template. Defaults to XXXXXXXX
  Returntype: string
  Exceptions: 
  Caller    : 
  Example   : $obj->workdir('RES_XXXXXXXX');

=cut

sub template {
  my $key = '_template';
  my $self = shift;
  if( @_ ){ $self->{$key} = shift }
  $self->{$key} ||= 'XXXXXXXX';
  return $self->{$key};
}

#----------------------------------------------------------------------

=head2 suffix

  Arg [1]   : string (optional)
  Function  : Accessor for the statefile template.
  Returntype: string
  Exceptions: 
  Caller    : 
  Example   : $obj->suffix('.state');

=cut

sub suffix {
  my $key = '_suffix';
  my $self = shift;
  if( @_ ){ $self->{$key} = shift }
  return $self->{$key};
}

#----------------------------------------------------------------------

=head2 new_retrievable

  Arg [1]   : Same as for 'new'
  Function  : Similar to store, except returns a 'skeleton' of the calling 
              object, rather than the statefile.  
              The skeleton can be repopulated by calling 'retrieve'. This 
              will be a clone of the original object.
  Returntype: Bio::Root::Storable inhereting object
  Exceptions: 
  Caller    : 
  Example   : my $skel = $obj->new_retrievable(); # skeleton 
              $skel->retrieve();                  # clone

=cut

sub new_retrievable{
   my $self = shift;
   my @args = @_;

   $self->_initialise_storable( @args );

#   if( $self->retrievable ){ warn( "FOO" ) && return $self->clone } # Clone retrievable
   return bless( { _statefile    => ( $self->retrievable ?
				      $self->statefile :
				      $self->store(@args) ),
		   _workdir      => $self->workdir,
		   _suffix       => $self->suffix,
		   _template     => $self->template,
		   #__adaptor     => $self->adaptor,
		   _retrievable  => 1 }, ref( $self ) ); 
}

#----------------------------------------------------------------------

=head2 retrievable

  Arg [1]   : none
  Function  : Reports whether the object is in 'skeleton' state, and the
              'retrieve' method can be called.
  Returntype: boolean
  Exceptions: 
  Caller    : 
  Example   : if( $obj->retrievable ){ $obj->retrieve }

=cut

sub retrievable {
   my $self = shift;
   if( @_ ){ $self->{_retrievable} = shift }
   return $self->{_retrievable};
}

#----------------------------------------------------------------------

=head2 token

  Arg [1]   : None
  Function  : Accessor for token attribute
  Returntype: string. Whatever retrieve needs to retrieve.
              This base implementation returns the statefile
  Exceptions: 
  Caller    : 
  Example   : my $token = $obj->token();

=cut

sub token{ 
  my $self = shift;
  # TODO: Make adaptor-generic. 
  # Assumes default filesystem adaptor at the moment
  return $self->statefile;
}


#----------------------------------------------------------------------

=head2 store

  Arg [1]   : none
  Function  : Saves a serialised representation of the object structure
              to disk. Returns the name of the file that the object was 
              saved to. 
  Returntype: string

  Exceptions: 
  Caller    : 
  Example   : my $token = $obj->store();

=cut

sub store{
  my $self = shift;

  # Prepare the serialised string
  my $serialised_obj = $self->serialise;

  # Check for explicit adaptor, and ensure it works.
  if( $self->adaptor ){
    my $ret;
    eval{ $ret = $self->adaptor->store($self, $serialised_obj, @_) };
    $@ && $self->debug( @$ );
    if( $ret ){
      $self->debug( "STORE $self to ".ref($self->adaptor)."\n" );
      $self->modified(0); # Unset modified flag
      return $ret;
    }
  }

  # Use default adaptor
  my $statefile = $self->statefile;
  my $io = Bio::Root::IO->new( ">$statefile" );
  $io->_print( $serialised_obj );
  $self->debug( "STORE $self to $statefile\n" );
  $self->modified(0); # Unset modified flag
  return $statefile;
}

#----------------------------------------------------------------------

=head2 serialise

  Arg [1]   : none
  Function  : Prepares the the serialised representation of the object. 
              Object attribute names starting with '__' are skipped.
              This is useful for those that do not serialise too well 
              (e.g. filehandles). 
              Attributes are examined for other storable objects. If these
              are found they are serialised seperately using 'new_retrievable'
  Returntype: string
  Exceptions: 
  Caller    : 
  Example   : my $serialised = $obj->serialise();

=cut

sub serialise{
  my $self = shift;

  # Create a new object of same class that is going to be serialised
  my $store_obj = bless( {}, ref( $self ) ); 

  my %retargs = ( -workdir =>$self->workdir,
		  -suffix  =>$self->suffix,
		  -template=>$self->template,
		  -adaptor =>$self->adaptor );

  # Assume that other storable bio objects held by this object are
  # only 1-deep.
  foreach my $key( keys( %$self ) ){
    if( $key =~ /^__/ ){ next } # Ignore keys starting with '__'
    my $value = $self->{$key};

    # Scalar value
    if( ! ref( $value ) ){
      $store_obj->{$key} = $value;
    }
    
    # Bio::Root::Storable obj: save placeholder
    elsif( ref($value) =~ /^Bio::/ and $value->isa('Bio::Root::Storable') ){
      # Bio::Root::Storable
      $store_obj->{$key} = $value->new_retrievable( %retargs );
      next;
    }
    
    # Arrayref value. Look for Bio::Root::Storable objs
    elsif( ref( $value ) eq 'ARRAY' ){
      my @ary;
      foreach my $val( @$value ){
	if( ref($val) =~ /^Bio::/ and $val->isa('Bio::Root::Storable') ){
	  push(  @ary, $val->new_retrievable( %retargs ) );
	}
	else{ push(  @ary, $val ) }
      }
      $store_obj->{$key} = \@ary;
    }
    
    # Hashref value. Look for Bio::Root::Storable objs
    elsif( ref( $value ) eq 'HASH' ){
      my %hash;
      foreach my $k2( keys %$value ){
	my $val = $value->{$k2};
	if( ref($val) =~ /^Bio::/ and $val->isa('Bio::Root::Storable') ){
	  $hash{$k2} = $val->new_retrievable( %retargs );
	}
	else{ $hash{$k2} = $val }
      }
      $store_obj->{$key} = \%hash;
    }
    
    # Unknown, just add to the store object regardless
    else{ $store_obj->{$key} = $value }
  }
  $store_obj->retrievable(0); # Once serialised, obj not retrievable?
  return $self->_freeze( $store_obj );
}


#----------------------------------------------------------------------

=head2 retrieve

  Arg [1]   : string; filesystem location of the state file to be retrieved
              OR adaptor object capable of retrieving self state
  Function  : Retrieves a stored object from disk. 
              Note that the retrieved object will be blessed into its original
              class, and not the calling class
  Returntype: Bio::Root::Storable inhereting object
  Exceptions: 
  Caller    : 
  Example   : my $obj = Bio::Root::Storable->retrieve( $token );

=cut

sub retrieve{
  my( $caller, $token, $adaptor ) = @_;

  my $self = {};
  my $class = ref( $caller ) || $caller;
  
  # Is this a call on a retrievable object?
  if( ref( $caller ) and $caller->retrievable ){
    $self      = $caller;
    $token   ||= $self->statefile;
    $adaptor ||= $self->adaptor;
  }
  bless( $self, $class );
  # Recover serialised object
  my $serialised_obj = '';
  my $err = '';
  if( $adaptor ){               # Use explicit adaptor
    eval{ $serialised_obj = $adaptor->retrieve( $self, $token ) };
    $err = $@ if $@;
  }
  unless( $serialised_obj ){    # Try default filesystem adaptor
    if( ! -f $token ){
      my @bits = ( ref($self), "Token $token is not found" );
      $err && push( @bits, $err );
      $self->throw(join ': ',  @bits); 
    }
    my $io = Bio::Root::IO->new( $token );
    local $/ = undef();
    $serialised_obj = $io->_readline;
  }
  # Thaw, with dynamic-load of modules required by stored object
  my $stored_obj;
  my $success; 
  for( my $i=0; $i<10; $i++ ){
    eval{ $stored_obj = $self->_thaw( $serialised_obj ) };
    unless( $@ ){ $success=1; last }
    my $package;
    if( $@ =~ /Cannot restore overloading/i ) {
      warn( $@ );
      my $postmatch = $';
      $package = $1 if $postmatch =~ /\(package +([\w\:]+)\)/;
    }
    if( $package ){
      eval "require $package"; 
      $self->throw($@) if $@; 
    }
    else{ $self->throw($@) }
  }
  $self->throw("maximum number of requires exceeded" ) unless $success;
  $self->throw( "Token $token returned no data" )      unless ref( $stored_obj );
  map { $self->{$_} = $stored_obj->{$_} } keys %$stored_obj; # Copy hasheys
  $self->adaptor( $adaptor ) if $adaptor;
  $self->retrievable(0);
  # Maintain class of stored obj
  if( my $sto_class = ref( $stored_obj ) ){
    eval "require $sto_class"; 
    $self->throw($@) if $@; 
    bless $self, $sto_class 
  }
  $self->token( $token ) unless $self->token;  # Ensure token is set
  $self->debug( "RETRIEVE $self from ". ( $adaptor ? ref($adaptor) : $self->statefile )."\n" );
  return $self;
}
   
#----------------------------------------------------------------------


=head2 clone

  Arg [1]   : none
  Function  : Returns a clone of the calling object
  Returntype: Bio::Root::Storable inhereting object
  Exceptions: 
  Caller    : 
  Example   : my $clone = $obj->clone();

=cut

sub clone {
  my $self = shift;
  my $data = {};
  map{$data->{$_} = $self->{$_}} grep{ $_ !~ /^__/ } keys %$self;
  my $frozen = $self->_freeze( $data );
  return $self->_thaw( $frozen );
}

#----------------------------------------------------------------------

=head2 remove

  Arg [1]   : none
  Function  : Clears the stored object from disk
  Returntype: boolean
  Exceptions: 
  Caller    : 
  Example   : $obj->remove();

=cut

sub remove {
  my $self = shift;
  #$self->verbose(1); # Force debug

  # Check for explicit adaptor, and ensure it works.
  if( $self->adaptor ){
    my $ret;
    eval{ $ret = $self->adaptor->remove($self, @_) };
    $@ && $self->warn( $@ );
    if( $ret ){
      $self->debug( "REMOVE $self from ".ref($self->adaptor)."\n" );
      return $ret;
    }
  }

  # Use default adaptor
  if( -e $self->statefile ){
    unlink( $self->statefile );
  }
  $self->debug( "REMOVE $self from ",$self->statefile,"\n" );

  return 1;
}

#----------------------------------------------------------------------

=head2 _freeze

  Arg [1]   : variable
  Function  : Converts whatever is in the the arg into a string.
              Uses either Storable::freeze or Data::Dumper::Dump
              depending on the value of $Bio::Root::BINARY
  Returntype: Serialised representation of arg[1]
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub _freeze {
  my $self = shift;
  my $data = shift;
  my $frozen;
  if( $BINARY ){
    eval{ $frozen = nfreeze( $data ) };
  }
  else{
    $Data::Dumper::Purity = 1;
    eval{ $frozen = Data::Dumper->Dump( [\$data],["*code"] ) };
  }
  $self->throw( " Cannot freeze $self: $@" ) if $@;
  return $frozen;
}

#----------------------------------------------------------------------

=head2 _thaw

  Arg [1]   : string
  Function  : Converts the string into a perl 'whatever'.
              Uses either Storable::thaw or eval depending on the
              value of $Bio::Root::BINARY.
              Note; the string arg should have been created with 
              the _freeze method, or strange things may occur!
  Returntype: variable
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub _thaw {
  my $self = shift;
  my $data = shift;
  if( $BINARY ){ return thaw( $data ) }
  else{ 
    my $code; 
    eval( $data ) ;
    if($@) {
      die( "eval: $@" );
    }   
    ref( $code ) eq 'REF' || 
      $self->throw( "Serialised string was not a scalar ref" );
    return $$code;
  }
}

#----------------------------------------------------------------------

=head2 adaptor

  Arg [1]   : Bio::Root::StorableAdaptorI compliant object (optional)
  Function  : Gets/sets an adaptor to override the default 
              store/retrieve/remove methods. 
              E.g. for storing objects in a database.
  Returntype: Bio::Root::StorableAdaptorI compliant object
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub adaptor {
  my $self = shift;
  my $key = "__adaptor"; # Don't serialise!
  if( @_ ){ 
    my $obj = shift;
    # TODO: Implement Bio::Root::StorableAdaptorI
    #$obj->isa( Bio::Root::StorableAdaptorI ) || 
    #  $self->throw( "$self is not a Bio::Root::StorableAdaptorI" );
    $self->{$key} = $obj; 
  }
  return $self->{$key};
}

#----------------------------------------------------------------------

=head2 modified

  Arg [1]   : boolean
  Function  : Gets/sets modified flag for object. 
              Can be used to determine whether object needs storing or not.
              Objects inhereting from storable generally need to set this 
              flag when attributes are changed.
  Returntype: boolean
  Exceptions: 
  Caller    : 
  Example   : if( $obj->modified ){ $obj->warn( '$obj modified' ) }

=cut

sub modified {
  my $self = shift;
  my $key = "__modified";
  if( @_ ){
    $self->{$key} = shift;
  }
  return $self->{$key} ? 1 : 0;
}

#----------------------------------------------------------------------
1;
