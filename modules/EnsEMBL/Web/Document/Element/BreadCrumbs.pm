# $Id$

package EnsEMBL::Web::Document::Element::BreadCrumbs;

use strict;

use base qw(EnsEMBL::Web::Document::Element);

# Package to generate breadcrumb links 

sub title {
  my $self = shift;
  $self->{'title'} = shift if @_;
  return $self->{'title'};
}

sub content {
  my $self        = shift;
  my $home        = $self->species_defs->ENSEMBL_BASE_URL;
  my $tree        = $self->species_defs->STATIC_INFO;
  ## Remove leading slash
  (my $pathstring  = $ENV{'SCRIPT_NAME'}) =~ s/^\///;
  my @path        = split('/', $pathstring);
  my @breadcrumbs = qq(<a class="home" href="$home">Home</a>);

  if ($path[0] eq 'info') {
    ## Recurse into tree
    my $html;
    my $current_path = '/info/';
    my $subtree = $tree->{$path[1]};

    ## Top level link
    if ($path[1] eq 'index.html') {
      push @breadcrumbs, $tree->{'_title'};
    }
    else {
      push @breadcrumbs, sprintf '<a href="%s">%s</a>', $current_path, $tree->{'_title'};
    }

    for (my $i = 1; $i < scalar(@path); $i++ ) {
      $current_path .= $path[$i];
      if ($path[$i] !~ /html$/) {
        $current_path .= '/';
      }
      my $next = $self->_create_link($subtree, $path[$i+1], $current_path);
      $subtree = $next->{'subtree'};
      push @breadcrumbs, $next->{'link'} if $next->{'link'};
    }

    my $last = pop @breadcrumbs;

    $html = '<ul class="breadcrumbs print_hide">';
    if (@breadcrumbs) {
      $html .= join '', map "<li>$_</li>", @breadcrumbs;
    }
    $html .= qq(<li class="last">$last</li></ul>);
    return $html;  
  }
}

sub init {
  my ($self, $controller) = @_;
  $self->title($controller->content =~ /<title>(.*?)<\/title>/sm ? $1 : 'Untitled: ' . $controller->r->uri) if $controller->request eq 'ssi';
}

sub _create_link {
  my ($self, $subtree, $child, $path) = @_;
  my ($link, $childtree);

  my $title = $subtree->{'_title'};
  my $url   = $subtree->{'_path'};
  if ($child) {
    if ($subtree->{'_show'}) {
      if ($path =~ /\.html/) {
        $link = $title;
      }
      else {
        $link = qq(<a href="$path" title="$title">$title</a>);
      }
    }
    $childtree = $subtree->{$child};
  }
  else {
    $link = $title;
  }

  return {'link' => $link, 'subtree' => $childtree};
}

1;
