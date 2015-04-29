=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Component::Regulation;

use strict;

use base qw(EnsEMBL::Web::Component);

sub shown_cells {
  my ($self,$image_config) = @_;

  my $hub = $self->hub;
  my %shown_cells;
  my $image_config = $hub->get_imageconfig($image_config);
  foreach my $type (qw(reg_features seg_features reg_feats_core reg_feats_non_core)) {
    my $menu = $image_config->get_node($type);
    next unless $menu;
    foreach my $node (@{$menu->child_nodes}) {
      next unless $node->id =~ /^(reg_feats|seg)_(core_|non_core_)?(.*)$/;
      my $cell=$3;
      next if $cell eq 'MultiCell';
      $shown_cells{$cell} = 1 unless $node->get('display') eq 'off';
    }
  }
  return [ keys %shown_cells ];
}

sub all_evidences {
  my ($self) = @_;

  my $hub = $self->hub;
  my $mode = 4;
  my %evidences;
  my $image_config = $hub->get_imageconfig('regulation_view');
  foreach my $type (qw(reg_feats_core reg_feats_non_core)) {
    my $menu = $image_config->get_node($type);
    next unless $menu;
    foreach my $node (@{$menu->child_nodes}) {
      my $ev = $node->id;
      my $cell = $node->id;
      $cell =~ s/^${type}_//;
      my $renderer = $node->get('display');
      foreach my $node2 (@{$node->child_nodes}) {
        my $ev = $node2->id;
        next unless $ev =~ s/^${type}_${cell}_//;
        my $renderer2 = $node2->get('display');
        $evidences{$ev} ||= { cells => [], on => 0 };
        $evidences{$ev}->{'on'} ||= ( $renderer2 ne 'off' );
        $evidences{$ev}->{'group'} ||= $node2->get('group');
        if($renderer2 ne 'off') {
          $mode = 3 if $mode == 4 and $renderer ne 'off';
          $evidences{$ev}->{'on'} ||= 1;
          $mode &=~ 1 if $renderer eq 'tiling';
          $mode &=~ 2 if $renderer eq 'compact';
        }
      }
    }
  }
  foreach my $ev (keys %evidences) {
    next unless $evidences{$ev}->{'group'} eq 'Histone';
    my $histone = 'Other';
    if($ev =~ /^(H\d)/) {
      $histone = $1;
      $histone = "H2A/B" if $histone eq 'H2';
    }
    $evidences{$ev}->{'cluster'} = $histone;
  }
  return { all => \%evidences, mode => $mode };
}

sub buttons { return @{$_[0]->{'buttons'}||[]}; }

sub nav_buttons {
  my ($self) = @_;

  my @buttons = (
    { css => 'summary', caption => 'Summary', action => 'Summary' },
    {
      css => 'details', caption => 'Details by Cell type',
      action => 'Cell_line'
    },
    { css => 'context', caption => 'Feature Context', action => 'Context' },
    { css => 'sourcedata', caption => 'Source Data', action => 'Evidence' }
  );

  my $action = $self->hub->action;
  foreach my $b (@buttons) {
    my $url = $self->hub->url({ action => $b->{'action'} });
    my $title = $b->{'caption'};
    my $disabled = 0;
    if($action eq $b->{'action'}) {
      $url = '#';
      $title = 'YOU ARE ON THIS PAGE';
      $disabled = 1;
    }
    push @{$self->{'buttons'}||=[]},{
      nav_image => "navb_reg_$b->{'css'}",
      caption => $b->{'caption'},
      title => $title,
      url => $url,
      disabled => $disabled,
    };
  }
}

sub cell_line_button {
  my ($self,$image_config) = @_;

  my $cell_m = scalar @{$self->shown_cells($image_config)};
  my $cell_n = scalar @{$self->object->all_cell_types};

  my $url = $self->hub->url('Component', {
    action   => 'Web',
    function    => 'CellTypeSelector/ajax',
    image_config => $image_config,
  });

  push @{$self->{'buttons'}||=[]},{
    url => $url,
    caption => "Select cells (showing $cell_m/$cell_n)",
    class => 'cell-line',
    modal => 1
  };
}

sub evidence_button {
  my ($self) = @_;

  my $ev = $self->all_evidences->{'all'};

  my $n = keys %$ev;
  my $m = grep { $_->{'on'} } values %$ev;
  my $url = $self->hub->url('Component', {
    action => 'Web',
    function => 'EvidenceSelector/ajax',
  });
  
  push @{$self->{'buttons'}||=[]},{
    url => $url,
    caption => "Select evidence (showing $m/$n)",
    class => 'evidence',
    modal => 1
  };
}

sub _current_renderer_setting {
  my ($self) = @_;

  my $mode = $self->all_evidences->{'mode'};
  return (!!($mode&4),$mode&1,!!($mode&2));
}

sub renderer_button {
  my ($self) = @_;

  my $peaks_url = $self->hub->url('Ajax', {
    type => 'reg_renderer',
    renderer => 'peaks',
  });
  my $signals_url = $self->hub->url('Ajax', {
    type => 'reg_renderer',
    renderer => 'signals',
  });
  my ($disabled,$peaks_on,$signals_on) = $self->_current_renderer_setting;

  push @{$self->{'buttons'}||=[]},{
    url => $peaks_url,
    caption => 'Peaks',
    class => 'peak radiogroup',
    toggle => $peaks_on?'on':'off',
    disabled => $disabled,
    group => 'renderer',
  },{
    url => $signals_url,
    caption => 'Signal',
    class => 'signal',
    toggle => $signals_on?'on':'off',
    disabled => $disabled,
    group => 'renderer',
  };
}

sub advanced_button {
  my ($self,$component) = @_;

  my $hub = $self->hub;
  my @components = @{$hub->components};

  my $view_config;
  $view_config = $hub->get_viewconfig(@{shift @components}) while !$view_config && scalar @components; 
  my $url     = $self->hub->url('Config', {
    type      => $view_config->type,
    action    => $view_config->component,
    function  => undef,
  });
  push @{$self->{'buttons'}||=[]},{
    url => $url,
    caption => 'Advanced ...',
    class => 'unstyled config modal_link',
    rel => "modal_config_$component-functional",
  };
}

1;
