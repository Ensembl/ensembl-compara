# $Id$

package EnsEMBL::Web::Component::Location::ChangeChromosome;

### Module to replace part of the former MapView, in this case 
### the form to navigate to a different chromosome

use strict;

use EnsEMBL::Web::Form;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(0);
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $object       = $self->object;
  my $image_config = $hub->get_imageconfig('Vsynteny');
  my $vwidth       = $image_config->image_height;
  my $form         = $self->new_form({ id => 'change_chr', action => $hub->url({ __clear => 1 }), method => 'get', class => 'nonstd autocenter labels_right check', style => $vwidth ? sprintf "width:${vwidth}px" : undef });
  my @chrs         = $self->chr_list($object);
  my $chr_name     = $object->seq_region_name;
  my $label        = 'Jump to Chromosome';

  if ($hub->action eq 'Synteny') {
    $form->add_element(
      type  => 'Hidden',
      name  => 'otherspecies',
      value => $hub->param('otherspecies') || $self->default_otherspecies,
    );

    $label = 'Jump to ' . $hub->species_defs->DISPLAY_NAME . ' chromosome';
  }

  $form->add_element(
    type         => 'DropDownAndSubmit',
    select       => 'select',
    style        => 'narrow',
    on_change     => 'submit',
    name         => 'r',
    label        => $label,
    values       => \@chrs,
    value        => $chr_name,
    button_value => 'Go'
  );

  return '<div class="autocenter_wrapper">' . $form->render . '</div>';
}

1;
