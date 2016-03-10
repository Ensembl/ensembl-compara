=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Info;

use strict;
use warnings;

use EnsEMBL::Web::DBSQL::ArchiveAdaptor;

use parent qw(EnsEMBL::Web::Component::Shared);

sub assembly_dropdown {
  my $self              = shift;
  my $hub               = $self->hub;
  my $adaptor           = EnsEMBL::Web::DBSQL::ArchiveAdaptor->new($hub);
  my $species           = $hub->species;
  my $archives          = $adaptor->fetch_archives_by_species($species);
  my $species_defs      = $hub->species_defs;
  my $pre_species       = $species_defs->get_config('MULTI', 'PRE_SPECIES');
  my $done_assemblies   = { map { $_ => 1 } $species_defs->ASSEMBLY_NAME, $species_defs->ASSEMBLY_VERSION };

  my @assemblies;

  foreach my $version (reverse sort {$a <=> $b} keys %$archives) {

    my $archive           = $archives->{$version};
    my $archive_assembly  = $archive->{'version'};

    if (!$done_assemblies->{$archive_assembly}) {

      my $desc      = $archive->{'description'} || sprintf '(%s release %s)', $species_defs->ENSEMBL_SITETYPE, $version;
      my $subdomain = ((lc $archive->{'archive'}) =~ /^[a-z]{3}[0-9]{4}$/) ? lc $archive->{'archive'}.'.archive' : lc $archive->{'archive'};

      push @assemblies, {
        url      => sprintf('http://%s.ensembl.org/%s/', $subdomain, $species),
        assembly => $archive_assembly,
        release  => $desc,
      };

      $done_assemblies->{$archive_assembly} = 1;
    }
  }

  ## Don't link to pre site on archives, as it changes too often
  push @assemblies, { url => "http://pre.ensembl.org/$species/", assembly => $pre_species->{$species}[1], release => '(Ensembl pre)' } if ($pre_species->{$species} && $species_defs->ENSEMBL_SITETYPE !~ /archive/i);

  my $html = '';

  if (scalar @assemblies) {
    if (scalar @assemblies > 1) {
      $html .= qq(<form action="/$species/redirect" method="get"><select name="url">);
      $html .= qq(<option value="$_->{'url'}">$_->{'assembly'} $_->{'release'}</option>) for @assemblies;
      $html .= '</select> <input type="submit" name="submit" class="fbutton" value="Go" /></form>';
    } else {
      $html .= qq(<ul><li><a href="$assemblies[0]{'url'}" class="nodeco">$assemblies[0]{'assembly'}</a> $assemblies[0]{'release'}</li></ul>);
    }
  }

  return $html;
}


### Site Gallery settings and methods

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
                                  'term'    => 'location',
                                  'label_1' => 'Choose Coordinates',
                                  'label_2' => 'or choose different coordinates'
                                  },
                  };

our $header_info = { 
  'Variation' => {'param' => 'v', 'term' => 'variant'},
};

sub format_gallery {
  my ($self, $type, $layout, $all_pages) = @_; 
  my ($html, @toc);
  my $hub = $self->hub;

  return unless $all_pages;

  foreach my $group (@$layout) {
    my @pages = @{$group->{'pages'}||[]};
    #next unless scalar @pages;

    my $title = $group->{'title'};
    my $icon  = $group->{'icon'};
    push @toc, sprintf('<a href="#%s"><img src="/i/48/%s" class="alongside" /></a><a href="#%s" class="notext">%s</a>', lc($title), $icon, lc($title), $title);

    $html .= $self->_sub_header($title);

    $html .= '<div class="gallery">';

    foreach (@pages) {
      my $page = $all_pages->{$_};
      next unless $page;
      my $url = $self->hub->url($page->{'link_to'});

      $html .= '<div class="gallery_preview">';

      my $label = $self->hub->param('default') ? 'label_1' : 'label_2';

      if ($page->{'disabled'}) {
        ## Disable views that are invalid for this feature
        $html .= sprintf('<img src="/i/gallery/%s.png" class="disabled" /></a>', $page->{'img'});
        $html .= sprintf('<div class="preview_caption">%s<br />[Not available for this %s]</div><br />', $page->{'caption'}, lc($header_info->{$type}{'term'}));
      }
      elsif ($page->{'multi'}) {
        my $image = sprintf('<img src="/i/gallery/%s.png" /></a>', $page->{'img'});
        my $multi_type = $page->{'multi'}{'type'};
        if ($page->{'multi'}{'zmenu'}) {
          ## Link to a zmenu of features
          my $params = $page->{'multi'}{'zmenu'};
          ## Also pass the parameters for the page we want the zmenu to link to
          while (my($k, $v) = each(%{$page->{'link_to'}})) {
            $params->{"link_$k"} = $v;
          }
          my $zmenu_link  = $self->hub->url($params);
          $html .= sprintf('<a href="%s" class="_zmenu">%s</a>', $zmenu_link, $image);
          $html .= sprintf('<div class="preview_caption">%s<br /><br />This %s maps to <a href="%s" class="_zmenu">multiple %s</a></div><br />', $page->{'caption'}, $data_type->{$type}{'term'}, $zmenu_link, lc($multi_type).'s');
        }
        else {
          ## Disable links on views that can't be mapped to a single feature/location
          $html .= $image;
          my $data_param  = $page->{'multi'}{'param'};
          $html .= sprintf('<div class="preview_caption">%s<br /><br />This %s maps to multiple %s</div><br />', $page->{'caption'}, $data_type->{$type}{'term'}, lc($multi_type).'s');

          my $link_to = $page->{'link_to'};
          my $form_url  = sprintf('/%s/%s/%s', $self->hub->species, $link_to->{'type'}, $link_to->{'action'});

          my $multi_form  = $self->new_form({'action' => $form_url, 'method' => 'post', 'class' => 'freeform'});
          while (my($k, $v) = each (%{$hub->core_params})) {
            if ($v) {
              $multi_form->add_hidden({'name' => $k, 'value' => $v});
            }
          }

          my $field          = $multi_form->add_field({
                                        'type'    => 'Dropdown',
                                        'name'    => $data_param,
                                        'values'  => $page->{'multi'}{'values'},
                                        });
          $field->add_element({'type' => 'submit', 'value' => 'Go'}, 1);
          $html .= $multi_form->render;
        }
      }
      else {
        $html .= sprintf('<a href="%s"><img src="/i/gallery/%s.png" /></a>', $url, $page->{'img'});
        $html .= sprintf('<div class="preview_caption"><a href="%s" class="nodeco">%s</a></div><br />', $url, $page->{'caption'});

      }

      my $form = $self->new_form({'action' => $url, 'method' => 'post', 'class' => 'freeform'});

      my $data_param = $data_type->{$type}{'param'};
      my $value           = $self->hub->param('default') ? $self->hub->param($data_param) : undef;
      my $field      = $form->add_field({
                                        'type'  => 'String',
                                        'size'  => 10,
                                        'name'  => $data_param,
                                        'label' => $data_type->{$type}{$label},
                                        'value' => $value,
                                        });

      $field->add_element({'type' => 'submit', 'value' => 'Go'}, 1);

      $html .= '<div class="gallery_preview preview_caption">'.$form->render.'</div>';

      $html .= '</div>';
    }

    $html .= '</div>';
  }
  my $toc_string = sprintf('<p class="center">%s</p>', join(' &middot; &middot; &middot; ', @toc));

  return $toc_string.$html;
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
  my $html;

  my $text  = ($hub->param('default') && $hub->param('default') eq 'yes') 
                ? 'example' : 'your chosen';
  my $type  = $hub->param('data_type');
  my $param = $hub->param($header_info->{$type}{'param'});
  my $term  = $header_info->{$type}{'term'};

  $html .= sprintf('<h2 id="%s" class="space-above">%s for %s %s: %s</h2>', lc($title), $title,
                                                          $text, $term, $param);

  return $html;
}


1;
