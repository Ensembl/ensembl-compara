=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Info::Gallery;

### Site Gallery settings and methods

use strict;
use warnings;
no warnings 'uninitialized';

use parent qw(EnsEMBL::Web::Component::Shared);

our $data_type = {
                  'Gene'      => {'param'   => 'g',
                                  'term'    => 'gene',
                                  'label_1' => 'Choose a Gene',
                                  'label_2' => 'or choose another Gene',
                                  },
                  'Variation' => {'param'   => 'v',
                                  'term'    => 'variant',
                                  'label_1' => 'Choose a Variant',
                                  'label_2' => 'or choose another Variant',
                                  },
                  'Location'  => {'param'   => 'r',
                                  'term'    => 'region',
                                  'label_1' => 'Choose Coordinates',
                                  'label_2' => 'or choose different coordinates'
                                  },
                  };

sub format_gallery {
  my ($self, $type, $layout, $all_pages) = @_; 
  my $hub = $self->hub;

  return 'Gallery not implemented' unless $all_pages;

  my ($previews, @toc, %page_count);

  foreach my $group (@$layout) {
    my @pages = @{$group->{'pages'}||[]};
    next unless scalar @pages;

    ## Add this group to the navigation bar
    my $title = $group->{'title'};
    my $icon  = $group->{'icon'};
    push @toc, sprintf('<div class="gallery-nav">
                          <span class="ht _ht">
                            <span class="_ht_tip hidden">Jump to views associated with %s</span>
                            <img src="/i/48/%s" /><br />
                            <a href="#%s" class="notext gallery-navlabel">%s</a>
                          </span>
                        </div>', 
                          lc($title), $icon, lc($title), $title);

    $previews .= '<div class="gallery-group">';
    $previews .= $self->_sub_header($title);

    ## Template for each entry
    my $entry_template = '<div class="gallery-preview">
                            <div class="page-preview">%s</div>
                            <h3%s>%s</h3>
                              <p class="preview-caption">%s</p>
                              <p%s>%s</p>
                          </div>';

    ## Add individual views
    foreach (@pages) {
      my $page = $all_pages->{$_};
      next unless $page;

      ## Count unique pages
      $page_count{$page->{'link_to'}} = 1;

      my $url = $self->hub->url($page->{'link_to'});

      my $label = $self->hub->param('default') ? 'label_1' : 'label_2';

      my ($img_disabled, $img_title, $next_action);
      my $action_class  = '';
      my $link_class    = '';
      my $title_class   = '';
      my ($img_link, $multi_form);

      if ($page->{'disabled'}) {
        ## Disable views that are invalid for this feature
        $img_disabled = 1;
        $next_action = sprintf 'Sorry, this view is not available for this %s', lc($data_type->{$type}{'term'});
        if ($page->{'message'}) {
          $next_action .= ': '.$page->{'message'};
        }
        $img_title    = $next_action;
        $title_class  = ' class="disabled"';
      }
      elsif ($page->{'multi'}) {
        my $multi_type = $page->{'multi'}{'type'};
        ## Disable links on views that can't be mapped to a single feature/location
        my $data_param  = $page->{'multi'}{'param'};

        my $link_to = $page->{'link_to'};
        my $form_url  = sprintf('/%s/%s/%s', $self->hub->species, $link_to->{'type'}, $link_to->{'action'});

        $multi_form  = $self->new_form({'action' => $form_url, 'method' => 'post', 'class' => 'freeform'});
        
        my $header = sprintf('<p><b>This %s maps to multiple %s</b></p>', $data_type->{$type}{'term'}, lc($multi_type).'s');

        while (my($k, $v) = each (%{$hub->core_params})) {
          $v ||= $link_to->{$k};
          if ($v) {
            $multi_form->add_hidden({'name' => $k, 'value' => $v});
          }
        }

        my $field = $multi_form->add_field({
                                        'type'    => 'Dropdown',
                                        'name'    => $data_param,
                                        'values'  => $page->{'multi'}{'values'},
                                        });
        $field->add_element({'type' => 'submit', 'value' => 'Show me'}, 1);
        $next_action = $header.$multi_form->render;
      }
      else {
        $action_class = ' class = "button"';
        $next_action  = sprintf '<a href="%s">Show me</a>', $url;
        $img_link     = $url;
      }

      my $image;
      if ($img_disabled) {
        $image = sprintf '<img src="/i/gallery/%s.png" title="%s" class="disabled"/>', 
                            $page->{'img'};
      }
      elsif ($img_link) {
        $image = sprintf '<a href="%s"%s><img src="/i/gallery/%s.png" class="embiggen" /></a>', 
                          $img_link, $link_class, $page->{'img'};
      }
      elsif ($multi_form) {
        $image = sprintf '<img src="/i/gallery/%s.png" class="embiggen" /><div class="popup-form hide"><span class="close on"></span>%s</div>', 
                          $page->{'img'}, $next_action;
      }
      else {
        $image = sprintf '<img src="/i/gallery/%s.png" class="embiggen" /></a>', 
                          $page->{'img'};
      }

      $previews .= sprintf($entry_template, $image, $title_class, $_, 
                            $page->{'caption'}, $action_class, $next_action);

    }

    $previews .= '</div>';
  }

  my $page_header = sprintf('<h1>%s views for %s data</h1>', scalar keys %page_count, $hub->param('data_type'));

  my $toc_string = sprintf('<div id="gallery-toc" class="center">%s</div>', join(' ', @toc));

  return qq(
            <div class="gallery js_panel" id="site-gallery">
              <input type="hidden" class="panel_type" value="SiteGallery">
              $page_header
              $toc_string
              $previews
            </div>
  );
}

sub gene_name {
## This is basically the same as Object::Gene::short_caption
  my ($self, $gene) = @_;

  my $dxr  = $gene->can('display_xref') ? $gene->display_xref : undef;
  my $name = $dxr ? $dxr->display_id : ($gene->display_id || $gene->stable_id);

  return $name;
}

sub _sub_header {
  my ($self, $title) = @_;
  my $hub  = $self->hub;

  my $type  = $hub->param('data_type');
  my $param = $data_type->{$type}{'param'};
  my $value = $hub->param($param);
  my $label = sprintf '%s displays for', $title, $data_type->{$type}{'term'};

  my $form  = $self->new_form({'id' => lc($title), 'method' => 'get'});

  $form->add_hidden({
                    'name'  => 'data_type',
                    'value' => $type,
                    });

  $form->add_field({
                    'inline'    => 1,
                    'label'     => $label,
                    'elements'  => [
                          {
                            'type'    => 'String',
                            'name'  => $param,
                            'value' => $value,
                            },
                           {
                            'type'  => 'Submit',
                            'value' => 'Update',
                            },
                      ],
                    });

  return $form->render;
}


1;
