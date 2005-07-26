#----------------------------------------------------------------------
#
# TODO docs
#
#----------------------------------------------------------------------

package EnsEMBL::Web::BlastView::Meta;

use strict;
use warnings;
no warnings "uninitialized";

use SiteDefs;
use Carp;

#use EnsEMBL::Web::BlastView::MetaForm;
#use EnsEMBL::Web::BlastView::MetaFormEntry;
#use EnsEMBL::Web::BlastView::MetaStage;
#use EnsEMBL::Web::BlastView::MetaBlock;
#use EnsEMBL::Web::BlastView::MetaInstance;

use vars qw( $GLOBAL );
$GLOBAL = EnsEMBL::Web::BlastView::Meta->new;

# Define the Meta framework
sub _object_template{ 
  return 
    ( 
     -all_stages => {}, # Unused?
     -stages     => [], 
     -all_blocks => {}, # Unused?
     -all_forms  => {}, # Unused?
     -stage_list => [], # Unused
     -default_stage => '',
    );
}

#----------------------------------------------------------------------
=head2 new

  Arg [1]   : 
  Function  : TODO: Change to be a copy constructor 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub new {
  my $caller = shift;
  my $class  = ref( $caller ) || $caller;
  my %temp   = $class->_object_template;
  my $self   = \%temp;
  bless $self, $class;
  return $self;
}

#----------------------------------------------------------------------
=head2 AUTOLOAD

  Arg [1]   : 
  Function  : 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub AUTOLOAD {
  use vars qw( $AUTOLOAD );
  my $self = shift;
  my $value = shift;

  if( ref($self) !~ /^EnsEMBL::Web::BlastView::Meta/ ){ 
    die( "'$self' is Not an EnsEMBL::Web::BlastView::Meta object!" )
  }

#  warn( $AUTOLOAD );
  my $method = $AUTOLOAD;
  $method =~ s/.*:://;
  
  # Parse the method name
  my( $action, $key ) = split( '_', $method, 2 ); 
  $key = join( '', '-', $key );

  # Creates an object of type Meta$key and loads it into the $key list
  # E.g.1: $obj->addobj_form 
  #        adds an EnsEMBL::Web::BlastView::MetaForm object 
  #        to the -form array
  # E.g.2: $obj->addobj_form_entry 
  #        adds an EnsEMBL::Web::BlastView::MetaFormEntry object 
  #        to the -form_entries array
  if( $action eq 'addobj' ){
    $key=~/-(.+?)$/;
    my $class = $1;
    $class = join( '', map( ucfirst, split( '_', $class ) ) );
    $class = 'EnsEMBL::Web::BlastView::Meta'.$class;
    if( UNIVERSAL::can( $class, 'new' ) ){
      my $obj = $class->new();
      unless( $key =~ s/y$/ies/ ){ $key .= 's' }

      if( ref( $self->{$key} ) eq 'ARRAY' ){
	push( @{$self->{$key}}, $obj );
	my $name;
	eval{ $name = $self->get_name };                  # Update the new obj
	if( ! $@ ){ $obj->set_parent( $self->get_name ) } # with parent name
	return $obj
      }
      else{ croak( "Do not have a placeholder for type '$class'" ) }
    }
    else{
      croak( "Cannot create an object of type '$class'" );
    }
  }

  # Validate
  my @caller = caller;
  if( $key eq '-' ){ 
    croak( "The method '$AUTOLOAD' is not valid." );
  }
  if( ! exists( $self->{$key} ) ){
    croak( "Key '$key' not found in '".ref($self)."' object. Called from: ",
	   $caller[0], ", line ", $caller[2] );
  }

  # Set value (scalar)
  if( $action eq 'set' ){
    $self->{$key} = $value;
    return 1;
  }

  # Add value (list)
  if( $action eq 'add' ){
    if( ref( $self->{$key} ) eq 'ARRAY' ){
      push( @{$self->{$key}}, $value ) && return 1;
    }
    if( ref( $self->{$key} ) eq 'HASH' ){
      if( ref( $value ) !~ /EnsEMBL::Web::BlastView::Meta/ ){ 
	die( "'$value' is not an EnsEMBL::Web::BlastView::Meta object. Called from: ",
	      $caller[0], ", line ", $caller[2] ); 
	return undef();
      }
      $self->{$key}->{$value->get_name} = $value;
      return 1;
    }
    die( "Key '$key': not arrayref/hashref: cannot add. Called from: ",
	 $caller[0], ", line ", $caller[2] );
    return undef();
  }

  # Get value
  if( $action eq 'get' ){
    my $retval;
    if( ref( $self->{$key} ) eq 'ARRAY' ){ 
      my @vals = @{$self->{$key}};
      if( ref( $vals[0] ) eq 'CODE' ){
	my $code = shift @vals;
	return $code->(@vals);
      }
      return @{$self->{$key}} 
    }
    if( ref( $self->{$key} ) eq 'HASH'  ){ 
      if( $value ){
	if( exists( $self->{$key}->{$value} ) ){
	  $retval = $self->{$key}->{$value}; 
	}
	else{ 	  
	  warn( "'$key' does not contain a value for '$value' in this '",
		ref($self),"' object. Called from: ",
		$caller[0], ", line ", $caller[2] );      
	}
      }
      else{ return %{$self->{$key}} }
    }
    else{ $retval = $self->{$key} }
    if( ref( $retval ) eq 'CODE' ){
      return $retval->($self, $value, @_);
    }
    return $retval;
  }

  if( $action eq 'avail' ){
    my $get_key = "get_$key";
    $get_key =~ s/-//g;
    grep{ ( $_ eq $value || $_ eq '__ALL__' ) && return 1 } $self->$get_key;
    return 0;
  }

  else{
    die( "Don't understand action '$action'" );
  }
}

#----------------------------------------------------------------------

=head2 get_valid

  Arg [1]   : 
  Function  : Overrides autoloader for validity checks.
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub get_valid {
  my $self   = shift;
  my $key    = '-valid';
  my @caller = caller;

  if( ref( $self->{$key} ) eq 'CODE' ){
    return $self->{$key}->( $self );
  }
  if( ref( $self->{$key} ) eq 'Regexp' ){
    return validate_form_regexp( $self );
  }
  return $self->{$key};
}

#----------------------------------------------------------------------

=head2 detect_error

  Arg [1]   : 
  Function  : Another autoloader override for validity checks
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub detect_error {
  my $self = shift;
  my $key    = '-error';

  my @errors;
  my @tests = ( $self->{$key} );
  if( ref( $tests[0] ) eq 'ARRAY' ){ @tests = @{$tests[0]} }
  foreach my $test( @tests ){
    if( ref( $test ) eq 'CODE' ){
      if( my $err = $test->( $self, @_ ) ){ push @errors, $err }
    } 
    elsif( ref( $test ) eq 'Regexp' ){
#      warn( $test );
      if( ! validate_form_regexp( $self, $test ) ){
	push @errors, 'Could not understand value';
      }
    }
  }

  return join( '. Also: ', @errors );
}

#----------------------------------------------------------------------

=head2 is_available

  Arg [1]   : 
  Function  : Runs through the array of '-available'. 
              Returns 1 if all evaluate as true, 0 otherwise. 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub is_available {
  my $self = shift;
  my $key    = '-available';
  
  my $avail_ref = $self->{$key};
  my @avail_ary = ref($avail_ref) eq 'ARRAY' ? @{$avail_ref} : ($avail_ref); 

  foreach my $avail( @avail_ary ){
    $avail || return 0; 
    if( ref( $avail ) eq 'CODE' ){ 
      $avail->( $self, @_ ) || return 0; 
    } 
  }
  return 1;
}



#----------------------------------------------------------------------

=head2 run_cgi_processing

  Arg [1]   : 
  Function  : Another autoloader override for running process_value code
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub run_cgi_processing {

  my $self = shift;
  my $key    = '-cgi_processing';
  
  my $code_ref = $self->{$key};
  my @code_ary = ref( $code_ref ) eq 'ARRAY' ? @{$code_ref} : ( $code_ref ); 
  foreach my $code( @code_ary ){
    my $err;
    if( ref( $code ) eq 'CODE' ){ $err = $code->( $self, @_ ) } 
    if( $err ){ return $err }
  }
  return 0;
}



#----------------------------------------------------------------------

=head2 DESTROY

  Arg [1]   : 
  Function  : 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub DESTROY { }


#----------------------------------------------------------------------
1;
