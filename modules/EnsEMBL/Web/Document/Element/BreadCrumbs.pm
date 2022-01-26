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

package EnsEMBL::Web::Document::Element::BreadCrumbs;

### Package to generate breadcrumb links

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Document::Element); 

sub init {
  my ($self, $controller) = @_;
  $self->title($controller->content =~ /<title>(.*?)<\/title>/sm ? $1 : 'Untitled: ' . $controller->r->uri) if $controller->request eq 'ssi';
}

sub title {
  my $self = shift;
  $self->{'title'} = shift if @_;
  return $self->{'title'};
}

sub content {
  my $self        = shift;
  my $home        = $self->species_defs->ENSEMBL_BASE_URL;
  my $tree        = $self->species_defs->STATIC_INFO;
  (my $pathstring = $ENV{'SCRIPT_NAME'}) =~ s/^\///; ## Remove leading slash
  my @path        = split '/', $pathstring;
  my @breadcrumbs = qq{<a class="home" href="$home">Home</a>};

  if ($path[0] eq 'info') {
    ## Recurse into tree
    my $current_path = '/info/';
    my $subtree      = $tree->{$path[1]};
    
    ## Top level link
    if ($path[1] eq 'index.html') {
      push @breadcrumbs, encode_entities($tree->{'_title'});
    } else {
      push @breadcrumbs, sprintf '<a href="%s">%s</a>', $current_path, encode_entities($tree->{'_title'});
    }

    for (my $i = 1; $i < scalar @path; $i++) {
      $current_path .= $path[$i];
      $current_path .= '/' if $path[$i] !~ /html$/;
      
      my $next = $self->create_link($subtree, $path[$i+1], $current_path);
      $subtree = $next->{'subtree'};
      
      push @breadcrumbs, $next->{'link'} if $next->{'link'};
    }

    my $last = pop @breadcrumbs;
    my $html = '<ul class="breadcrumbs print_hide">';
    $html   .= join '', map "<li>$_</li>", @breadcrumbs;
    $html   .= qq{<li class="last">$last</li></ul>};
    
    return $html;  
  }
}

sub create_link {
  my ($self, $subtree, $child, $path) = @_;
  my $title = $subtree->{'_title'};
  my $url   = $subtree->{'_path'};
  my ($link, $childtree);
  
  if ($child) {
    $link      = $path =~ /\.html/ ? $title : qq{<a href="$path" title="$title">$title</a>} if $subtree->{'_show'} eq 'y';
    $childtree = $subtree->{$child};
  } else {
    $link = $title;
  }

  return { link => $link, subtree => $childtree };
}

1;
