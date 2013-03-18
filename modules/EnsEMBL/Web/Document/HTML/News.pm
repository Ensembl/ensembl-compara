package EnsEMBL::Web::Document::HTML::News;

### This module outputs news for a given Ensembl release

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::DBSQL::ProductionAdaptor;
use EnsEMBL::Web::DBSQL::WebsiteAdaptor;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;
  my $html;

  my $hub           = $self->hub;
  my $release_id    = $hub->param('id') || $hub->species_defs->ENSEMBL_VERSION;
  my $adaptor       = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub);
  my $release       = $adaptor->fetch_release($release_id);
  my $release_date  = $release->{'date'};

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
    my (@sorted, %seen);
    if ($hub->species) {
      foreach (@changes) {
        next if $seen{$_->{'id'}};
        next if ($_->{'team'} eq 'Variation' && !exists $hub->species_defs->databases->{'DATABASE_VARIATION'});
        next if ($_->{'team'} eq 'Funcgen' && !exists $hub->species_defs->databases->{'DATABASE_FUNCGEN'});
        push @sorted, $_;
        $seen{$_->{'id'}}++;
      }
    }
    else {
      @sorted = @changes;
    }
    @sorted = sort {$a->{'team'} cmp $b->{'team'} || $a->{'priority'} <=> $b->{'priority'}} @sorted;
 
    if (scalar(@sorted) > 0) {

      my ($record, $prev_team);;

      ## Quick'n'dirty TOC
      $html .= qq(<h2>Teams</h2>
                <ul>\n);
      foreach $record (@sorted) {
        if ($record->{'team'} ne $prev_team) {
          $html .= sprintf '<li><a href="#team-%s">%s</a></li>', $record->{'team'}, $record->{'team'};
        }
        $prev_team = $record->{'team'};
      }
      $html .= "</ul>\n\n";
      $prev_team = undef;


      ## format news changes
      foreach my $record (@sorted) {

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
            if ($sp->{'web_name'} =~ /\./) {
              push @names, '<i>'.$sp->{'web_name'}.'</i>';
            }
            else {
              push @names, $sp->{'web_name'};
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
