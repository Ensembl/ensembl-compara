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

package EnsEMBL::Web::Document::Element::StaticNav;

# Container HTML for left sided navigation menu on static pages 

use strict;

use HTML::TreeBuilder;

use EnsEMBL::Web::Controller::SSI;
use EnsEMBL::Web::Form;

use base qw(EnsEMBL::Web::Document::Element::Navigation);

sub content {
  my $self = shift;
  
  ## LH MENU ------------------------------------------
  
  my $tree        = $self->species_defs->STATIC_INFO;
  my $here        = $ENV{'SCRIPT_NAME'};
  (my $pathstring = $here) =~ s/^\///; ## Remove leading slash
  my @path        = split '/', $pathstring;
  my $img_url     = $self->img_url;
  my $config      = $self->hub->session->get_record_data({type => 'nav', code => 'static'});
  my $dir         = $here =~ s/^\/(.+\/)*(.+)\.(.+)$/$1/r;                                 ## Strip filename from current location - we just want directory
  my $this_tree   = $dir eq 'info/' ? $tree : $self->walk_tree($tree, $dir, \@path, 1);    ## Recurse into tree until you find current location
  my @pages       = map { ref $this_tree->{$_} eq 'HASH' ? $_ : () } keys %$this_tree;
  my @page_order  = sort {
    $this_tree->{$a}{'_order'}      <=> $this_tree->{$b}{'_order'} ||
    (lc $this_tree->{$a}{'_title'}) cmp (lc $this_tree->{$b}{'_title'}) ||
    (lc $this_tree->{$a})           cmp (lc $this_tree->{$b})
  } @pages;
  
  my $last_page = $page_order[-1];
  my ($menu, $in_page, $related, $search);
  
  foreach my $page (grep { !/^_/ && keys %{$this_tree->{$_}} } @page_order) {
    my $page_tree = $this_tree->{$page};
    
    next unless $page_tree->{'_title'};
    
    my $url         = $page_tree->{'_path'};
       $url        .= $page if $page =~ /html$/;
    (my $id         = $url) =~ s/\//_/g;
    my $class       = $page eq $last_page ? 'last' : 'top_level';
    my $state       = $config->{$page};
    my $toggle      = $state ? 'closed' : 'open';
    my $image       = "${img_url}leaf.gif";
    my @children    = grep !/^_/, keys %$page_tree;
    my @child_order = sort {
      $page_tree->{$a}{'_order'}      <=> $page_tree->{$b}{'_order'} ||
      (lc $page_tree->{$a}{'_title'}) cmp (lc $page_tree->{$b}{'_title'}) ||
      (lc $page_tree->{$a})           cmp (lc $page_tree->{$b})
    } @children;
    
    my $submenu;
    
    if (scalar @children) {
      my $last   = $child_order[-1];
        $class  .= ' parent';
        $submenu = '<ul>';
      
      foreach my $child (@child_order) {
        next unless ref $page_tree->{$child} eq 'HASH' && $page_tree->{$child}{'_title'};
        my $child_url = $url.$child; #$page_tree->{$child}{'_path'};
        $child_url .= '/' unless $child =~ /html$/;
        $submenu .= sprintf '<li%s><img src="%s"><a href="%s" title="%s">%s</a></li>', 
                        $child eq $last ? ' class="last"' : '', 
                        $image, 
                        $child_url, 
                        $page_tree->{$child}{'_title'}, 
                        $page_tree->{$child}{'_title'};
      }
      
      $submenu .= '</ul>';
      $image    = "$img_url$toggle.gif";
    }
    
    $menu .= qq{<li class="$class"><img src="$image" class="toggle $id" alt=""><a href="$url"><b>$page_tree->{'_title'}</b></a>$submenu</li>}; 
  }
  
  ## ----- IN-PAGE NAVIGATION ------------

  ## Read the current file and parse out h2 headings with ids
  my $content    = EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, $here);
  my $doc        = HTML::TreeBuilder->new_from_content($content);
  my @headers    = $doc->find('h2');
  my @id_headers = grep $_->attr('id'), @headers; ## Check the headers have id attribs we can link to
  
  ## Create submenu from these headers
  if (scalar @id_headers) {
    my $last = $id_headers[-1];
    
    $in_page .= sprintf('
      <div class="subheader">On this page</div>
      <ul class="local_context" style="border-width:0">
        %s
      </ul>',
      join('', map sprintf('<li class="%s"><img src="%sleaf.gif"><a href="#%s">%s</a></li>', $_ eq $last ? 'last' : 'top_level', $img_url, $_->attr('id'), $_->as_text), @id_headers)
    );
  }
  
  ## OPTIONAL 'RELATED CONTENT' SECTION ---------------
  
  if ($this_tree->{'_rel'}) {
    my $content = EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, $this_tree->{'_rel'});
    
    if ($content) {
      my @links = split '\n', $content;
      my $last  = $links[-1];
      
      $related .= sprintf('
        <div class="subheader">Related content</div>
        <ul class="local_context" style="border-width:0">
          %s
        </ul>',
        join('', map sprintf('<li class="%s"><img src="%sleaf.gif">%s</li>', $_ eq $last ? 'last' : 'top_level', $img_url, $_), @links)
      );
    }
  }
  
  ## SEARCH -------------------------------------------
  
  if ($self->species_defs->ENSEMBL_SOLR_ENDPOINT && $ENV{'HTTP_USER_AGENT'} !~ /Sanger Search Bot/) {
    my $search_url          = $self->species_defs->ENSEMBL_WEB_ROOT . 'Multi/Psychic';
    my $default_search_code = $self->species_defs->ENSEMBL_DEFAULT_SEARCHCODE;
    my $form                = EnsEMBL::Web::Form->new({ action => $search_url, method => 'get', skip_validation => 1, class => [ 'search-form', 'clear' ] });
    
    $form->add_hidden({ name => 'site',               value => $default_search_code });
    $form->add_hidden({ name => 'facet_feature_type', value => 'Documentation'      });

    # search input box and submit button
    my $field = $form->add_field({
      inline   => 1,
      elements => [{
        type       => 'string',
        value      => 'Search documentation&#8230;',
        is_encoded => 1,
        id         => 'q',
        size       => '20',
        name       => 'q',
        class      => [ 'query', 'input', 'inactive' ]
      }, {
        type  => 'submit',
        value => 'Go'
      }]
    });
    
    $search = sprintf('
      <div class="js_panel" style="margin:16px 0 0 8px">
        <input type="hidden" class="panel_type" value="SearchBox" />
        %s
      </div>
    ', $form->render);
  }

  return qq{
    <input type="hidden" class="panel_type" value="LocalContext" />
    <div class="header">In this section</div>
    <ul class="local_context">
      $menu
    </ul>
    $in_page
    $related
    $search
  };
}

sub walk_tree {
  my ($self, $tree, $here, $path, $level) = @_;
  my $current_path = join('/', @$path[0..$level]) . '/';
  my $sub_tree     = $tree->{$path->[$level]};

  if ($sub_tree) {
    return $sub_tree if $current_path eq $here;
    
    $self->walk_tree($sub_tree, $here, $path, $level + 1); ## Recurse
  } else {
    return $tree;
  }
}

1;
