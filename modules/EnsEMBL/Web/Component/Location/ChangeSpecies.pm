package EnsEMBL::Web::Component::Location::ChangeSpecies;

### Module to replace part of the former SyntenyView, in this case 
### the lefthand menu dropdown of syntenous species

use strict;

use EnsEMBL::Web::Form;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self   = shift;
  my $object = $self->object;
  my $url    = $object->_url({ otherspecies => undef }, 1);
  my $form   = new EnsEMBL::Web::Form('change_sp', $url->[0], 'get', 'nonstd check');
  
  $form->add_hidden($url->[1]);

  my %synteny_hash     = $object->species_defs->multi('DATABASE_COMPARA', 'SYNTENY');
  my %synteny          = %{$synteny_hash{$object->species} || {}};
  my @sorted_by_common = sort { $a->{'common'} cmp $b->{'common'} } map {{ name => $_, common => $object->species_defs->get_config($_, 'SPECIES_COMMON_NAME') }} keys %synteny;
  my @values;
  
  foreach my $next (@sorted_by_common) {
    next if $next->{'name'} eq $object->species;
    push @values, { name => $next->{'common'}, value => $next->{'name'} };
  }

  $form->add_element(
    type         => 'DropDownAndSubmit',
    select       => 'select',
    style        => 'narrow',
    name         => 'otherspecies',
    label        => 'Change Species',
    values       => \@values,
    value        => $object->param('otherspecies') || $object->param('species') || $self->default_otherspecies,
    button_value => 'Go'
  );
  
  return '<div class="center">' . $form->render . '</div>';
}

1;
