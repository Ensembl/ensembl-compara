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

package EnsEMBL::Web::Document::HTML::NewsByTopic;

### This module outputs news for a given category

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::DBSQL::ProductionAdaptor;
use EnsEMBL::Web::DBSQL::ArchiveAdaptor;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;
  my $hub           = $self->hub;
  my $html;

  my $site_type     = $hub->species_defs->ENSEMBL_SITETYPE;

  if ($hub->species_defs->multidb->{'DATABASE_PRODUCTION'}{'NAME'}) {
    my $cat = $hub->param('topic');
    my %cat_lookup = (
                      'web'         => 'Web',
                      'genebuild'   => 'Assembly and Genebuild',
                      'variation'   => 'Variation',
                      'regulation'  => 'Regulation',
                      'alignment'   => 'Comparative Genomics',
                      'schema'      => 'API and schema',
                      );
    ## Also map teams to topics, to ensure we catch all relevant items
    my %team_lookup = (
                      'web'         => 'Web',
                      'genebuild'   => 'Genebuild',
                      'variation'   => 'Variation',
                      'regulation'  => 'Funcgen',
                      'alignment'   => 'Compara',
                      'schema'      => 'Core',
                      );
    ## TOC
    my $div = $cat ? '<div class="tinted-box float-right">' : '';
    my $adj = $cat ? 'Other news' : 'News'; 
    $html .= qq($div<h2>$adj categories</h2>
            <ul>\n);
    my @order = qw(web genebuild variation regulation alignment schema);
    foreach (@order) {
      next if $_ eq $cat;
      my $title   = $cat_lookup{$_};
      my $url = $hub->url({'topic' => $_});
      $html .= sprintf '<li><a href="%s">%s</a></li>', $url, $title;
    }
    $html .= "</ul>";
    $html .= "</div>\n\n" if $div;

    if ($cat) {
      $html .= sprintf('<h1>%s %s News</h1>', $site_type, $cat_lookup{$cat});
      my $adaptor = EnsEMBL::Web::DBSQL::ProductionAdaptor->new($hub);

      ## News items
      my @changes = @{$adaptor->fetch_changelog({'category' => $cat, 'team' => $team_lookup{$cat}}, 'site_type' => 'all')};
      my (%seen, @ok_changes);
      
      ## Dedupe records
      foreach (@changes) {
        if ($hub->species) {
          next if $seen{$_->{'id'}};
          next if ($cat eq 'variation' && !exists $hub->species_defs->databases->{'DATABASE_VARIATION'});
          next if ($cat eq 'regulation' && !exists $hub->species_defs->databases->{'DATABASE_FUNCGEN'});
          $seen{$_->{'id'}}++;
        }
        push @ok_changes, $_;
      }
      
      if (scalar(@ok_changes) > 0) {

        my $record;

        my $this_release; 
        foreach my $record (@ok_changes) {
          if (!$this_release || ($record->{'release'} != $this_release)) {
            $html .= sprintf('<h2>Release %s</h2>', $record->{'release'});
          }
          $this_release = $record->{'release'};
          $html .= '<h3 id="change_'.$record->{'id'}.'">'.$record->{'title'};
          my @species = @{$record->{'species'}}; 
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
              if ($sp->{'web_name'} =~ /\./) {
                push @names, '<i>'.$sp->{'web_name'}.'</i>';
              }
              else {
                push @names, $sp->{'web_name'};
              }  
            }
            $sp_text = join(', ', @names);
          }
          $html .= " ($sp_text)";
          my $site = $record->{'site_type'};
          $html .= sprintf(' - %s.ensembl.org', $site) if $site ne 'ensembl';
          $html .= "</h3>\n";
          my $content = $record->{'content'};
          $html .= $content."\n\n";
        }
      }
    }
  }
  else {
    $html = "<p>Sorry, this view is not available in $site_type.</p>";
  }

  return $html;
}

1;
