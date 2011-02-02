# $Id$

package EnsEMBL::Web::ViewConfig::ExternalData;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;

  $self->storable   = 1;
  $self->_set_defaults(map { $_->logic_name => undef } values %{$self->hub->get_all_das});
}

sub form {
  my ($self, $object) = @_;
  
  $self->add_fieldset('DAS sources');
  
  my $view    = $object->__objecttype . '/ExternalData';
  my @all_das = sort { lc $a->label cmp lc $b->label } grep $_->is_on($view), values %{$self->hub->get_all_das};
  
  foreach my $das (@all_das) {
    $self->add_form_element({
      type  => 'DASCheckBox',
      das   => $das,
      name  => $das->logic_name,
      value => 'yes'
    });
  }
}

1;
