=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::Element::Navigation;

# Base class for left sided navigation menus

use strict;

use HTML::Entities qw(encode_entities);
use List::MoreUtils qw(any);

use base qw(EnsEMBL::Web::Document::Element);

sub new {
  return shift->SUPER::new({
    %{$_[0]},
    tree    => undef,
    active  => undef,
    caption => 'Local context',
    counts  => {}
  });
}

sub tree {
  my $self = shift;
  $self->{'tree'} = shift if @_;
  return $self->{'tree'};
}

sub active {
  my $self = shift;
  $self->{'active'} = shift if @_;
  return $self->{'active'};
}

sub caption {
  my $self = shift;
  $self->{'caption'} = shift if @_;
  return $self->{'caption'};
}

sub counts {
  my $self = shift;
  $self->{'counts'} = shift if @_;
  return $self->{'counts'} || {};
}

sub configuration {
  my $self = shift;
  $self->{'configuration'} = shift if @_;
  return $self->{'configuration'};
}

sub availability {
  my $self = shift;
  $self->{'availability'} = shift if @_;
  $self->{'availability'} ||= {};
  return $self->{'availability'};
}

sub implausibility {
  my $self = shift;
  $self->{'implausibility'} = shift if @_;
  $self->{'implausibility'} ||= {};
  return $self->{'implausibility'};
}

sub get_json {
  my $self = shift;
  return { nav => $self->content };
}

sub init {
  my $self          = shift;
  my $controller    = shift;    
  my $object        = $controller->object;
  my $hub           = $controller->hub;
  my $configuration = $controller->configuration;
  return unless $configuration;
  my $action        = $configuration->get_valid_action($hub->action, $hub->function);
 
  $self->tree($configuration->{'_data'}{'tree'});
  $self->active($action);
  $self->caption(ref $object && $object->short_caption ? $object->short_caption : $configuration->short_caption);
  $self->counts($object->counts) if ref $object;
  $self->availability(ref $object ? $object->availability : {});
  $self->implausibility(ref $object ? $object->implausibility : {});
  
  $self->{'hub'} = $hub;
}

sub content {
  my $self = shift;
  my $tree = $self->tree;
  
  return unless $tree;
  
  my $active = $self->active;
  my @nodes  = grep { $_->can('data') && !$_->data->{'no_menu_entry'} && $_->data->{'caption'} } @{$tree->root->child_nodes};
  my $menu;
  
  if ($active && $tree->get_node($active) || scalar @nodes) {
    my $hub        = $self->{'hub'};
    my $modal      = $self->renderer->{'_modal_dialog_'};
    my $config     = $hub->session->get_record_data({type => 'nav', code => $hub->type});
    my $img_url    = $hub->species_defs->img_url;
    my $counts     = $self->counts;
    my $all_params = !!$hub->object_types->{$hub->type};
    
    foreach (@nodes) {
      $_->data->{'top_level'} = 1;
      $self->build_menu($_, $hub, $config, $img_url, $modal, $counts, $all_params, $active, $nodes[-1] eq $_);
    }
    
    $menu .= $_->render for @nodes;
  }
  
  $tree->clear_references;
  
  return sprintf('
    %s
    <div class="header">%s</div>
    <ul class="local_context">%s</ul>',
    $self->configuration ? '' : '<input type="hidden" class="panel_type" value="LocalContext" />',
    encode_entities($self->strip_HTML($self->caption)),
    $menu
  );
}

sub is_implausible {
  my ($self,$key) = @_;

  return $self->{'implausibility'}{$key};
}

sub plausible {
  my ($self,$node) = @_;

  my $implaus = $node->data->{'implausibility'};
  return !$implaus || !$self->is_implausible($implaus);
}

sub plausible_children {
  my ($self,$node) = @_;

  my @children     = grep { $_->can('data') && !$_->data->{'no_menu_entry'} && $_->data->{'caption'} } @{$node->child_nodes};
  return
    any { $self->plausible($_) or $self->plausible_children($_) }
    @children;
}

sub build_menu {
  my ($self, $node, $hub, $config, $img_url, $modal, $counts, $all_params, $active, $is_last) = @_;
  
  my $data = $node->data;
  
  return if $data->{'no_menu_entry'} || !$data->{'caption'};
  
  my @children     = grep { $_->can('data') && !$_->data->{'no_menu_entry'} && $_->data->{'caption'} } @{$node->child_nodes};
  my $caption      = $data->{'caption'};
  my $title        = $data->{'full_caption'} || $caption;
  my $count        = $data->{'count'};
  my $availability = $data->{'availability'};
  my $class        = $data->{'class'};
    ($class        = $caption) =~ s/ /_/g unless $class;
  my $state        = $config->{$class} ^ $data->{'closed'};
  my $toggle       = $state ? 'closed' : 'open';
  my @classes      = $data->{'li_class'} || ();
  my @append;

  @children = grep { $self->plausible($_) or $self->plausible_children($_) } @children;

  if ($modal) {
    if ($data->{'top_level'}) {
      @append = ([ 'img', { src => "$img_url${toggle}2.gif", class => "toggle $class", alt => '' }]) if scalar @children;
    } else {
      @append = ([ 'img', { src => "${img_url}leaf.gif", alt => '' }]);
    }
  } else {
    @append = ([ 'img', scalar @children ? { src => "$img_url$toggle.gif", class => "toggle $class", alt => '' } : { src => "${img_url}leaf.gif", alt => '' }]);
  }
  
  if ($availability && $self->is_available($availability)) {
    # $node->data->{'code'} contains action and function where required, so setting function to undef is fine.
    # If function is NOT set to undef and you are on a page with a function, the generated url could be wrong
    # e.g. on Location/Compara_Alignments/Image the url for Alignments (Text) will also be Location/Compara_Alignments/Image, rather than Location/Compara_Alignments
    my $url = $data->{'url'} || $hub->url({ action => $data->{'code'}, function => undef }, undef, $all_params);
    my $rel = $data->{'external'} ? 'external' : $data->{'rel'};
    
    for ($title, $caption) {
      s/\[\[counts::(\w+)\]\]/$counts->{$1}||0/eg;
      $_ = encode_entities($_);
    }
    
    push @append, [ 'a',    { class => $class,  inner_HTML => $caption, href => $url, title => $title, rel => $rel }];
    push @append, [ 'span', { class => 'count', inner_HTML => $count }] if $count;
  } else {
    $caption =~ s/\(\[\[counts::(\w+)\]\]\)//eg;
    push @append, [ 'span', { class => 'disabled', title => $data->{'disabled'}, inner_HTML => $caption }];
  }
  
  if (scalar @children) {
    my $ul = $node->dom->create_element('ul');
    
    foreach (@children) {
      $self->build_menu($_, $hub, $config, $img_url, $modal, $counts, $all_params, $active, $children[-1] eq $_);
      $ul->append_child($_);
    }
    
    push @append, $ul;
    push @classes, 'parent';
  }
  
  push @classes, 'active'         if $node->id eq $active;
  push @classes, 'top_level'      if $data->{'top_level'};
  push @classes, 'last'           if $is_last;
  push @classes, 'closed'         if $toggle eq 'closed';
  push @classes, 'default_closed' if $data->{'closed'};
  
  $node->node_name('li');
  $node->set_attributes({ id => $data->{'id'}, class => join(' ', @classes) });
  $node->append_children(@append);
}

1;
