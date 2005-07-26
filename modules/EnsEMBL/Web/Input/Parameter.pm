package EnsEMBL::Web::Input::Parameter;

=head1 NAME

EnsEMBL::Web::Parameter - input parameter object for Ensembl web scripts

=head1 SYNOPSIS

  # Create and initailise the input parameters
  use EnsEMBL::Web::Input;
  my $input = EnsEMBL::Web::Input->new('contigview');
  $input->initialise_from_cgi(); # New values
  $input->retrieve_from_userdb(); # Saved values

  # Reset the input parameters to their saved values
  foreach my $parameter( $input->parameter ){
      my @values = $parameter->values;
      if( $parameter->has_changed ){
	  my @saved_values = $parameter->saved_values;
	  $parameter->values(@saved_values);
      }
  }

=head1 DESCRIPTION

 Provides a container for an individual input parameter. Pretty much a
 simple key->value pair, but can handle multiple values, and keep
 track of state.

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Brian Gibbins - bg2@sanger.ac.uk

=cut

use strict;

#----------------------------------------------------------------------

=head2 new

  Arg [1]   : 
  Function  : Instantiates EnsEMBL::Web::Input::Parameter object
  Returntype: EnsEMBL::Web::Parameter
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub new {
    my $class     = shift;
    my $self = bless {}, $class;
    $self->_initialise_parameter( @_ );
    return $self;
}

#----------------------------------------------------------------------

=head2 _initialise_parameter

  Arg [1]   : As for new()
  Function  : Parameter initailisation. Can be subclassed if obj inhereted
  Returntype: boolean: true on success
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub _initialise_parameter {
    my $self  = shift;
    my $name  = shift;
    my $value = shift;

    # Initialise value structure to cope with different types
    $self->{_value} = {};
    $self->{_value}->{_default} = [];
    $self->{_value}->{_stored}  = [];
    $self->{_value}->{_initial} = [];
    $self->{_value}->{_runtime} = [];

    $name  && $self->name( $name );
    $value && $self->value( 'initial', $value );

    return 1;
}

#----------------------------------------------------------------------

=head2 name

  Arg [1]   : String - Parameter name (optional)
  Function  : Gets/sets the name for this parameter
  Returntype: String
  Exceptions: 
  Caller    : 
  Example   : my $name = $param->name('foo');

=cut

sub name {
    my $self = shift;
    my $key = '_name';
    if( @_ ){ $self->{$key} = shift }
    return $self->{$key};
}

#----------------------------------------------------------------------

=head2 value

  Arg [1]   : Scalar - value type (optional), OR
              Arrayref of parameter values (optional)
  Arg [2]   : Arrayref of parameter values (optional)
  Function  : Gets/sets the current value for this parameter object.
              Value types are: default, stored, initial, runtime (default)
              If value is called without specifying a type, then the object
              will seek for a value with the following priority:
              runtime>initial>stored>default
  Returntype: wantarray ? value : list of values
  Exceptions: Value type not one of above types
  Caller    :
  Example   : my $value = $param->(['a','b']); # Returns 'a'

=cut

sub value {

   my $self = shift;
   my $default_type = 'runtime';
   my $type;
   ref( $_[0] ) or $type = shift; # Type as 1'st arg

   # Set the new value
   if( @_ ){
       ref( $_[0] ) eq 'ARRAY' ||
	 die( "Value must be an arrayref" );
       $type ||= $default_type;
       $type = lc( $type );

       my $old_valueref = $self->{_value}->{"_$type"} ||
	 die( "Value type $type is not recognised" );

       my $new_valueref = shift;
       $old_valueref = [ @$new_valueref ];
       $self->{_value}->{"_$type"} = $old_valueref;
   }

   # Get the value, testing each possible type if type not explicit
   my $valueref;
   if( $type ){ $valueref = $self->{_value}->{"_$type"} }
   else{
       foreach my $type qw( runtime initial stored default ){
	   $valueref = $self->{_value}->{"_$type"} || [];
	   scalar( @$valueref ) && last
       }
   }

   # Return
   return wantarray ? @{$valueref} : $valueref->[0];
}

#----------------------------------------------------------------------
1;
