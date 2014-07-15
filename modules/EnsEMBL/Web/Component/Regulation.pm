=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  my ($self) = @_;

  my $hub = $self->hub;
  my %shown_cells;
  my $image_config = $hub->get_imageconfig('regulation_view');
  foreach my $type (qw(reg_features seg_features)) {
    my $menu = $image_config->get_node($type);
    next unless $menu;
    foreach my $node (@{$menu->child_nodes}) {
      next unless $node->id =~ /^(reg_feats|seg)_(.*)$/;
      next if $node->id =~ /^reg_feats_(core|non_core)_/;
      my $cell=$2;
      $shown_cells{$cell} = 1 unless $node->get('display') eq 'off';
    }
  }
  return [ keys %shown_cells ];
}

sub all_evidences {
  my ($self) = @_;

  my $hub = $self->hub;
  my $mode = 3;
  my %evidences;
  my $image_config = $hub->get_imageconfig('regulation_view');
  foreach my $type (qw(reg_feats_core reg_feats_non_core)) {
    my $menu = $image_config->get_node($type);
    next unless $menu;
    foreach my $node (@{$menu->child_nodes}) {
      my $ev = $node->id;
      my $cell = $node->id;
      $cell =~ s/^${type}_//;
      foreach my $node2 (@{$node->child_nodes}) {
        my $ev = $node2->id;
        $ev =~ s/^${type}_${cell}_//;  
        $evidences{$ev} ||= { cells => [], on => 0 };
        push @{$evidences{$ev}->{'cells'}},$cell;
        $evidences{$ev}->{'on'} ||= ( $node2->get('display') ne 'off' );
        $evidences{$ev}->{'group'} ||= $node2->get('group');
      }
      my $renderer = $node->get('display');
      if($renderer ne 'off') {
        $evidences{$ev}->{'on'} ||= 1;
        $mode &=~ 1 if $renderer eq 'tiling';
        $mode &=~ 2 if $renderer eq 'compact';
      }
    }
  }
  return { all => \%evidences, mode => $mode };
}

sub buttons { return @{$_[0]->{'buttons'}||[]}; }

sub cell_line_button {
  my ($self) = @_;

  my $cell_m = scalar @{$self->shown_cells};
  my $cell_n = scalar @{$self->object->all_cell_types};

  my $url = $self->hub->url('Component', {
    action   => 'Web',
    function    => 'CellTypeSelector/ajax',
  });

  push @{$self->{'buttons'}||=[]},{
    url => $url,
    caption => "Select cells (showing $cell_m/$cell_n)",
    class => 'cell-line',
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
  };
}

sub _current_renderer_setting {
  my ($self) = @_;

  my $mode = $self->all_evidences->{'mode'};
  return ($mode&1,!!($mode&2));
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
  my ($peaks_on,$signals_on) = $self->_current_renderer_setting;

  push @{$self->{'buttons'}||=[]},{
    url => $peaks_url,
    caption => 'Peaks',
    class => 'peak radiogroup',
    toggle => $peaks_on?'on':'off',
    group => 'renderer',
  },{
    url => $signals_url,
    caption => 'Signals',
    class => 'signal',
    toggle => $signals_on?'on':'off',
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
    class => 'unstyled config',
    rel => "modal_config_$component",
  };
}

1;
