# $Id$

package EnsEMBL::Web::ViewConfig::Cell_line;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  
  $self->_set_defaults(qw(
    image_width   800
    context       200
    das_sources), []
  );
 
  my %default_evidence_types = (
    CTCF     => 1,
    DNase1   => 1,
    H3K4me3  => 1,
    H3K36me3 => 1,
    H3K27me3 => 1,
    H3K9me3  => 1,
    PolII    => 1,
    PolIII   => 1,
  );  
 
  if ($self->type eq 'Regulation') {
    $self->add_image_configs({ regulation_view         => 'das' });
    $self->add_image_configs({ reg_detail_by_cell_line => 'das' }); 
  }

  $self->_set_defaults('opt_highlight'    => 'yes');
  $self->_set_defaults('opt_empty_tracks' => 'yes');
  
  my $funcgen_tables           = $self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'};
  $self->{'cell_lines'}        = $funcgen_tables->{'cell_type'}{'ids'};
  $self->{'evidence_features'} = $funcgen_tables->{'feature_type'}{'ids'};
  $self->{'feature_type_ids'}  = $funcgen_tables->{'meta'}{'feature_type_ids'};
  $self->{'focus_set_ids'}     = $funcgen_tables->{'meta'}{'focus_feature_set_ids'};
  
  foreach my $cell_line (keys %{$self->{'cell_lines'}}) {
    $cell_line =~ s/\:\w*//;
    
    # allow all evdience for this sell type to be configured together  
    $self->_set_defaults("opt_cft_$cell_line:all" => 'off');
    
    foreach my $evidence_type (keys %{$self->{'evidence_features'}}) {
      my ($evidence_name, $evidence_id) = split /\:/, $evidence_type; 
      my $value = ( exists $default_evidence_types{$evidence_name} && exists $self->{'feature_type_ids'}{$cell_line}{$evidence_id} ) ? 'on' : 'off';
      $self->_set_defaults("opt_cft_$cell_line:$evidence_name" => $value);
    }
  }
  
  foreach my $evidence_type (keys %{$self->{'evidence_features'}}) {
    $evidence_type =~ s/\:\w*//;
    $self->_set_defaults("opt_cft_$evidence_type:all" => 'off');
  }

  $self->storable = 1;
  $self->nav_tree = 1;
}

sub form {
  my ($self, $object) = @_;  
  
  my %focus_feature_type_ids;
  my $focus_row = 3;
  my $row = 3;

  # Allow focus sets to appear first
  foreach my $feature_sets (values %{$self->{'focus_set_ids'}}) {
    $focus_feature_type_ids{$_} ||= $focus_row++ for keys %$feature_sets;
  }
  
  my $fieldset = $self->add_fieldset('Evidence types', 'matrix');
  my $matrix   = $fieldset->add_matrix;
  
  $fieldset->set_flag($self->SELECT_ALL_FLAG);
  $matrix->configure({ name_prefix => 'opt_cft_', selectall_label => '<b>Select features:</b>' });
  
  foreach my $cell_line (sort keys %{$self->{'cell_lines'}}) {
    $cell_line =~ s/\:\w*//;
    $matrix->add_column({ name => $cell_line, caption => $cell_line });
  }
  
  my $groups = { core => [], other => [] };

  foreach my $feature (sort keys %{$self->{'evidence_features'}}) {
    my ($feature_name, $feature_id) = split /\:/, $feature;
    my $set = exists $focus_feature_type_ids{$feature_id} ? 'core' : 'other';
    
    my $row = {
      name => $feature_name,
      row  => {}
    };
    
    foreach my $cell_line (sort keys %{$self->{'cell_lines'}}) { 
      $cell_line =~ s/\:\w*//;
      
      $row->{'row'}->{$cell_line}->{'enabled'} = 1 if exists $self->{'feature_type_ids'}{$cell_line}{$feature_id};
      $row->{'row'}->{$cell_line}->{'default'} = 1 if $self->{'_options'}{"opt_cft_$cell_line:$feature_name"}{'default'} eq 'on';
      $row->{'row'}->{$cell_line}->{'checked'} = 1 if $self->get("opt_cft_$cell_line:$feature_name") eq 'on';
    }
    
    push @{$groups->{$set}}, $row;
  }
  
  foreach my $subheading (keys %$groups) {
    $matrix->add_subheading(ucfirst "$subheading features:", $subheading);
    $matrix->add_row($_->{'name'}, $_->{'row'}) for @{$groups->{$subheading}};
  }

  # Add context selection
  $self->add_fieldset('Context');
  $self->add_form_element({
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

  $self->add_form_element({ type => 'YesNo', name => 'opt_highlight',    select => 'select', label => 'Highlight core region' });
  $self->add_form_element({ type => 'YesNo', name => 'opt_empty_tracks', select => 'select', label => 'Show empty tracks'     });
}

sub update_from_input {
  my ($self, $image_config_name) = @_;
  
  $image_config_name ||= 'reg_detail_by_cell_line';
  
  my $hub   = $self->hub;
  my $input = $hub->input;
  
  return $self->reset if $input->param('reset');
  
  my $image_config = $hub->get_imageconfig($image_config_name);
  my @options      = $self->options;
  my $flag         = 0;
  my $altered;
  my %cell_lines;
  my %evidence_types;
  
  foreach (keys %{$self->{'evidence_features'}}) {
    my ($name, $id) = split /:/;
    my $type = 'other';
    
    foreach my $focus_set (values %{$self->{'focus_set_ids'}}) {
      if (exists $focus_set->{$id}) {
        $type = 'core';
        last;
      }
    }
    
    $evidence_types{$name} = $type;
  }
  
  foreach my $key (@options) {
    my @values = $input->param($key);
    
    (my $cell_line = $key) =~ s/^opt_cft_//;
    ($cell_line)   = split /:/, $cell_line;
    
    if (scalar @values && $values[0] ne $self->{'_options'}{$key}{'user'}) {
      $flag = 1;
      
      if (scalar @values > 1) {
        $self->set($key, \@values);
      } else {
        $self->set($key, $values[0]);
      }
      
      $altered ||= $key if $values[0] !~ /^(off|no)$/;
      
      $cell_lines{$cell_line}{$key} = $values[0];
    }
  }
  
  foreach my $cell_line (keys %cell_lines) {
    foreach my $key (keys %{$cell_lines{$cell_line}}) {
      my (undef, $feature) = split /:/, $key;
      
      if ($cell_lines{$cell_line}{$key} =~ /^(off|no)$/) {
        foreach (grep /^opt_cft_$cell_line/, @options) {
          if ($self->get($_) !~ /^(off|no)$/) {
            $cell_lines{$evidence_types{$feature}}{$cell_line} = 1;
            last;
          }
        }
      } else {
        $cell_lines{$evidence_types{$feature}}{$cell_line} = 1;
      }
    }
    
    for ('core', 'other') {
      my $node = $image_config->get_node("reg_feats_${_}_$cell_line");
      
      if ($cell_lines{$_}{$cell_line} && $node->get('display') eq 'off') {
        $node->set_user('display', 'compact');
        $image_config->altered = 1;
      }
    }
  }
  
  $self->altered = $altered || 1 if $flag;
}

1;
