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
  my @shown_cells;
  my $image_config = $hub->get_imageconfig('regulation_view');
  foreach my $type (qw(reg_features seg_features)) {
    my $menu = $image_config->get_node($type);
    next unless $menu;
    foreach my $node (@{$menu->child_nodes}) {
      next unless $node->id =~ /^(reg_feats|seg)_(.*)$/;
      my $cell=$2;
      unless($node->get('display') eq 'off') {
        push @shown_cells,$cell;
      }
    }
  }
  return \@shown_cells;
}

sub all_evidences {
  my ($self) = @_;

  my $hub = $self->hub;
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
        my $on = ( $node2->get('display') ne 'off' );
        $evidences{$ev} ||= { cells => [], on => 0 };
        push @{$evidences{$ev}->{'cells'}},$cell;
        $evidences{$ev}->{'on'} ||= $on;
        $evidences{$ev}->{'group'} ||= $node2->get('group');
      }
    }
  }
  return { all => \%evidences };
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

1;
