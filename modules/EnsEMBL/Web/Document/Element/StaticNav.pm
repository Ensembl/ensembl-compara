# $Id$

package EnsEMBL::Web::Document::Element::StaticNav;

# Container HTML for left sided navigation menu on static pages 

use strict;

use EnsEMBL::Web::Controller::SSI;
use HTML::TreeBuilder;
use HTML::Entities qw(encode_entities);
use URI::Escape    qw(uri_escape);

use base qw(EnsEMBL::Web::Document::Element::Navigation);

sub content {
  my $self = shift;
  my $html;

  ## LH MENU ------------------------------------------
  $html .= '<input type="hidden" class="panel_type" value="LocalContext" />
<div class="header">In this section</div>';

  $html .= '<ul class="local_context">';

  my $tree        = $self->species_defs->STATIC_INFO;
  my $here        = $ENV{'SCRIPT_NAME'};
  (my $pathstring = $here) =~ s/^\///; ## Remove leading slash
  my @path        = split '/', $pathstring;
  my $img_url     = $self->img_url;
  my $config      = $self->hub->session->get_data(type => 'nav', code => 'static') || {};

  ## Strip filename from current location - we just want directory
  (my $dir = $here) =~ s/^\/(.+\/)*(.+)\.(.+)$/$1/;
  
  ## Recurse into tree until you find current location
  my $this_tree = ($dir eq 'info/') ? $tree : $self->_walk_tree($tree, $dir, \@path, 1);

  my @pages = map { ref $this_tree->{$_} eq 'HASH' ? $_ : () } keys %$this_tree;
  my @page_order = sort {
    $this_tree->{$a}{'_order'} <=> $this_tree->{$b}{'_order'} ||
    $this_tree->{$a}{'_title'} cmp $this_tree->{$b}{'_title'} ||
    $this_tree->{$a}           cmp $this_tree->{$b}
  } @pages;

  my $last_page = $page_order[-1];
  foreach my $page (grep { !/^_/ && keys %{$this_tree->{$_}} } @page_order) {
    next unless $this_tree->{$page}{'_title'};

    my $url     = $this_tree->{$page}{'_path'};
    $url       .= $page if $page =~ /html$/;
    (my $id     = $url) =~ s/\//_/g;
    my $class   = $page eq $last_page ? 'last' : 'top_level';
    my $state   = $config->{$page};
    my $toggle  = $state ? 'closed' : 'open';
    my @children  = grep { !/^_/ } keys %{$this_tree->{$page}};
    my @child_order = sort {
      $this_tree->{$page}{$a}{'_order'} <=> $this_tree->{$page}{$b}{'_order'} ||
      $this_tree->{$page}{$a}{'_title'} cmp $this_tree->{$page}{$b}{'_title'} ||
      $this_tree->{$page}{$a}           cmp $this_tree->{$page}{$b}
    } @children;

    my $image = "${img_url}leaf.gif";
    my $submenu;
    if (scalar @children) {
      $class .= ' parent';
      my $last  = $child_order[-1];
      $submenu  = '<ul>';
  
      foreach my $child (@child_order) {
        my $info = $this_tree->{$page}{$child};
        next unless ref($info) eq 'HASH';
        next unless $info->{'_title'};
        my $class = $child eq $last ? ' class="last"' : '';

        $submenu .= sprintf('<li%s><img src="%s"><a href="%s%s">%s</a></li>', 
                              $class, $image, $url, $child, $info->{'_title'});
      }
      $submenu .= '</ul>';
      $image    = "$img_url$toggle.gif";
    }

    $html .= sprintf('<li class="%s"><img src="%s" class="toggle %s" alt=""><a href="%s"><b>%s</b></a>%s</li>', 
                        $class, $image, $id, $url, $this_tree->{$page}{'_title'}, $submenu); 
  }

  ## ----- IN-PAGE NAVIGATION ------------

  ## Read the current file and parse out h2 headings with ids
  my $content = EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, $here);
  my $doc = HTML::TreeBuilder->new_from_content(split('/\n/', $content));
  my @headers = $doc->find('h2');

  if (scalar(@headers)) {
    ## Check the headers have id attribs we can link to
    my @id_headers;
    foreach (@headers) {
      push @id_headers, $_ if $_->attr('id');
    }

    ## Create submenu from these headers
    if (scalar(@id_headers)) {
      $html .= '<div class="subheader">On this page</div>';
      $html .= '<ul class="local_context" style="border-width:0">';
      my $image = "${img_url}leaf.gif";

      my $i = 0;
      foreach (@id_headers) {
        my $class = ($i == $#id_headers) ? 'last' : 'top_level';
        $html .= sprintf('<li class="%s"><img src="%s"><a href="#%s">%s</a></li>', 
                          $class, $image, $_->attr('id'), $_->as_text);
        $i++;
      }

      $html .= '</ul>';
    }
  }

  ## SEARCH -------------------------------------------

  my $img_url         = $self->img_url;
  my $search_url      = sprintf '%s%s/psychic', $self->home_url, 'Multi';

  $html .= qq(
    <div id="doc_search">
      <form action="$search_url">
        <div class="print_hide">
          <div class="header">Search documentation:</div>
          <input type="text" name="se_q" />
          <input type="image" class="button" src="${img_url}16/search.png" alt="Search&nbsp;&raquo;" />
        </div>
      </form>
    </div>
  );

  return $html;
}

sub _walk_tree {
  my ($self, $tree, $here, $path, $level) = @_;

  my $current_path = join('/', @$path[0..$level]).'/';
  my $sub_tree = $tree->{$path->[$level]};

  if ($sub_tree) {
    if ($current_path eq $here) {
      return $sub_tree;
    }
    else {
      ## Recurse
      $self->_walk_tree($sub_tree, $here, $path, $level+1);
    }
  }
  else {
    return $tree;
  }

}

1;
