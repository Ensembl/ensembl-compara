package EnsEMBL::Web::Document::HTML::TOC;

### Generates table of contents for documentation (/info/)

use strict;

use EnsEMBL::Web::RegObj;
use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;

  my $tree = $ENSEMBL_WEB_REGISTRY->species_defs->STATIC_INFO;
  (my $location         = $ENV{'SCRIPT_NAME'}) =~ s/index\.html$//;
  my @toplevel_sections = map { ref $tree->{$_} eq 'HASH' ? $_ : () } keys %$tree;
  my $html;
  my $first_header = 1;
  
  my @section_order = sort {
    $tree->{$a}{'_order'} <=> $tree->{$b}{'_order'} ||
    $tree->{$a}{'_title'} cmp $tree->{$b}{'_title'} ||
    $tree->{$a} cmp $tree->{$b}
  } @toplevel_sections;
  
  my $count = 0;
  foreach my $dir (grep { !/^_/ && keys %{$tree->{$_}} } @section_order) {
    my $section   = $tree->{$dir};
    my $side      = $dir eq 'docs' ? 'right' : 'left';
    my $title     = $section->{'_title'} || ucfirst $dir;
    $html .= qq{<div class="twocol-$side plain-box"><h2 class="first">$title</h2>};
    $first_header = 0;

    my @second_level = @{$self->_create_links($section, ' style="font-weight:bold"')};
    if (scalar @second_level) {
      $html .= '<ul>';
  
      foreach my $entry (@second_level) {
      
        my $link  = $entry->{'link'};
        $html .= '<li>'.$link;

        ## One more level!
        my $subsection = $entry->{'key'};
        my @third_level = @{$self->_create_links($subsection)};
        if (scalar @third_level) {
          $html .= '<ul>';
          foreach my $subentry (@third_level) {
            my $sublink  = $subentry->{'link'};
            $html .= qq{<li>$sublink</li>};
          }
          $html .= '</ul>';
        }

        $html .= '</li>';
      }      
      
      $html .= '</ul>';
    }
    $html .= '</div>';
    $count++;  
  }
   
  return $html;
}

sub _create_links {
  my ($self, $level, $style) = @_;
  my $links = [];
    
  ## Do we have subpages/dirs, or just metadata?
  my @sublevel = map { ref $level->{$_} eq 'HASH' ? $_ : () } keys %$level;
    
  if (scalar @sublevel) {
    my @sub_order = sort { 
        $level->{$a}{'_order'} <=> $level->{$b}{'_order'} ||
        $level->{$a}{'_title'} cmp $level->{$b}{'_title'} ||
        $level->{$a} cmp $level->{$b}
      } @sublevel;

    foreach my $sub (grep { !/^_/ && keys %{$level->{$_}} } @sub_order) {
      my $pages = $level->{$sub};
      my $path  = $pages->{'_path'} || "$level->{'_path'}$sub";
      my $title = $pages->{'_title'} || ucfirst $sub;
        
      push @$links, {'key' => $pages, 'link' => qq(<a href="$path" title="$title"$style>$title</a>)};
    }
  }

  return $links;
}

1;
