=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

use base qw(EnsEMBL::Web::Component::Shared);

sub shown_cells {
  my ($self,$image_config) = @_;
  my $hub = $self->hub;

  my %shown_cells;
  my $ic = $hub->get_imageconfig($image_config);

  foreach my $type (qw(reg_features seg_features reg_feats_core reg_feats_non_core)) {
    my $menu = $ic->get_node($type);
    next unless $menu;
    foreach my $node (@{$menu->child_nodes}) {
      next unless $node->id =~ /^(reg_feats|seg)_(core_|non_core_)?(.*)$/;
      my $cell=$3;
      $shown_cells{$cell} = 1 unless $node->get('display') eq 'off';
    }
  }
  my $ev = $self->all_evidences($image_config)->{'all'};
  my %partials;
  foreach my $ex (values %$ev) {
    next unless $ex->{'on'};
    ($partials{$_}||=0)++ for(@{$ex->{'cells'}});
    ($partials{$_}||=0)-- for(@{$ex->{'oncells'}});
  }
  my @partials = grep { ($partials{$_}||0) } keys %shown_cells;

  return ([ keys %shown_cells ],\@partials);
}

sub all_evidences {
  my ($self, $image_config) = @_;
  $image_config ||= 'regulation_view';

  my $hub = $self->hub;
  my $mode = 4;
  my %evidences;
  my $image_config = $hub->get_imageconfig($image_config);
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
        $evidences{$ev} ||= { oncells => [], cells => [], on => 0 };
        $evidences{$ev}->{'on'} ||= ( $renderer2 ne 'off' );
        $evidences{$ev}->{'group'} ||= $node2->get('group');
        push @{$evidences{$ev}->{'cells'}},$cell;
        if($renderer2 ne 'off') {
          $mode = 3 if $mode == 4 and $renderer ne 'off';
          $evidences{$ev}->{'on'} ||= 1;
          push @{$evidences{$ev}->{'oncells'}},$cell if $renderer ne 'off';
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

sub button_portal {
  my ($self, $buttons, $class) = @_;
  $class ||= '';
  my $html;

  my $img_url = $self->img_url;

  foreach (@{$buttons || []}) {
    my ($counts,$url,$text,$extra_class) = ('','#','','');
    $extra_class = $_->{'class'} if $_->{'class'};
    if($_->{'count'}) {
     $counts = qq(<span class="counts">$_->{'count'}</span>);
    }
    if($_->{'text'}) {
      $text = qq(<div class="text">$_->{'text'}</div>);
    }
    $text =~ s/\n/<br>/g;
    $url = $_->{'url'} if $_->{'url'};
    $html .= ( qq(
      <div class="portal_box $extra_class">
        <a href="$_->{'url'}"
           title="$_->{'title'}"
           class="_ht">
          <img src="$img_url$_->{'img'}"
               alt="$_->{'title'}"/>
          $text
          $counts
        </a>
      </div>
    ));
    $html =~ s/ +/ /g;
  }

  return qq{<div class="portal $class">$html</div><div class="invisible"></div>};
}

sub nav_buttons {
  my ($self) = @_;

  my @buttons = (
    {
      img => "navb-reg-summary.png",
      title => "Summary",
      action => 'Summary',
      text => "Summary",
    },{
      img => "navb-reg-details.png",
      title => "Details by cell type",
      action => 'Cell_line',
      text => "Details by\ncell type",
    },{
      img => "navb-reg-context.png",
      title => "Feature context",
      action => 'Context',
      text => "Feature\ncontext",
    },{
      img => "navb-reg-sourcedata.png",
      title => "Source Data",
      action => 'Evidence',
      text => "Source Data",
    }
  );
  foreach my $b (@buttons) {
    if($b->{'action'} eq $self->hub->action) {
      $b->{'title'} = "YOU ARE ON THIS PAGE";
      $b->{'class'} = "navb-current";
    } else {
      $b->{'url'} = $self->hub->url({ action => $b->{'action'} });
    }
  }
  return $self->button_portal(\@buttons);
}

sub cell_line_button {
  my ($self,$image_config) = @_;

  my ($shown_cells, $partials) = $self->shown_cells($image_config);
  my $shown_count = scalar @$shown_cells;
  my $object      = $self->object || $self->hub->core_object('regulation');
  my $total_count = scalar keys %{$object->regbuild_epigenomes};

  my $url = $self->hub->url('MultiSelector', {
    action   => 'CellTypeSelector',
    image_config => $image_config,
  });

  my $partial_count = scalar(@$partials);
  my $count = "showing ".($shown_count - $partial_count)."/$total_count";
  $count   .= " and $partial_count partially" if $partial_count;

  my $components = $self->hub->components;

  push @{$self->{'buttons'}||=[]},{
    url =>  $self->hub->url({'type' => 'Config', 'action' => $self->hub->type, 'function' => $components->[0]->[0]}).'#regulatory_features',
    caption => "Configure Cell/Tissue",
    class => 'config',
    rel => 'modal_config_'.lc($components->[0]->[0]),
    modal => 1
  };
}

sub evidence_button {
  my ($self) = @_;

  return;
#we dont need the evidence button anymore

  my $ev = $self->all_evidences->{'all'};

  my $n = keys %$ev;
  my $m = grep { $_->{'on'} } values %$ev;
  my $url = $self->hub->url('MultiSelector', {
    action => 'EvidenceSelector',
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

1;
