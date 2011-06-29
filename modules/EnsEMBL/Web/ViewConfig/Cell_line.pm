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
  $self->{'type_descriptions'} = $funcgen_tables->{'feature_set'}{'analyses'}{'RegulatoryRegion'}{'desc'};
  
  my $defaults;
  
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
    
    $self->form_context if $self->can('form_context');
    $tree->get_node('functional')->append($tree->create_node('regulatory_evidence', {
      url          => $hub->url('Config', { function => 'Cell_line', partial => 1 }),
      availability => 1,
      caption      => 'Regulatory evidence',
      class        => 'Regulatory_evidence'
    }));
  }
}

sub build_imageconfig_form {
  my $self         = shift;
  my $image_config = shift;
  
  $_->set('controls', qq{<div style="width:auto"><a href="#Regulatory_evidence" class="modal_link">Configure Regulatory evidence</a></div>}) for grep $_->get('glyphset') eq 'fg_multi_wiggle', $image_config->get_tracks;
  $self->SUPER::build_imageconfig_form($image_config);
}

sub form_evidence_types {
  my $self    = shift;
  my $groups  = { core => [], other => [] };
  my @columns = ( sort(map { s/\:\w*//; $_ } grep !/MultiCell/, keys %{$self->{'cell_lines'}}), 'MultiCell' );
  my %focus_feature_type_ids;
  
  my $select_all_col = qq{
    <div class="select_all_column floating_popup">
      Select features for %s<br />
      <div><input type="radio" name="%s" class="default">Default</input></div>
      <div><input type="radio" name="%s" class="all">All</input></div>
      <div><input type="radio" name="%s" class="none">None</input></div>
    </div>
  };
  
  my $select_all_row = qq{
    <div class="select_all_row floating_popup">
      Select all<br />
      %s
      <input type="checkbox" />
    </div>
  };
  
  $self->{'panel_type'} = 'FuncgenMatrix';
  
  # Allow focus sets to appear first
  foreach my $feature_sets (values %{$self->{'focus_set_ids'}}) {
    $focus_feature_type_ids{$_} = 1 for keys %$feature_sets;
  }
  
  foreach my $feature (sort keys %{$self->{'evidence_features'}}) {
    my ($feature_name, $feature_id) = split /\:/, $feature;
    my $set = exists $focus_feature_type_ids{$feature_id} ? 'core' : 'other';
    my @row = ($feature_name, { tag => 'th', class => 'first', html => sprintf("$feature_name$select_all_row", $feature_name) }); # row name
    
    foreach my $cell_line (@columns) {
      my $cell = { tag => 'td', html => '<p></p>' };
      
      if (exists $self->{'feature_type_ids'}{$cell_line}{$feature_id}) {
        $cell->{'title'}  = "$cell_line:$feature_name";
        $cell->{'class'}  = "option $cell_line $feature_name";
        $cell->{'class'} .= ' on'      if $self->get("opt_cft_$cell_line:$feature_name") eq 'on';
        $cell->{'class'} .= ' default' if $self->{'options'}{"opt_cft_$cell_line:$feature_name"}{'default'} eq 'on';
      } else {
        $cell->{'class'} = 'disabled';
      }
      
      push @row, $cell;
    }
    
    push @{$groups->{$set}}, \@row;
  }
  
  my $width = (scalar @columns * 26) + 86; # Each td is 25px wide + 1px border. The first cell (th) is 85px + 1px border
  my $html  = '
    <div class="matrix_key">
      <h2>Key</h2>
      <div class="key"><div>On</div><div class="cell on"></div></div>
      <div class="key"><div>Off</div><div class="cell off"></div></div>
      <div class="key"><div>Unavailable</div><div class="cell disabled"></div></div>
    </div>
  ';
  
  foreach my $set ('core', 'other') {
    my @cols = map {{ class => $_, html => sprintf("<p>$_</p>$select_all_col", $_, $_, $_, $_), enabled => 0 }} @columns;
    my @rows;
    
    foreach (@{$groups->{$set}}) {
      my $row_class = shift @$_;
      my $i         = 0;
      my $row_html;
      
      foreach (@$_) {
        $row_html .= sprintf('<%s%s%s>%s</%s>',
          $_->{'tag'},
          $_->{'class'} ? qq{ class="$_->{'class'}"} : '',
          $_->{'title'} ? qq{ title="$_->{'title'}"} : '',
          $_->{'html'},
          $_->{'tag'}
        );
        
        $cols[$i-1]{'enabled'} ||= $_->{'class'} ne 'disabled' if $i;
        $i++;
      }
      
      push @rows, qq{<tr class="$row_class">$row_html</tr>};
    }
    
    $html .= sprintf('
      <div class="funcgen_matrix %s">
        <div class="header_wrapper">
          <h2>%s</h2>
          <div class="help" title="Click for more information"></div>
          <input type="text" class="filter" value="Search" />
          <div class="desc">%s</div>
        </div>
        <table class="funcgen_matrix" cellspacing="0" cellpadding="0" style="width:%spx">
          <thead>
            <tr><th class="first"></th>%s</tr>
          </thead>
          <tbody>
            %s
          </tbody>
        </table>
        <div class="no_results">No results found</div>
      </div>',
      $set,
      $set eq 'core' ? ucfirst $set : 'Histones &amp; Polymerases',
      $self->{'type_descriptions'}{$set},
      $width,
      join('', map { sprintf '<th class="%s">%s</th>', $_->{'enabled'} ? $_->{'class'} : 'disabled', $_->{'html'} } @cols),
      join('', @rows)
    );
  }
  
  $self->add_fieldset->append_children(
    [ 'h2',  { inner_HTML => 'Regulatory evidence' }],
    [ 'div', { id => 'funcgen_matrix', class => 'js_panel', inner_HTML => $html }]
  );
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
  my %altered_tracks;
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
          $altered_tracks{"reg_feats_${_}_$cell_line"} = 'compact';
        }
      }
    }
  }
  
  $self->altered   = $image_config->update_from_input if $image_config;
  $self->altered ||= $altered || 1 if $flag;
  
  return scalar keys %altered_tracks ? { imageConfig => \%altered_tracks, trackTypes => [ 'functional' ] } : $self->altered;
}

1;
