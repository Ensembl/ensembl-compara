package EnsEMBL::Web::Form::Element::YesNo;

use strict;
use base qw( EnsEMBL::Web::Form::Element::DropDown );

#--------------------------------------------------------------------
# Creates a form element for an option set, as either a select box
# or a set of radio buttons
# Takes an array of anonymous hashes, thus:
# my @values = (
#           {'name'=>'Option 1', 'value'=>'1'},
#           {'name'=>'Option 2', 'value'=>'2'},
#   );
# The 'name' element is displayed as a label or in the dropdown,
# whilst the 'value' element is passed as a form variable
#--------------------------------------------------------------------

sub new {
  my $class  = shift;
  my $self   = $class->SUPER::new(@_);
  $self->{'values'} = [ { 'value' => 'no', 'name' => 'No' }, { 'value' => 'yes', 'name' => 'Yes' } ];
  return $self;
}

1;
