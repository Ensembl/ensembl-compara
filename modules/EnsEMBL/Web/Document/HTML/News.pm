package EnsEMBL::Web::Document::HTML::News;

### This module outputs all the news for the current Ensembl release 

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::NewsItem;
use EnsEMBL::Web::Data::NewsCategory;
use EnsEMBL::Web::Data::Species;
use EnsEMBL::Web::Data::Release;

use base qw(EnsEMBL::Web::Root);


{

sub render {
  my $self = shift;

  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;
  my $filtered = 0;

  my $release_id = $species_defs->ENSEMBL_VERSION;
  my $release = EnsEMBL::Web::Data::Release->new($release_id);
  my $release_date = $self->pretty_date($release->date);

  my $html;

  ## get news stories
  my @stories = EnsEMBL::Web::Data::NewsItem->fetch_news_items({'release_id' => $release_id});

  ## Do lookup hashes
  my %species_lookup; 
  my @all_species = EnsEMBL::Web::Data::Species->find_all;
  foreach my $sp (@all_species) {
    $species_lookup{$sp->species_id} = $sp->name;
  }
  my %category_lookup; 
  my @categories = EnsEMBL::Web::Data::NewsCategory->find_all;
  foreach my $cat (@categories) {
    $category_lookup{$cat->news_category_id} = $cat->name;
  }

  if (scalar(@stories) > 0) {

    my $prev_cat = 0;
    ## format news stories
    foreach my $item (@stories) {
      next unless $item->title && $item->content;

      ## sort out species names
      my @species = $item->species; 
      my (@sp_ids, $sp_id, $sp_name, $sp_count);
      my $news_url = '';
      if (!@species) {
        $sp_name = 'all species';
      }
      elsif (@species > 5) {
        $sp_name = 'multiple species';
      }
      else {
        my @names;
        foreach my $sp (@species) {
          if ($sp->common_name =~ /\./) {
            push @names, '<i>'.$sp->common_name.'</i>';
          }
          else {
            push @names, $sp->common_name;
          } 
        }
        $sp_name = join(', ', @names);
      }
      ## generate HTML
  
      ## is it a new category?
      if ($prev_cat != $item->news_category_id) {
        $html .= '<h2>'.$category_lookup{$item->news_category_id}."</h2>\n";
      }

      $html .= sprintf(qq(<h3 id="%s">%s (%s)</h3>\n),
              $item->news_item_id, $item->title, $sp_name);
      my $content = $item->content;
      if ($content !~ /^</) { ## wrap bare content in a <p> tag
        $content = "<p>$content</p>";
      }
      $html .= $content."\n\n";
      $prev_cat = $item->news_category_id;
    }

  }
  else {
    $html .= qq(<p>No news is currently available for release $release_id.</p>\n);
  }

  return $html;
}

}

1;
