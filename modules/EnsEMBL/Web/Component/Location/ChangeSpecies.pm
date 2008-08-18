package EnsEMBL::Web::Component::Location::ChangeSpecies;

### Module to replace part of the former SyntenyView, in this case 
### the lefthand menu dropdown of syntenous species

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use CGI qw(escapeHTML);
sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $form = EnsEMBL::Web::Form->new( 'change_sp', '/'.$object->species.'/Location/Synteny', 'get' );

  my %synteny = $object->species_defs->multi('SYNTENY');
  my @species = keys %synteny;
  my @values;
  foreach my $next (@species) {
    (my $name = $next) =~ s/_/ /g;
    push @values, {'name'=>$name, 'value'=>$next} ;
  }

  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'r',
    'value'   => $object->param('r'),
  );

  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'db',
    'value'   => 'core',
  );

  $form->add_element(
    'type'     => 'DropDownAndSubmit',
    'select'   => 'select',
    'style'    => 'narrow',
    'on_change' => 'submit',
    'name'     => 'otherspecies',
    'label'    => 'Change Species',
    'values'   => \@values,
    'button_value' => 'Go'
  );
  return '<div class="center">'.$form->render.'</div>';
}

1;
