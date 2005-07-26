package EnsEMBL::Web::Input::Options;

=head1 NAME

EnsEMBL::Web::Input::Options.pm 

=head1 SYNOPSIS

Object to store input options

=head1 DESCRIPTION
  
 my $input  = new EnsEMBL::Web::Input::CGI( $ENV{'ENSEMBL_SCRIPT'} );
 my $db     = $input->options->get('number')
 
 Used to get and store options from input object

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
 Args[1]    : string
              option name to return
 Example    : $self->get('gene')
 Description: returns the specified option name
 Returns    : The option value

=cut

sub get {
    my $self = shift;
    my $call = shift;
    return $self->$call;
}

=head2 set

  Arg[1]      : String
                Option key
  Arg[2]      : String
                Option value
  Example     : $self->set('limit', '10');
  Description : option setter
  Return type : none

=cut

sub set {
    my $self = shift;
    my $option = shift;
    unless ($option) {
        warn "You must provide an option key";
        return;
    }
    my $value = shift;
    $self->{$option} = $value;
}

#----------- Autoload methods-----------------

sub DESTROY {}

sub RENDERER {}

#Autoload accessor for all params in input object
sub AUTOLOAD {
    my ($self) = shift ;
    no strict 'refs';
    
    my ($key) = $AUTOLOAD =~ /([^:]+)$/ or die "INPUT: AUTOLOAD ERROR: $AUTOLOAD";
                   
    # cache autoload
    # *{$AUTOLOAD} = sub { return $_[0]->{$key} };
    return $self->{$key} if exists $self->{$key};
    return undef;       
    # Can't find parameter so return undef.
}

1;
