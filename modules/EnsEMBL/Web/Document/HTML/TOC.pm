# $Id$

package EnsEMBL::Web::Document::HTML::TOC;

### Generates table of contents for documentation (/info/)

use strict;

use EnsEMBL::Web::RegObj;
use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self              = shift;
  my $tree              = $ENSEMBL_WEB_REGISTRY->species_defs->STATIC_INFO;
  (my $location         = $ENV{'SCRIPT_NAME'}) =~ s/index\.html$//;
  my @toplevel_sections = map { ref $tree->{$_} eq 'HASH' ? $_ : () } keys %$tree;
  my %html              = ( left => '', middle => '', right => '' );
  my $column            = 'left';  

  my @section_order = sort {
    $tree->{$a}{'_order'} <=> $tree->{$b}{'_order'} ||
    $tree->{$a}{'_title'} cmp $tree->{$b}{'_title'} ||
    $tree->{$a}           cmp $tree->{$b}
  } @toplevel_sections;
  
  foreach my $dir (grep { !/^_/ && keys %{$tree->{$_}} } @section_order) {
    my $section      = $tree->{$dir};
    if ($dir eq 'about') {
      $column = 'middle';
    }
    elsif ($dir eq 'docs') {
      $column = 'right';
    }
    
    my $title        = $section->{'_title'} || ucfirst $dir;
    my @second_level = @{$self->create_links($section, ' style="font-weight:bold"')};
    
    $html{$column} .= qq{<div class="plain-box" style="margin:0 0 2%;padding:2%"><h2 class="first">$title</h2>\n};
    
    if (scalar @second_level) {
      $html{$column} .= '<ul>';
  
      foreach my $entry (@second_level) {
        my $link = $entry->{'link'};

        ## One more level!
        my $subsection  = $entry->{'key'};
        my @third_level = @{$self->create_links($subsection)};
        
        if (scalar @third_level && $link !~ /eHive/ && $link !~ /webcode/) {
          $link .= '<ul>';
          $link .= "<li>$_->{'link'}</li>\n" for @third_level;
          $link .= '</ul>';
        }

        $html{$column} .= "<li>$link</li>\n";
      }      
      
      $html{$column} .= '</ul>';
    }
    
    $html{$column} .= '</div>';
  }
  
  $html{$_} = qq{<div class="threecol-$_ widepage">$html{$_}</div>} for grep $html{$_}, keys %html;
  
  return qq{<div style="width:100%">
              $html{'left'}
              $html{'middle'}
              $html{'right'}
            </div>};
}

sub create_links {
  my ($self, $level, $style) = @_;
  my $links = [];
    
  ## Do we have subpages/dirs, or just metadata?
  my @sublevel = map { ref $level->{$_} eq 'HASH' ? $_ : () } keys %$level;
    
  if (scalar @sublevel) {
    my @sub_order = sort { 
      $level->{$a}{'_order'} <=> $level->{$b}{'_order'} ||
      $level->{$a}{'_title'} cmp $level->{$b}{'_title'} ||
      $level->{$a}           cmp $level->{$b}
    } @sublevel;
    
    foreach my $sub (grep { !/^_/ && keys %{$level->{$_}} } @sub_order) {
      my $pages = $level->{$sub};
      my $path  = $pages->{'_path'} || "$level->{'_path'}$sub";
      my $title = $pages->{'_title'} || ucfirst $sub;
        
      push @$links, { key => $pages, link => qq(<a href="$path" title="$title"$style>$title</a>) };
    }
  }

  return $links;
}

1;
