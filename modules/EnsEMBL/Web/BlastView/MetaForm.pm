#----------------------------------------------------------------------
#
# TODO docs
#
#----------------------------------------------------------------------

package EnsEMBL::Web::BlastView::MetaForm;

use strict;
use warnings;
no warnings "uninitialized";

use Data::Dumper;

use EnsEMBL::Web::BlastView::Meta;

use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::BlastView::Meta);

sub _object_template{ 
  return 
    (
     -name         => '', # ID for this object
     -parent       => '', # ID of parent object (i.e. block name)
     -form_entries => [], # List of child objects (form entries)

     -type         => '',          # Type: used for HTML template, for example

     -default      => [], # Default value(s) for CGI param name

     -available      => [1], # Availability. Array exp's ANDed
     -error          => [], # Error detection code_ref/regexp/value
     -cgi_processing => [], # 'cgi value' processing code references 

     -jscript        => '', # Javascript code to add to HTML header
     -jscript_onload => '', # Javascript function to add to <BODY> tag

     -species      => ['__ALL__'], # Deprecated
     -focus        => ['__ALL__'], # Deprecated
     -outtype      => ['__ALL__'], # Deprecated
     -multispecies => 1,  # Deprecated

    );
}

#----------------------------------------------------------------------
#sub new{
#  my $caller = shift;
#  my $class = ref( $caller ) || $caller;
#  my $self  = $class->SUPER::new();
#  return $self;
#}

#----------------------------------------------------------------------
=head2 add_form_entries

  Arg [1]   : 
  Function  : 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub add_form_entries {
  my $key = '-form_entries';
  my $self = shift;
  my $form_entry = shift;

  # Validate args
  if( ref( $form_entry ) ne 'EnsEMBL::Web::BlastView::MetaFormEntry' ){
    carp( 'Arg not a MetaFormEntry object' );
    return undef();
  }
  if( ref( $self->{$key} ) ne 'ARRAY' ){ 
    carp( "Key '$key' does not point to an arrayref: cannot add" );
    return undef();
  }

  $form_entry->set_name( $self->get_name ); # Associate form entry with form
  if( ! $form_entry->get_cgi_name ){
    $form_entry->set_cgi_name( $self->get_name.$form_entry->get_name_suffix );
  }
  push( @{$self->{$key}}, $form_entry );
  return 1;
}

#----------------------------------------------------------------------

=head2 get_defaults

  Arg [1]   : 
  Function  : 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub get_defaults{
  my $self = shift;
  my %defaults;
  my @form_elements = $self->get_form_entries;
  foreach my $element( @form_elements ){
    my @defs = grep{ defined($_) } $element->get_default;
    next if ! scalar( @defs );
    $defaults{ $element->get_cgi_name } ||= [];
    push @{$defaults{ $element->get_cgi_name }}, @defs;
  }
  my @defs = grep{ defined($_) } $self->get_default;
  if( scalar( @defs ) ){ 
    $defaults{ $self->get_name } ||= [];
    push @{$defaults{  $self->get_name }}, @defs;
  }
  return %defaults;
}

#----------------------------------------------------------------------
1;
