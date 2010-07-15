package EnsEMBL::Web::Document::HTML::News;

### This module outputs news for the current Ensembl release, 
### optionally sorted into news applying to the current species and other news

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Hub;
use EnsEMBL::Web::DBSQL::WebsiteAdaptor;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;
  my $html;
  
  my $hub = new EnsEMBL::Web::Hub;
  my $release_id = $hub->species_defs->ENSEMBL_VERSION; 

  ## get news stories
  my $adaptor = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub);
  my @stories;

  if ($adaptor) {
    @stories = @{$adaptor->fetch_news({'release' => $release_id})};
  }

  if (scalar(@stories) > 0) {
    foreach my $item (@stories) {
      $html .= '<h4 id="news_'.$item->{'id'}.'">'.$item->{'title'};

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
          if ($sp->{'common_name'} =~ /\./) {
            push @names, '<i>'.$sp->{'common_name'}.'</i>';
          }
          else {
            push @names, $sp->{'common_name'};
          } 
        }
        $sp_text = join(', ', @names);
      }
      $html .= " ($sp_text)</h4>\n";

      my $content = $item->{'content'};
      if ($content !~ /^</) { ## wrap bare content in a <p> tag
        $content = "<p>$content</p>";
      }
      $html .= $content."\n\n";
    }
  }
  else {
    $html .= qq(<p>No news is currently available for release $release_id.</p>\n);
  }

  return $html;
}


1;
