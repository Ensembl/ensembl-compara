package EnsEMBL::Web::Document::HTML::News;

### This module outputs news for previous Ensembl releases 

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Hub;
use EnsEMBL::Web::DBSQL::ProductionAdaptor;
use EnsEMBL::Web::DBSQL::WebsiteAdaptor;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;
  my $html;

  my $hub = new EnsEMBL::Web::Hub;
  my $release_id = $hub->param('id') || $hub->species_defs->ENSEMBL_VERSION;
  my $adaptor = new EnsEMBL::Web::DBSQL::WebsiteAdaptor($hub);
  my $release      = $adaptor->fetch_release($release_id);
  my $release_date = $release->{'date'};

  $html .= qq(<h1>What's New in Release $release_id ($release_date)</h1>);

  ## Are we using static news content output from a script?
  my $file         = '/ssi/whatsnew.html';
  my $include = EnsEMBL::Web::Controller::SSI::template_INCLUDE(undef, $file);

  if ($release_id == $hub->species_defs->ENSEMBL_VERSION && $include) {
    $html .= '<h2>Headlines</h2>'.$include;
  }

  my $first_production = $hub->species_defs->get_config('MULTI', 'FIRST_PRODUCTION_RELEASE');

  if ($hub->species_defs->multidb->{'DATABASE_PRODUCTION'}{'NAME'} 
      && $first_production && $release_id > $first_production) {
    ## get news changes
    my $adaptor = EnsEMBL::Web::DBSQL::ProductionAdaptor->new($hub);
    my @changes = ();
    if ($adaptor) {
      @changes = @{$adaptor->fetch_changelog({'release' => $release_id})};
    }
 
    if (scalar(@changes) > 0) {

      my ($record, $prev_team);;

      ## Quick'n'dirty TOC
      $html .= qq(<h2>Teams</h2>
                <ul>\n);
      foreach $record (@changes) {
        if ($record->{'team'} ne $prev_team) {
          $html .= sprintf '<li><a href="#team-%s">%s</a></li>', $record->{'team'}, $record->{'team'};
        }
        $prev_team = $record->{'team'};
      }
      $html .= "</ul>\n\n";
      $prev_team = undef;


      ## format news changes
      foreach my $record (@changes) {

        ## is it a new category?
        if ($prev_team ne $record->{'team'}) {
          $html .= sprintf '<h2 id="team-%s">%s</h2>', $record->{'team'}, $record->{'team'};;
        }

        $prev_team = $record->{'team'};
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
            if ($sp->{'common_name'} =~ /\./) {
              push @names, '<i>'.$sp->{'common_name'}.'</i>';
            }
            else {
              push @names, $sp->{'common_name'};
            } 
          }
          $sp_text = join(', ', @names);
        }
        $html .= " ($sp_text)</h3>\n";
        my $content = $record->{'content'};
        #if ($content !~ /^</) { ## wrap bare content in a <p> tag
        #  $content = "<p>$content</p>";
        #}
        $html .= $content."\n\n";
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
