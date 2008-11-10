package EnsEMBL::Web::ViewConfig::Gene::ExternalData;

use strict;
use warnings;
use EnsEMBL::Web::RegObj;

sub init {
  my ($view_config) = @_;

  $view_config->storable = 1;
  $view_config->can_upload = 1; # allows configuration of DAS etc
  
  $view_config->_set_defaults( map {
    $_->logic_name => undef 
  } values %{ $ENSEMBL_WEB_REGISTRY->get_all_das() } );
}

sub _view {
  return 'Gene/ExternalData';
}

sub form {
  my ( $view_config, $object ) = @_;
  
  $view_config->add_fieldset('Das sources', 'table');
# 'type' => 'SubHeader', 'value' => 'DAS Sources' });
  my @all_das = sort {
    $a->label cmp $b->label
  } grep {
    1#  ;$_->is_on( _view )
  } values %{ $ENSEMBL_WEB_REGISTRY->get_all_das() };

  for my $das ( @all_das ) {
    $view_config->add_form_element({
      'type' => 'DASCheckBox',
      'das'  => $das,
      'name' => $das->logic_name,
      'value'=> 'yes'
    });
  }
}


1;
