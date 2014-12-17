=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  my $adaptor       = EnsEMBL::Web::DBSQL::ArchiveAdaptor->new($hub);
  my $release       = $adaptor->fetch_release($release_id);
  my $release_date  = $release->{'date'};
  my $species_name  = $hub->species ? $hub->species_defs->SPECIES_COMMON_NAME : '';

  $html .= sprintf('<h1>%s News for %s Release %s', $site_type, $species_name, $release_id);
  $html .= sprintf(' (%s)', $release_date) if $release_date;
  $html .= '</h1>';

  ## Are we using static news content output from a script?
  my $file          = '/ssi/whatsnew.html';
  my $include       = EnsEMBL::Web::Controller::SSI::template_INCLUDE(undef, $file);

  if ($release_id == $hub->species_defs->ENSEMBL_VERSION && $include) {
    $html .= '<h2>Headlines</h2>'.$include;
  }

  my $first_production = $hub->species_defs->get_config('MULTI', 'FIRST_PRODUCTION_RELEASE');

  if ($hub->species_defs->multidb->{'DATABASE_PRODUCTION'}{'NAME'} && $first_production && $release_id > $first_production) {
    ## get news changes
    my $adaptor = EnsEMBL::Web::DBSQL::ProductionAdaptor->new($hub);
    my @changes = ();
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

      my $record;
      my @order = $has_cats ? qw(web genebuild variation regulation alignment schema other) : sort keys %ok_teams;
      my %cat_lookup = (
                      'web'         => 'New web displays and tools',
                      'genebuild'   => 'New species, assemblies and genebuilds',
                      'variation'   => 'New variation data',
                      'regulation'  => 'New regulation data',
                      'alignment'   => 'New alignments',
                      'schema'      => 'API and schema changes',
                      'other'       => 'Other updates',
                      );

      my %team_lookup = (
                        'Funcgen'   => 'Regulation',
                        );

      ## TOC
      $html .= qq(<h2>News categories</h2>
                <ul>\n);
      foreach my $header (@order) {
        next unless $headers{$header};
        my $title   = $has_cats ? $cat_lookup{$header} : ucfirst($header);
        $html .= sprintf '<li><a href="#cat-%s">%s</a>', $header, $title;
        if ($has_cats && $header eq 'other') {
          my @teams = sort keys %$sorted_teams;
          if (scalar @teams) {
            $html .= '<ul>';
            foreach my $team (@teams) {
              my $team_name = $team_lookup{$team} || ucfirst($team);
              $html .= sprintf '<li><a href="#team-%s">%s</a>', $team, $team_name;
            }
            $html .= '</ul>';
          }
        }
        $html .= '</li>';
      }
      $html .= "</ul>\n\n";

      ## format news changes
      foreach my $header (@order) {
        next unless $headers{$header};
        my @records = @{$sorted->{$header}||[]};  
        my $title   = $has_cats ? $cat_lookup{$header} : ucfirst($header);
        $html .= sprintf '<h2 id="cat-%s" class="news-category">%s</h2>', $header, $title;
        my $header_level = 3;
        if ($has_cats && $header eq 'other') {
          $header_level = 4; 
          @records = sort {$a->{'team'} cmp $b->{'team'}} @records;
        } 
        my $previous_team;
      
     
        foreach my $record (@records) {
          if ($has_cats && $header eq 'other') {
            my $team = $record->{'team'};
            if ($team && $team ne $previous_team) {
              my $team_name = $team_lookup{$team} || ucfirst($team);
              $html .= sprintf '<h3 id="team-%s" class="news-category">%s</h3>', $team, $team_name;
            }
            $previous_team = $team;
          }
          $html .= sprintf('<h%s id="change_%s">%s', $header_level, $record->{'id'}, $record->{'title'});

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
          $html .= " ($sp_text)" if $sp_text;
          $html .= "\n</h$header_level>\n";
          my $content = $record->{'content'};
          $html .= $content."\n\n";
        }
      }
    }
    else {
      $html .= qq(<p>No changelog is currently available for release $release_id.</p>\n);
    }
  }
  elsif ($hub->species_defs->multidb->{'DATABASE_WEBSITE'}{'NAME'}) {
    ## get news stories
    my $adaptor = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub);
    my @stories;

    if ($adaptor) {
      @stories = @{$adaptor->fetch_news({'release' => $release_id})};
    }

    if (scalar(@stories) > 0) {

      my $prev_cat = 0;
      ## format news stories
      foreach my $item (@stories) {

        ## is it a new category?
        if ($release_id < 59 && $prev_cat != $item->{'category_id'}) {
          $html .= "<h2>".$item->{'category_name'}."</h2>\n";
        }
        $html .= '<h3 id="news_'.$item->{'id'}.'">'.$item->{'title'};

        ## sort out species names
        my @species = @{$item->{'species'}};
        my $sp_text;

        if (!@species || !$species[0]) {
          $sp_text = 'all species';
        }
        elsif (@species > 5) {
          $sp_text = 'multiple species';
        }
        else { 
          my @names;
          foreach my $sp (@species) {
            next unless $sp->{'id'} > 0;
            if ($sp->{'common_name'} =~ /\./) { ## No common name, only Latin
              push @names, '<i>'.$sp->{'common_name'}.'</i>';
            }
            else {
              push @names, $sp->{'common_name'};
            }
          }
          $sp_text = join(', ', @names);
        }
        $html .= " ($sp_text)</h3>\n";
        my $content = $item->{'content'};
        if ($content !~ /^</) { ## wrap bare content in a <p> tag
          $content = "<p>$content</p>";
        }
        $html .= $content."\n\n";

        $prev_cat = $item->{'category_id'};
      }
    }
    else {
      $html .= qq(<p>No news is currently available for release $release_id.</p>\n);
    }
  }
  else {
    $html .= '<p>No news is available for this release</p>';
  }

  return $html;
}

1;
