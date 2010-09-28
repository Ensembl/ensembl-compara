# $Id$

package EnsEMBL::Web::Document::Element::DocsMenu;

### Generates navigation menu for documentation (/info/)

use strict;

sub content {
  my $self              = shift;
  my $tree              = $self->species_defs->STATIC_INFO;
  (my $location         = $ENV{'SCRIPT_NAME'}) =~ s/index\.html$//;
  my @sortable_sections = map { ref $tree->{$_} eq 'HASH' ? $_ : () } keys %$tree;
  my ($title, $class, $menu, $page_count);
  
  my @section_order = sort {
    $tree->{$a}{'_order'} <=> $tree->{$b}{'_order'} ||
    $tree->{$a}{'_title'} cmp $tree->{$b}{'_title'} ||
    $tree->{$a} cmp $tree->{$b}
  } @sortable_sections;
  
  foreach my $section (grep { !/^_/ && keys %{$tree->{$_}} } @section_order) {
    my $subsection = $tree->{$section};
    $class         = $location eq $subsection->{'_path'} ? ' class="active"' : '';
    $title         = $subsection->{'_title'} || ucfirst $section;
    
    if ($subsection->{'_nolink'}) {
      $menu .= qq{<dd class="open"><strong>$title</strong>};
    } else {
      $menu .= qq{<dd class="open"><strong><a href="$subsection->{'_path'}" title="$title"$class>$title</a></strong>};
    }
    
    $page_count++;
    
    next if $subsection->{'_no_follow'};
    
    my @sortable_subsections = map { ref $subsection->{$_} eq 'HASH' ? $_ : () } keys %$subsection;
    
    ## we have subpages/dirs, not just metadata
    if (scalar @sortable_subsections) {
      my @sub_order = sort { 
        $subsection->{$a}{'_order'} <=> $subsection->{$b}{'_order'} ||
        $subsection->{$a}{'_title'} cmp $subsection->{$b}{'_title'} ||
        $subsection->{$a} cmp $subsection->{$b}
      } @sortable_subsections;
         
      $menu .= '<dl>';
      
      foreach my $sub (grep { !/^_/ && keys %{$subsection->{$_}} } @sub_order) {
        my $pages = $subsection->{$sub};
        my $path  = $pages->{'_path'} || "$subsection->{'_path'}$sub";
        $class    = $location eq $path ? ' class="active"' : '';
        $title    = $pages->{'_title'} || ucfirst $sub;
        
        $menu .= qq{<dd><a href="$path" title="$title"$class>$title</a></dd>};
        
        $page_count++;
      }
      
      $menu .= '</dl>';
    }
    
    $menu .= '</dd>';
  }
  
  return sprintf(qq{
    <input type="hidden" class="panel_type" value="LocalContext" />
    <dl class="local_context">
      <dt>Help &amp; Documentation</dt>
      %s
      $menu
    </dl>
  }, $page_count > 5 ? '<dd><a href="/info/">Alphabetical List of Pages</a></dd>' : '');
}

1;
