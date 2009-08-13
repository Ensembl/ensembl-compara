package EnsEMBL::Web::Component::Location::ChangeChromosome;

### Module to replace part of the former MapView, in this case 
### the form to navigate to a different chromosome

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use CGI qw(escapeHTML);
sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $form = EnsEMBL::Web::Form->new( 'change_chr', $object->_url({'__clear'=>1}), 'get', 'nonstd check' );

  my @chrs = $self->chr_list($object);
  my $chr_name = $object->seq_region_name;

  my $label = 'Jump to Chromosome';

  if ($object->action eq 'Synteny') {
    $form->add_element(
      'type'  => 'Hidden',
      'name'  => 'otherspecies',
      'value' => $object->param('otherspecies') || $self->default_otherspecies,
    );
    $label = 'Jump to '.$object->species_defs->DISPLAY_NAME.' chromosome';
  }

  $form->add_element(
    'type'     => 'DropDownAndSubmit',
    'select'   => 'select',
    'style'    => 'narrow',
    'on_change' => 'submit',
    'name'     => 'r',
    'label'    => $label,
    'values'   => \@chrs,
    'value'    => $chr_name,
    'button_value' => 'Go'
  );

  return '<div class="center">'.$form->render.'</div>';
}

1;
