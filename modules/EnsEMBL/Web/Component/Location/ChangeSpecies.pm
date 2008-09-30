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

  my $form = EnsEMBL::Web::Form->new( 'change_sp', '/'.$object->species.'/Location/Synteny', 'get', 'nonstd check' );

  my %synteny = $object->species_defs->multi('DATABASE_COMPARA', 'SYNTENY');
  my @species = keys %synteny;
  my @sorted_by_common = sort { $a->{'common'} cmp $b->{'common'} }
        map  { { 'name'=> $_, 'common' => $object->species_defs->get_config($_, "SPECIES_COMMON_NAME")} }
                          @species;
  my @values;
  foreach my $next (@sorted_by_common) {
    push @values, {'name'=>$next->{'common'}, 'value'=>$next->{'name'}} ;
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
    'value'   => $object->param('otherspecies'),
    'button_value' => 'Go'
  );
  return '<div class="center">'.$form->render.'</div>';
}

1;
