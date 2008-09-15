package EnsEMBL::Web::Document::HTML::News;

### This module outputs news for the current Ensembl release, 
### optionally sorted into news applying to the current species and other news

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
  my $current_sp = $ENV{'ENSEMBL_SPECIES'} =~ /_/ ? $ENV{'ENSEMBL_SPECIES'} : '';
  my $sitename = $species_defs->ENSEMBL_SITETYPE;

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

  my ($header, $subhead);
  if ($current_sp) {
    $header = '3';
    $subhead = '4';
  }
  else {
    $header = '2';
    $subhead = '3';
  }

  ## Sort stories
  my (@main, @other);
  if (scalar(@stories) > 0) {
    foreach my $item (@stories) {
      my $matched = 0;
      next unless $item->title && $item->content;
      my @species = $item->species; 
      if ($current_sp) {
        if (!@species) {
          push @main, $item;
        }
        else {
          foreach my $sp (@species) {
            if ($species_lookup{$sp} eq $current_sp) {
              push @main, $item;
              $matched = 1;
              last;
            } 
          }
          if (!$matched) {
            push @other, $item;
          }
        }
      }
      else {
        push @main, $item;
      }
    }
  }

  if (scalar(@main) > 0) {

    my $prev_cat = 0;
    ## format news stories
    foreach my $item (@main) {

      ## is it a new category?
      if ($prev_cat != $item->news_category_id) {
        $html .= "<h$header>".$category_lookup{$item->news_category_id}."</h$header>\n";
      }
      my $show_species = $current_sp ? 0 : 1;
      $html .= $self->_output_story($item, $subhead, $show_species);

      $prev_cat = $item->news_category_id;
    }

  }
  else {
    $html .= qq(<p>No news is currently available for release $release_id.</p>\n);
  }

  if (scalar(@other) > 0) {
    $html .= qq(<h2 style="margin-top:1em">Other news</h2>);
    foreach my $item (@other) {
      $html .= $self->_output_story($item, $subhead, 1);
    }
  }

  return $html;
}

sub _output_story {
  my ($self, $item, $header, $show_species) = @_;
  my $html = '<h'.$header.' id="'.$item->id.'">'.$item->title;
  if ($show_species) {
    ## sort out species names
    my @species = $item->species; 
    my $sp_text;
  
    if (!@species) {
      $sp_text = 'all species';
    }
    elsif (@species > 5) {
      $sp_text = 'multiple species';
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
      $sp_text = join(', ', @names);
    }
    $html .= " ($sp_text)";
  }
  $html .= "</h$header>\n";
  my $content = $item->content;
  if ($content !~ /^</) { ## wrap bare content in a <p> tag
    $content = "<p>$content</p>";
  }
  $html .= $content."\n\n";
  return $html;
}

}

1;
