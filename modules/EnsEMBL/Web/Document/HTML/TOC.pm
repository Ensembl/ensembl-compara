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

package EnsEMBL::Web::Document::HTML::TOC;

### Generates table of contents for documentation (/info/)

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

# So it can be overridden in plugins
sub heading_html {
  my ($self,$dir,$title) = @_;

  return qq{<div class="plain-box"><h2 class="box-header"><a href="/info/$dir/">$title</a></h2>\n};
}

sub render {
  my $self              = shift;
  my $tree              = $self->hub->species_defs->STATIC_INFO;
  (my $location         = $ENV{'SCRIPT_NAME'}) =~ s/index\.html$//;
  my @toplevel_sections = map { ref $tree->{$_} eq 'HASH' ? $_ : () } keys %$tree;
  my %html              = ( left => '', middle => '', right => '' );

  my @section_order = sort {
    $tree->{$a}{'_order'} <=> $tree->{$b}{'_order'} ||
    $tree->{$a}{'_title'} cmp $tree->{$b}{'_title'} ||
    $tree->{$a}           cmp $tree->{$b}
  } @toplevel_sections;
  
  foreach my $dir (grep { !/^_/ && keys %{$tree->{$_}} } @section_order) {
    next if $dir eq 'sitemap.html';
    my $column      = 'left';  
    my $section     = $tree->{$dir};
    if ($dir eq 'genome') {
      $column = 'middle';
    }
    elsif ($dir eq 'docs' || $dir eq 'data') {
      $column = 'right';
    }
    
    my $title        = $section->{'_title'} || ucfirst $dir;
    my @second_level = @{$self->create_links($section, ' class="bold"')};

    $html{$column} .= $self->heading_html($dir,$title);
 
    if (scalar @second_level) {
      $html{$column} .= '<ul>';
  
      foreach my $entry (@second_level) {
        my $link = $entry->{'link'};

        ## One more level!
        my $subsection  = $entry->{'key'};
        my @third_level = @{$self->create_links($subsection)};
        
        if (scalar @third_level) {
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

  $html{$_} = sprintf(q(<div class="column-three"><div class="column-padding%s">%s</div></div>), $_ eq 'middle' ? '' : " no-$_-margin", $html{$_}) for grep $html{$_}, keys %html; # no-left-margin, no-right-margin

  return qq(<div class="column-wrapper">
              $html{'left'}
              $html{'middle'}
              $html{'right'}
            </div>);
}

sub create_links {
  my ($self, $level, $attribs) = @_;
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
        
      push @$links, { key => $pages, link => qq(<a href="$path" title="$title"$attribs>$title</a>) };
    }
  }

  return $links;
}

1;
