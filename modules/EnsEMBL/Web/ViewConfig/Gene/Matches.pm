package EnsEMBL::Web::ViewConfig::Gene::Matches;
use strict;
use base qw(EnsEMBL::Web::ViewConfig);
sub init {
  my $view_config = shift;
  my $help        = shift;
  $view_config->storable = 1;
  $view_config->nav_tree = 1;
  my %defaults = map { ($_->{'priority'} >100) ? ($_->{'name'} => 'yes') : ($_->{'name'} => 'off') } get_xref_types($view_config->hub);
  $view_config->_set_defaults(%defaults);
}

sub form {
  my ($view_config, $object) = @_;
  foreach (sort { $b->{'priority'} <=> $a->{'priority'} || $a->{'name'} cmp $b->{'name'}} get_xref_types($view_config->hub)) {
    $view_config->add_form_element({
      type   => 'CheckBox',
      select => 'select',
      name   => $_->{'name'},
      label  => $_->{'name'},
      value  => 'yes'
    });
  }
}
sub get_xref_types {
  my $hub = shift;
  my @xref_types;
  foreach (split /,/, $hub->species_defs->XREF_TYPES) {
    my @type_priorities = split /=/;
	  push @xref_types, {
      name     => $type_priorities[0],
      priority => $type_priorities[1]
    };
  }
  return @xref_types;
}
1;