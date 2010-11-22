# $Id$

package EnsEMBL::Web::ViewConfig::ExternalData;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $view_config = shift;

  $view_config->storable   = 1;
  $view_config->can_upload = 1; # allows configuration of DAS etc
  $view_config->_set_defaults(map { $_->logic_name => undef } values %{$view_config->hub->get_all_das});
}

sub form {
  my ($view_config, $object) = @_;
  
  $view_config->add_fieldset('DAS sources');
  
  my $view    = $object->__objecttype . '/ExternalData';
  my @all_das = sort { lc $a->label cmp lc $b->label } grep $_->is_on($view), values %{$view_config->hub->get_all_das};
  
  foreach my $das (@all_das) {
    $view_config->add_form_element({
      type  => 'DASCheckBox',
      das   => $das,
      name  => $das->logic_name,
      value => 'yes'
    });
  }
}

1;
