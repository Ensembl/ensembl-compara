package EnsEMBL::Web::ViewConfig::Cell_line;

use strict;
use base qw(Exporter);

our @EXPORT_OK = qw(init form);
our @EXPORT    = @EXPORT_OK;

sub init {
  my ($view_config) = @_;
  
  $view_config->_set_defaults(qw(
    image_width   800
    context       200
    das_sources), []
  );
  
  $view_config->add_image_configs({ regulation_view => 'das' });
  $view_config->_set_defaults('opt_highlight' => 'yes');
  $view_config->_set_defaults('opt_empty_tracks' => 'yes');
  
  my $funcgen_tables    = $view_config->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'};
  my %cell_lines        = %{$funcgen_tables->{'cell_type'}{'ids'}};
  my %evidence_features = %{$funcgen_tables->{'feature_type'}{'ids'}};
  my %feature_type_ids  = %{$funcgen_tables->{'meta'}{'feature_type_ids'}};
  my %focus_set_ids     = %{$funcgen_tables->{'meta'}{'focus_feature_set_ids'}};
  
  foreach my $cell_line (keys %cell_lines) {
    $cell_line =~ s/\:\w*//;
    
    # allow all evdience for this sell type to be configured together  
    $view_config->_set_defaults("opt_cft_$cell_line:all" => 'off');
    
    foreach my $evidence_type (keys %evidence_features) {
      my ($evidence_name, $evidence_id) = split /\:/, $evidence_type;  
      my $value = 'off';
      
      if (exists $focus_set_ids{$cell_line}{$evidence_id}) {
        $value = 'on';
      } elsif ($cell_line eq 'MultiCell' && exists $feature_type_ids{'core'}{$evidence_id}) {
        $value = 'on';
      }
      
      $view_config->_set_defaults("opt_cft_$cell_line:$evidence_name" => $value);
    }
  }
  
  foreach my $evidence_type (keys %evidence_features) {
    $evidence_type =~ s/\:\w*//;
    $view_config->_set_defaults("opt_cft_$evidence_type:all" => 'off');
  }

  $view_config->storable = 1;
  $view_config->nav_tree = 1;
}

sub form {
  my ($view_config, $object) = @_;  
  
  my $funcgen_tables = $view_config->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'};
  
  # Add matrix style selection 
  my %cell_lines        = %{$funcgen_tables->{'cell_type'}{'ids'}};
  my %evidence_features = %{$funcgen_tables->{'feature_type'}{'ids'}};  
  my %focus_set_ids     = %{$funcgen_tables->{'meta'}{'focus_feature_set_ids'}};  
  my %feature_type_ids  = %{$funcgen_tables->{'meta'}{'feature_type_ids'}};
  
  my %focus_feature_type_ids;
  my $focus_row = 3;
  my $row = 3;
  
  # Allow focus sets to appear first
  # All MultiCell feature types are focus sets so add these in ($feature_type_ids{'core'})
  foreach my $feature_sets (values(%focus_set_ids), $feature_type_ids{'core'}) {
    $focus_feature_type_ids{$_} ||= $focus_row++ for keys %$feature_sets;
  }
  
  $view_config->add_fieldset('Evidence types', 'matrix');
  
  # Add row headers
  $view_config->add_form_element({
    type   => 'CheckBox',
    label  => '<span style="color: #880000">Core features:</span>',
    name   => 'opt_ft_core',
    value  => 'on',
    raw    => 1,
    layout => '2:0',
  });
  
  $view_config->add_form_element({
    type   => 'CheckBox',
    label  => '<span style="color: #880000">Other features:</span>',
    name   => 'opt_ft_other',
    value  => 'on',
    raw    => 1,
    layout => "$focus_row:0",
  });
  
  $view_config->add_form_element({
    type   => 'CheckBox',
    label  => '&nbsp',
    name   => 'opt_ft_no_data',
    value  => 'on',
    raw    => 1,
    layout => '1:0',
  });
  
  foreach my $feature (sort keys %evidence_features) {
    my ($feature_name, $feature_id) = split /\:/, $feature; 
    my $column    = 2;
    my $name      = "opt_cft_$feature_name";
    my $row_value = $focus_feature_type_ids{$feature_id} ? $row++ : ++$focus_row;
    
    # Add row headers
    $view_config->add_form_element({
      type   => 'CheckBox',
      label  =>  $feature_name,
      name   =>  "$name:header",
      value  => 'on',
      raw    => 1,
      layout => "$row_value:0",
    });
    
    # Add select all for row 
    $view_config->add_form_element({
      type    => 'CheckBox',
      label   => 'Select all',
      name    => $name,
      value   => 'select_all',
      classes => [ 'select_all_row' ],
      raw     => 1,
      layout  => "$row_value:1",
    });

    foreach my $cell_line (sort keys %cell_lines) { 
      $cell_line =~ s/\:\w*//;
      
      my $name     = "opt_cft_$cell_line:$feature_name";
      my $disabled = 1;
      my $classes  = [];
      
      if (exists $feature_type_ids{$cell_line}{$feature_id}) { 
        $disabled = 0; 
        $classes = [ "opt_cft_$cell_line", "opt_cft_$feature_name" ];
      } elsif ($cell_line eq 'MultiCell') {
        if (exists $feature_type_ids{'core'}{$feature_id}) {
          $disabled = 0;
          $classes  = [ "opt_cft_$cell_line", "opt_cft_$feature_name" ];
        }
      }
      
      $view_config->add_form_element({   
        type     => 'CheckBox', 
        name     => $name,
        value    => 'on',
        raw      => 1, 
        disabled => $disabled,
        layout   => "$row_value:$column",
        classes  => $classes,
      });
      
      $column++;
    }
  }

  # Add column to contain select all from row checkbox
  $view_config->add_form_element({
    type   => 'CheckBox',
    name   => 'cell_line:all',
    label  => '&nbsp;',
    value  => 'on',
    raw    => 1,
    layout => '0:1',
  });
  
  my $column = 2;
  
  foreach my $cell_line (sort keys %cell_lines) {
    $cell_line =~ s/\:\w*//;
    
    my $name = "opt_cft_$cell_line";
    
    $view_config->add_form_element({
      type   => 'CheckBox',
      label  => $cell_line,
      name   => "$name:header",
      value  => 'on',
      raw    => 1,
      layout => "0:$column",
    });
    
    $view_config->add_form_element({
      type    => 'CheckBox',
      label   => 'Select all',
      name    => $name,
      value   => 'select_all',
      classes => [ 'select_all_column' ],
      raw     => 1,
      layout  => "1:$column",
    });
    
    $column++;
  }

  # Add context selection
  $view_config->add_fieldset('Context');
  $view_config->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'context',
    label  => 'Context',
    values => [
      { value => '20',   name => '20bp'   },
      { value => '50',   name => '50bp'   },
      { value => '100',  name => '100bp'  },
      { value => '200',  name => '200bp'  },
      { value => '500',  name => '500bp'  },
      { value => '1000', name => '1000bp' },
      { value => '2000', name => '2000bp' },
      { value => '5000', name => '5000bp' }
    ]
  });

  $view_config->add_form_element({ type => 'YesNo', name => 'opt_highlight',    select => 'select', label => 'Highlight core region' });
  $view_config->add_form_element({ type => 'YesNo', name => 'opt_empty_tracks', select => 'select', label => 'Show empty tracks' });
}

1;
