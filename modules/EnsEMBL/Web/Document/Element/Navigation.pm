# $Id$

package EnsEMBL::Web::Document::Element::Navigation;

# Generates the left sided navigation menu, used in dynamic pages

use strict;

use HTML::Entities qw(encode_entities);

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

sub class {
  my $self = shift;
  $self->{'class'} = shift if @_;
  return $self->{'class'};
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

sub get_json {
  my $self = shift;
  $self->class('local_modal');
  return { nav => $self->content };
}

sub init {
  my $self          = shift;
  my $controller    = shift;    
  my $object        = $controller->object;
  my $hub           = $controller->hub;
  my $configuration = $controller->configuration;
  my $action        = $configuration->get_valid_action($hub->action, $hub->function);
 
  $self->tree($configuration->{'_data'}{'tree'});
  $self->active($action);
  $self->caption(ref $object ? $object->short_caption : $configuration->short_caption);
  $self->counts($object->counts) if ref $object;
  $self->availability(ref $object ? $object->availability : {});     
  
  $self->{'hub'} = $hub;
}

sub content {
  my $self = shift;
  my $tree = $self->tree;
  
  return unless $tree;
  
  my $caption = encode_entities($self->strip_HTML($self->caption));
  
  my $content = sprintf('
    %s
    <dl class="local_context %s">
      <dt>%s</dt>',
    $self->configuration ? '' : '<input type="hidden" class="panel_type" value="LocalContext" />',
    $self->class,
    encode_entities($caption)
  );
  
  my $active      = $self->active;
  my @nodes       = $tree->nodes;
  my $active_node = $tree->get_node($active) || $nodes[0];
  
  return "$content</dl>" unless $active_node;
  
  my $hub          = $self->{'hub'};
  my $active_l     = $active_node->left;
  my $active_r     = $active_node->right;
  my $counts       = $self->counts;
  my $all_params   = !!$hub->object_types->{$hub->type};
  my $r            = 0;
  my $previous_node;
  
  foreach my $node (@nodes) {
    my $no_show = 1 if $node->data->{'no_menu_entry'} || !$node->data->{'caption'};
    
    $r = $node->right if $node->right > $r;
    
    if ($previous_node && $node->left > $previous_node->right) {
      $content .= '</dl></dd>' for 1..$node->left - $previous_node->right - 1;
    }
    
    if (!$no_show) {
      my $title = $node->data->{'full_caption'};
      my $name  = $node->data->{'caption'};
      my $id    = $node->data->{'id'};
      
      $title ||= $name;
      
      if ($node->data->{'availability'} && $self->is_available($node->data->{'availability'})) {
        # $node->data->{'code'} contains action and function where required, so setting function to undef is fine.
        # If function is NOT set to undef and you are on a page with a function, the generated url could be wrong
        # e.g. on Location/Compara_Alignments/Image the url for Alignments (Text) will also be Location/Compara_Alignments/Image, rather than Location/Compara_Alignments
        my $external = $node->data->{'external'} ? ' rel="external"' : '';
        my $class    = $node->data->{'class'};
        my $url      = $node->data->{'url'} || $hub->url({ action => $node->data->{'code'}, function => undef }, undef, $all_params);
        $class = qq{ class="$class"} if $class;
        
        for ($title, $name) {
          s/\[\[counts::(\w+)\]\]/$counts->{$1}||0/eg;
          $_ = encode_entities($_);
        }
        
        $name = qq{<a href="$url" title="$title"$class$external>$name</a>};
      } else {
        $name =~ s/\(\[\[counts::(\w+)\]\]\)//eg;
        $name = sprintf '<span class="disabled" title="%s">%s</span>', $node->data->{'disabled'}, $name;
      }
      
      if ($node->is_leaf) {
        $content .= sprintf '<dd%s%s>%s</dd>', $id ? qq{ id="$id"} : '', $node->key eq $active ? ' class="active"' : '', $name;
      } else {
        $content .= sprintf '<dd class="open%s">%s<dl>', ($node->key eq $active ? ' active' : ''), $name;
      }
    }
    
    $previous_node = $node;
  }
  
  $content .= '</dl></dd>' for $previous_node->right + 1..$r;
  $content .= '</dl>';
  $content =~ s/\s*<dl>\s*<\/dl>//g;
  
  return $content;
}

1;
