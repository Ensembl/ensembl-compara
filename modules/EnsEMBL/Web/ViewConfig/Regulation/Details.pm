package EnsEMBL::Web::ViewConfig::Regulation::Details;

use strict;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    image_width         800
    das_sources),       []
  );

  $view_config->add_image_configs({qw(
    reg_detail das
  )});

  ## Add config for focus feature track 
  $view_config->_set_defaults('opt_focus' => 'yes');

  ## Add config for different feature types 
  my %temp = %{$view_config->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'feature_type'}{'analyses'}};
  foreach (keys %temp){
    $view_config->_set_defaults('opt_ft_'.$_ => 'on');
  }

  $view_config->storable = 1;
}

sub form {
  my( $view_config, $object ) = @_;  
  my $reg_object = $object->core_objects->regulation;
  if ($reg_object->get_focus_attributes){
    $view_config->add_form_element({ 'type' => 'YesNo', 'name' => 'opt_focus',  'select' => 'select', 'label'  => 'Show Focus track:' });
  }
  
  my $non_focus = $reg_object->get_nonfocus_attributes;

  ## First group displayable feature sets by histone modification 
  my %sets_by_type;
  foreach my $set (@$non_focus){
     my $feature_type = $set->feature_set->feature_type->name .':'.  $set->feature_set->cell_type->name;
     my $histone_mod = substr($feature_type, 0, 2);
     if ($histone_mod =~/H\D/) {$histone_mod  = 'H1';}
     unless ($histone_mod =~/H\d/ ){ $histone_mod = 'Other';}
     $sets_by_type{$histone_mod} = {} unless exists $sets_by_type{$histone_mod};
     $sets_by_type{$histone_mod}{$feature_type} = $set; 
  }

  ## Add each feature set to page config according to histone modification
  foreach (sort keys %sets_by_type){
    $view_config->add_fieldset('Select ' .$_ .' feature sets to display');
    my %data  = %{$sets_by_type{$_}};   
    my @temp = values %data;
    foreach (sort {$a->feature_set->feature_type->name cmp $b->feature_set->feature_type->name}  @temp){
      my $name = 'opt_ft_'. $_->feature_set->feature_type->name.':'. $_->feature_set->cell_type->name;
      $view_config->add_form_element({
        'type'    => 'CheckBox', 
        'label'   => $_->feature_set->feature_type->name . ' (' .$_->feature_set->cell_type->name .')',
        'name'    => $name,
        'value'   => 'on', 
        'raw' => 1
      });
    } 
  }
}
1;

