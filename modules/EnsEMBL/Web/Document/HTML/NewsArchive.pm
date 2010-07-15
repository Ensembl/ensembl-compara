package EnsEMBL::Web::Document::HTML::NewsArchive;

### This module outputs news for previous Ensembl releases 
### Done as a separate module, since older news includes all declarations

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Hub;
use EnsEMBL::Web::DBSQL::WebsiteAdaptor;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;

  my $hub = new EnsEMBL::Web::Hub;
  my $release_id = $hub->param('id') || $hub->species_defs->ENSEMBL_VERSION; 
  
  my $html = qq(<h1>What's New in Release $release_id</h1>);
  
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

  return $html;
}


1;
