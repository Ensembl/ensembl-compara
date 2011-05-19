# $Id$

package EnsEMBL::Web::ViewConfig::Cell_line;

use strict;

use JSON qw(from_json);

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
 
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
  
  my $funcgen_tables           = $self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'};
  $self->{'cell_lines'}        = $funcgen_tables->{'cell_type'}{'ids'};
  $self->{'evidence_features'} = $funcgen_tables->{'feature_type'}{'ids'};
  $self->{'feature_type_ids'}  = $funcgen_tables->{'meta'}{'feature_type_ids'};
  $self->{'focus_set_ids'}     = $funcgen_tables->{'meta'}{'focus_feature_set_ids'};
  
  my $defaults = {
    opt_highlight    => 'yes',
    opt_empty_tracks => 'yes'
  };
  
  foreach my $cell_line (keys %{$self->{'cell_lines'}}) {
    $cell_line =~ s/\:\w*//;
    
    # allow all evdience for this sell type to be configured together  
    $defaults->{"opt_cft_$cell_line:all"} = 'off';
    
    foreach my $evidence_type (keys %{$self->{'evidence_features'}}) {
      my ($evidence_name, $evidence_id) = split /\:/, $evidence_type;
      $defaults->{"opt_cft_$cell_line:$evidence_name"} = exists $default_evidence_types{$evidence_name} && exists $self->{'feature_type_ids'}{$cell_line}{$evidence_id} ? 'on' : 'off';
    }
  }
  
  foreach my $evidence_type (keys %{$self->{'evidence_features'}}) {
    $evidence_type =~ s/\:\w*//;
    $defaults->{"opt_cft_$evidence_type:all"} = 'off';
  }
  
  $self->set_defaults($defaults);
}

sub form {
  my $self = shift;
  my $hub  = $self->hub;
  
  if ($hub->function eq 'Cell_line') {
    $self->form_evidence_types;
  } else {
    my $tree = $self->tree;
    my $node = $tree->get_node('functional');
    
    if ($self->can('form_context')) {
      $self->form_context;
      $node->append($tree->get_node('context'));
    }
    
    $node->append($tree->create_node('evidence_types', { url => $hub->url('Config', { function => 'Cell_line', partial => 1 }), availability => 1, caption => 'Evidence types', class => 'Evidence_types' }));
  }
}

sub build_imageconfig_form {
  my $self         = shift;
  my $image_config = shift;
  
  $_->set('controls', qq{<div style="width:auto"><a href="#Evidence_types" class="modal_link">Configure Evidence types</a></div>}) for grep $_->get('glyphset') eq 'fg_multi_wiggle', $image_config->get_tracks;
  $self->SUPER::build_imageconfig_form($image_config);
}

sub form_evidence_types {
  my $self      = shift;
  my $focus_row = 3;
  my $row       = 3;
  my %focus_feature_type_ids;
  
  $self->info_panel;
  
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
      $row->{'row'}->{$cell_line}->{'default'} = 1 if $self->{'options'}{"opt_cft_$cell_line:$feature_name"}{'default'} eq 'on';
      $row->{'row'}->{$cell_line}->{'checked'} = 1 if $self->get("opt_cft_$cell_line:$feature_name") eq 'on';
      $row->{'row'}->{$cell_line}->{'title'}   = "$cell_line:$feature_name";
    }
    
    push @{$groups->{$set}}, $row;
  }
  
  foreach my $subheading (keys %$groups) {
    $matrix->add_subheading(ucfirst "$subheading features:", $subheading);
    $matrix->add_row($_->{'name'}, $_->{'row'}) for @{$groups->{$subheading}};
  }
}

sub info_panel {
  my $self = shift;
  my $form = $self->get_form;
  
  $form->append_child($form->dom->create_element('div', { class => 'content', inner_HTML => qq{
    <div class="info">
      <h3>Note:</h3>
      <div class ="error-pad">
      <p>
        These are data intensive tracks. For best performance it is advised that you limit the 
        number of feature types you try to display at any one time.
      </p>
      <p>
        Any cell lines that you configure here must also be turned on in the <a href="#functional" class="modal_link">Functional genomics</a> section before any data will be displayed.
      </p>
      </div>
    </div>
  }}));
}

# Set image config tracks when selecting checkboxes
sub update_from_input {
  my $self         = shift;
  my $hub          = $self->hub;
  my $input        = $hub->input;
  my $image_config = $hub->get_imageconfig($self->image_config) if $self->image_config;
  
  return $self->reset($image_config) if $input->param('reset');
  
  my $diff = $input->param('view_config');
  my $flag = 0;
  my $altered;
  
  if ($diff) {
    my @options = $self->options;
    my (%cell_lines, %evidence_types);
    
    $diff = from_json($diff);
    
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
    
    foreach my $key (grep exists $self->{'options'}{$_}, keys %$diff) {
      my @values = ref $diff->{$key} eq 'ARRAY' ? @{$diff->{$key}} : ($diff->{$key});
      
      (my $cell_line = $key) =~ s/^opt_cft_//;
      ($cell_line)   = split /:/, $cell_line;
      
      if ($values[0] ne $self->{'options'}{$key}{'user'}) {
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
  }
  
  $self->altered   = $image_config->update_from_input if $image_config;
  $self->altered ||= $altered || 1 if $flag;
  
  return $self->altered;
}

1;
