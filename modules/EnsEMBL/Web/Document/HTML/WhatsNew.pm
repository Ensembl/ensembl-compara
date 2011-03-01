# $Id$

package EnsEMBL::Web::Document::HTML::WhatsNew;

### This module outputs a selection of news headlines from either 
### a static HTML file or a database (ensembl_website or ensembl_production) 

use strict;

use EnsEMBL::Web::Controller::SSI;
use EnsEMBL::Web::DBSQL::WebsiteAdaptor;
use EnsEMBL::Web::DBSQL::ProductionAdaptor;
use EnsEMBL::Web::Hub;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self         = shift;
  my $hub          = new EnsEMBL::Web::Hub;
  my $species_defs = $hub->species_defs;
  my $html;

  my $release_id = $hub->param('id') || $hub->param('release_id') || $hub->species_defs->ENSEMBL_VERSION;
  return unless $release_id;

  my $adaptor = new EnsEMBL::Web::DBSQL::WebsiteAdaptor($hub);
  my $release      = $adaptor->fetch_release($release_id);
  my $release_date = $self->pretty_date($release->{'date'});
  my $html = qq{<h2 class="first">What's New in Release $release_id ($release_date)</h2>};

  ## Are we using static news content output from a script?
  my $file         = '/ssi/whatsnew.html';
  my $include = EnsEMBL::Web::Controller::SSI::template_INCLUDE(undef, $file);
  ## Only use static page with current release!
  if ($release_id == $hub->species_defs->ENSEMBL_VERSION && $include) {
    return $html.$include;
  }

  ## Return dynamic content from the ensembl_website database
  my $news_url     = '/info/website/news/index.html?id='.$release_id;
  my @items = ();

  my $first_production = $hub->species_defs->get_config('MULTI', 'FIRST_PRODUCTION_RELEASE');

  if ($hub->species_defs->multidb->{'DATABASE_PRODUCTION'}{'NAME'}
      && $first_production && $release_id > $first_production) {
    ## TODO - implement way of selecting interesting news stories
    #my $p_adaptor = EnsEMBL::Web::DBSQL::ProductionAdaptor->new($hub);
    #if ($p_adaptor) {
    #  @items = @{$p_adaptor->fetch_changelog({'release' => $release_id, order_by => 'priority', limit => 5})};
    #}   
  }
  elsif ($hub->species_defs->multidb->{'DATABASE_WEBSITE'}{'NAME'}) { 
    @items    = @{$adaptor->fetch_news({ release => $release_id, order_by => 'priority', limit => 5 })};
  } 

  if (scalar @items > 0) {
    $html .= "<ul>\n";

    ## format news headlines
    foreach my $item (@items) {
      my @species = @{$item->{'species'}};
      my (@sp_ids, $sp_id, $sp_name, $sp_count);
      
      if (!scalar(@species) || !$species[0]) {
        $sp_name = 'all species';
      } 
      elsif (scalar(@species) > 5) {
        $sp_name = 'multiple species';
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
        
        $sp_name = join ', ', @names;
      }
      
      ## generate HTML
      $html .= qq{<li><strong><a href="$news_url#news_$item->{'id'}" style="text-decoration:none">$item->{'title'}</a></strong> ($sp_name)</li>\n};
    }

    $html .= "</ul>\n";
  }
  else {
    $html .= "<p>No news is currently available for release $release_id.</p>\n";
  }

  return $html;
}

1;
