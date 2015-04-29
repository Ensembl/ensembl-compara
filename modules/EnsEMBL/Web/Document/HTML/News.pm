=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::HTML::News;

### This module outputs news for a given Ensembl release

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::DBSQL::ProductionAdaptor;
use EnsEMBL::Web::DBSQL::ArchiveAdaptor;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;
  my $html;

  my $hub           = $self->hub;
  my $release_id    = $hub->param('id') || $hub->species_defs->ENSEMBL_VERSION;
  my $site_type     = $hub->species_defs->ENSEMBL_SITETYPE;
  my $species_name  = $hub->species ? $hub->species_defs->SPECIES_COMMON_NAME : '';

  $html .= sprintf('<h1>News for %s %s', $species_name, $self->news_header($hub, $release_id));
  $html .= '</h1>';

  ## Are we using static news content output from a script?
  my $file          = '/ssi/whatsnew.html';
  my $include       = EnsEMBL::Web::Controller::SSI::template_INCLUDE(undef, $file);

  if ($release_id == $hub->species_defs->ENSEMBL_VERSION && $include) {
    $html .= '<h2>Headlines</h2>'.$include;
  }

  my @news = $self->get_news($release_id);

  if (@news) {
  
    my $toc .= qq(<h2>News categories</h2>\n<ul>);
    my $full;

    foreach my $section (@news) {
    
      $toc .= sprintf '<li><a href="#%s">%s</a>', 
                  $section->{'header'}{'id'}, $section->{'header'}{'text'};
      $full .= sprintf '<h2 id="%s" class="news-category">%s</h2>', 
                          $section->{'header'}{'id'}, $section->{'header'}{'text'};

      if ($section->{'subsections'}) {
        $toc .= '<ul>';
        foreach my $subsection (@{$section->{'subsections'}}) {
          $toc .= sprintf '<li><a href="#%s">%s</a>', 
                  $subsection->{'header'}{'id'}, $subsection->{'header'}{'text'};
          $full .= sprintf '<h3 id="%s" class="news-subcategory">%s</h3>', 
                          $subsection->{'header'}{'id'}, $subsection->{'header'}{'text'};
          $full .= $self->_format_items($subsection->{'items'});
  
        }
        $toc .= '</ul>';
      }
      else {
        $full .= $self->_format_items($section->{'items'});
      }
      $toc .= '</li>';
    }
    $toc .= "</ul>\n\n";

    $html .= $toc.$full;
  }
  else {
    $html .= qq(<p>No news is currently available for release $release_id.</p>\n);
  }
  return $html;
}

sub _format_items {
  my ($self, $items) = @_;
  return unless scalar @{$items||[]};
  my $html;

  foreach my $item (@$items) {      
    my $header = $item->{'header'};
    $html .= sprintf('<div class="news-item"><h%s id="%s">%s%s</h%s>%s</div>', 
                              $header->{'level'}, $header->{'id'}, 
                              $header->{'text'}, $header->{'species'},
                              $header->{'level'}, $item->{'content'},
                    ); 
  }
  return $html;
}

sub get_news {
  my ($self, $release_id) = @_;
  my $hub           = $self->hub;
  my (@news, @changes);

  my $first_production = $hub->species_defs->get_config('MULTI', 'FIRST_PRODUCTION_RELEASE');

  if ($hub->species_defs->multidb->{'DATABASE_PRODUCTION'}{'NAME'} && $first_production && $release_id >= $first_production) {
    ## get news changes
    my $adaptor = EnsEMBL::Web::DBSQL::ProductionAdaptor->new($hub);
    if ($adaptor) {
      my $params = {'release' => $release_id};
      if ($hub->species) {
        $params->{'species'} = $hub->species;
        @changes = @{$adaptor->fetch_changelog($params)};
      }
      else {
        @changes = @{$adaptor->fetch_changelog($params)};
      }
    }

    ## Sort and dedupe records
    my ($sorted_cats, $sorted_teams, %seen, %ok_cats, %ok_teams);
    foreach (@changes) {
      if ($hub->species) {
        next if $seen{$_->{'id'}};
        next if ($_->{'team'} eq 'Variation' && !exists $hub->species_defs->databases->{'DATABASE_VARIATION'});
        next if ($_->{'team'} eq 'Funcgen' && !exists $hub->species_defs->databases->{'DATABASE_FUNCGEN'});
        $seen{$_->{'id'}}++;
      }
      ## We potentially need to sort by both category and team, depending
      ## on when the record was created
      $ok_cats{$_->{'category'}}++;
      if ($sorted_cats->{$_->{'category'}}) {
        push @{$sorted_cats->{$_->{'category'}}}, $_;
      }
      else {
        $sorted_cats->{$_->{'category'}} = [$_];
      }
      $ok_teams{$_->{'team'}}++;
      if ($sorted_teams->{$_->{'team'}}) {
        push @{$sorted_teams->{$_->{'team'}}}, $_;
      }
      else {
        $sorted_teams->{$_->{'team'}} = [$_];
      }
    }
    ## Now we can check if we have any categories beyond other!
    my $has_cats = scalar keys %ok_cats > 1 ? 1 : 0; 
    my %headers = $has_cats ? %ok_cats : %ok_teams;
    my $sorted = $has_cats ? $sorted_cats : $sorted_teams;

    if (scalar(@changes) > 0) {

      my @order = $has_cats ? qw(web genebuild variation regulation alignment schema retired other) : sort keys %ok_teams;
      my %cat_lookup = (
                      'web'         => 'New web displays and tools',
                      'genebuild'   => 'New species, assemblies and genebuilds',
                      'variation'   => 'New variation data',
                      'regulation'  => 'New regulation data',
                      'alignment'   => 'New alignments',
                      'schema'      => 'API and schema changes',
                      'retired'     => 'Retired data',
                      'other'       => 'Other updates',
                      );

      my %team_lookup = (
                        'Funcgen'   => 'Regulation',
                        );

      foreach my $header (@order) {
        next unless $headers{$header};
        my @records = @{$sorted->{$header}||[]};  
        next unless scalar @records;

        my $section = {};
        my $title   = $has_cats ? $cat_lookup{$header} : ucfirst($header);
        $section->{'header'} = {'id' => 'cat-'.$header, 'text' => $title};

        my $header_level;
        if ($has_cats && $header eq 'other') {
          $header_level = 4; 
          @records = sort {$a->{'team'} cmp $b->{'team'}} @records;
          $section->{'subsections'} = [];

          ## Compile subsections
          my $team_sections = {};
          foreach my $record (@records) {
            my $team = $record->{'team'};
            if (!$team_sections->{$team}) {
              my $team_name = $team_lookup{$team} || ucfirst($team);
              $team_sections->{$team} = {
                                        'header' => {'id' => 'team-'.$team, 'text' => $team_name}, 
                                        'items' => [],
                                      };
            }
            push @{$team_sections->{$team}{'items'}}, $self->_build_item($record, $header_level); 
          }

          ## Put subsections in correct order
          my @teams = sort keys %$sorted_teams;
          foreach my $team (@teams) {
            push @{$section->{'subsections'}}, $team_sections->{$team};
          }
        }
        else {
          $header_level = 3;
          foreach my $record (@records) {
            push @{$section->{'items'}}, $self->_build_item($record, $header_level); 
          }
        }
        push @news, $section;
      }
    }
  }
  return @news;
}
  
sub _build_item {
  my ($self, $record, $header_level) = @_;
  my $species_name  = $self->hub->species ? $self->hub->species_defs->SPECIES_COMMON_NAME : '';
  my $item;      
     
  $item->{'header'} = {
                      'level' => $header_level, 
                      'id'    => 'change_'.$record->{'id'}, 
                      'text' => $record->{'title'},
                      }; 

  my @species = @{$record->{'species'}}; 
  my $sp_text;
  
  if ($species_name && $species_name eq $species[0]->{'web_name'}) {
    $sp_text = '';
  }
  elsif (!@species || !$species[0]) {
    $sp_text = 'all species';
  }
  elsif (@species > 5) {
    $sp_text = 'multiple species';
  }
  else {
    my @names;
    foreach my $sp (@species) {
      if ($sp->{'web_name'} =~ /\./) {
        push @names, '<i>'.$sp->{'web_name'}.'</i>';
      }
      else {
        push @names, $sp->{'web_name'};
      }  
    }
    $sp_text = join(', ', @names);
  }
  $item->{'header'}{'species'} = " ($sp_text)" if $sp_text;
  $item->{'content'} = $record->{'content'};
  return $item;
}

1;
