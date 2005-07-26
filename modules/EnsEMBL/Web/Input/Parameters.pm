package EnsEMBL::Web::Input::Parameters;

=head1 NAME

EnsEMBL::Web::Input::Parameters.pm 

=head1 SYNOPSIS

Object to store input parameters

=head1 DESCRIPTION
  
 my $input  = new EnsEMBL::Web::Input::CGI( $ENV{'ENSEMBL_SCRIPT'} );
 my $db 	= $input->parameters->get('db')
 
 Used to get and store parameters from input object

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Brian Gibbins - bg2@sanger.ac.uk

=cut

use strict;
use vars '$AUTOLOAD';

sub new{
    my $class = shift;       
    my $self = shift;    
    bless( $self, $class );    
	return $self;
}

=head2 get
 Args[1]	: string
 				parameter name to return
 Example 	: $self->get('gene')
 Description: returns the specified parameter name
 Returns 	: The parameter value

=cut

sub get{
	my $self = shift;
	my $call = shift;
	return $self->$call;
}

#----------- Autoload methods-----------------

sub DESTROY {}

#Autoload accessor for all params in input object
sub AUTOLOAD {
  my ($self) = shift ;
  no strict 'refs';
    
  my ($key) = $AUTOLOAD =~ /([^:]+)$/ or die "INPUT: AUTOLOAD ERROR: $AUTOLOAD";
                   
  # *{$AUTOLOAD} = sub { return $_[0]->{$key} };
  return $self->{$key} if exists $self->{$key};
  return undef;
}

1;
