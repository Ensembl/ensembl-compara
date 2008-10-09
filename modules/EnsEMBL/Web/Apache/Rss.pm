package EnsEMBL::Web::Apache::Rss;

use strict;

use SiteDefs qw(:ALL);
use Apache2::Const qw(:common :methods :http);
use Apache2::Util ();

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::NewsItem;
use EnsEMBL::Web::Data::Species;
use EnsEMBL::Web::Cache;

our $MEMD = EnsEMBL::Web::Cache->new;

#############################################################
# Mod_perl request handler all /img-tmp and /img-cache images
#############################################################
sub handler {
  my $r = shift;

  $r->err_headers_out->{ 'Ensembl-Error' => 'Problem in module EnsEMBL::Web::Apache::Rss' };
  $r->custom_response(SERVER_ERROR, '/Crash');

  my $release_id = $SiteDefs::VERSION;
  my ($species) = EnsEMBL::Web::Data::Species->find(name => $ENV{ENSEMBL_SPECIES});
  my $species_id = $species ? $species->id : undef;
   
  $ENV{CACHE_KEY} = '::RSS';
  $ENV{CACHE_KEY} .= '::'. $species->name if $species;

  if( $MEMD && (my $rss = $MEMD->get($ENV{CACHE_KEY})) ) {
    
      #$r->headers_out->set('Accept-Ranges'  => 'bytes');
      #$r->headers_out->set('Content-Length' => $data->{'size'});
      $r->headers_out->set('Expires'        => Apache2::Util::ht_time($r->pool, $r->request_time + 86400*30*12) );
      
      $r->content_type('xml/rss');
      my $rc = $r->print($rss);
      return OK;

  } else {

      my @news = EnsEMBL::Web::Data::NewsItem->fetch_news_items(
        {
          release_id  => $release_id,
          $species    ? (species => $species->id) : (),
        },
        { order_by => 'priority' },
      );
      $r->headers_out->set('Expires' => Apache2::Util::ht_time($r->pool, $r->request_time + 86400*30*12) );

      my $rss = qq(
        <rss version="2.0">
          <channel>
            <language>en</language>
            <category>Bioinformatics</category>
            <category>Genomics</category>
            <category>Genome Browsers</category>
            <copyright>Copyright 2008 The Ensembl webteam</copyright>
            <managingEditor>helpdesk\@ensembl.org</managingEditor>
            <webMaster>webmaster\@ensembl.org</webMaster>
            <title>Ensembl release $release_id</title>
            <link>http://www.ensembl.org/</link>
            <generator>Ensembl web API</generator>
            <image>
              <url>http://www.ensembl.org/img/e-rss.png</url>
              <title>Ensembl release $release_id</title>
              <link>http://www.ensembl.org/</link>
            </image>
            <ttl>1440</ttl>
            <description>
              Ensembl is a joint project between EMBL - EBI and the Sanger Institute
              to develop a software system which produces and maintains automatic
              annotation on selected eukaryotic genomes. Ensembl is primarily
              funded by the Wellcome Trust. The site provides free access to all
              the data and software from the Ensembl project. Click on a species
              name to browse the data.
            </description>
            <language>en-gb</language>
      );

      foreach my $item ( @news ) {
        next unless $item->title && $item->content;
        my $C = $item->content;
        if( $C =~ /^\s*<p>(.*)<\/p>/ ) {
          $C = $1;
        }
        $C =~ s/<.*//sm;
        $rss .= sprintf(
          '<item>
            <title>%s</title>
            <description>%s</description>
            <link>'.$SiteDefs::ENSEMBL_BASE_URL.'/info/website/news/index.html</link>
          </item>',
          $item->title,
          $C,
          undef, #$this_species,
          undef, #$release_id,
          $item->id,
        ); 
      }

      $rss .= '</channel></rss>';

      my @tags = qw(STATIC RSS);
      push @tags, keys %{ $ENV{CACHE_TAGS} } if $ENV{CACHE_TAGS};
      $MEMD->set($ENV{CACHE_KEY}, $rss, $ENV{CACHE_TIMEOUT}, @tags);
      
      $r->content_type('xml/rss');
      my $rc = $r->print($rss);
      return OK;
      
  }

} # end of handler

1;
