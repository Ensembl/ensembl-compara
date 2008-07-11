package EnsEMBL::Web::Document::HTML::DocsMenu;

### Generates "local context" menu for documentation (/info/)

use strict;
use EnsEMBL::Web::Document::HTML;
use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $sd = $ENSEMBL_WEB_REGISTRY->species_defs;

  my $tree = $sd->STATIC_INFO;

  my $html = qq(
<dl id="local">
<dt>Documentation</dt>
);

  my $title;

  my @sortable_sections;
  foreach my $section (keys %$tree) {
    push (@sortable_sections, $section) if ref($tree->{$section}) eq 'HASH';  
  }
  my @section_order = sort {
        $tree->{$a}{_order} <=> $tree->{$b}{_order}
        || $tree->{$a}{_title} cmp $tree->{$b}{_title}
        || $tree->{$a} cmp $tree->{$b}
    }
    @sortable_sections;
  
  foreach my $section (@section_order) {
    next if $section =~ /^_/;
    my $subsection = $tree->{$section};
    next unless keys %$subsection;
    $title = $subsection->{'_title'} || ucfirst($section);
    $html .= sprintf(qq(<dd class="open"><a href="%s">%s</a>),
        $subsection->{'_path'}, $title
    );
    my @sortable_subsections;
    foreach my $sub (keys %$subsection) {
      push (@sortable_subsections, $sub) if ref($subsection->{$sub}) eq 'HASH';  
    }

    if (scalar(@sortable_subsections)) { ## we have subpages/dirs, not just metadata
      my @sub_order = sort { 
        $subsection->{$a}{_order} <=> $subsection->{$b}{_order}
        || $subsection->{$a}{_title} cmp $subsection->{$b}{_title}
        || $subsection->{$a} cmp $subsection->{$b}
        } 
         @sortable_subsections;
      $html .= sprintf(qq(
        <dl>
      ), );
      foreach my $sub (@sub_order) {
        next if $sub =~ /^_/;
        my $pages = $subsection->{$sub};
        next unless keys %$pages;
        my $path = $pages->{'_path'} || $subsection->{'_path'}.$sub;
        $title = $pages->{'_title'} || ucfirst($sub);
        $html .= sprintf(qq(<dd><a href="%s">%s</a>),
            $path, $title
        );
        
      }
      $html .= qq(</dl>\n);
    }
    $html .= '</dd>';
  }
  
  $html .= '</dl>';
  return $html;
}

1;
