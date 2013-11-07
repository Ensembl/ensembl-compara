package EnsEMBL::Web::Apache::Rss;

use strict;

use SiteDefs;
use Apache2::Const qw(:common :methods :http);
use Apache2::Util;

use EnsEMBL::Web::Hub;
use EnsEMBL::Web::DBSQL::WebsiteAdaptor;
use EnsEMBL::Web::Cache;

our $MEMD = EnsEMBL::Web::Cache->new;

#############################################################
# Mod_perl request handler all /img-tmp and /img-cache images
#############################################################
sub handler {
  my $r = shift;

  $r->err_headers_out->{'Ensembl-Error' => 'Problem in module EnsEMBL::Web::Apache::Rss'};
  $r->custom_response(SERVER_ERROR, '/Crash');

  my $hub     = EnsEMBL::Web::Hub->new;
  my $species = $hub->species;

  my $release_id = $SiteDefs::ENSEMBL_VERSION;
   
  $ENV{'CACHE_KEY'}  = '::RSS';
  $ENV{'CACHE_KEY'} .= '::'. $species if $species;

  if ($MEMD && (my $rss = $MEMD->get($ENV{'CACHE_KEY'}))) {
    $r->headers_out->set('Expires' => Apache2::Util::ht_time($r->pool, $r->request_time + 86400*30*12));
    $r->content_type('xml/rss');
    $r->print($rss);
  } else {
    $r->headers_out->set('Expires' => Apache2::Util::ht_time($r->pool, $r->request_time + 86400*30*12));
    
    my $helpdesk  = $SiteDefs::ENSEMBL_HELPDESK_EMAIL;
    my $webmaster = $SiteDefs::ENSEMBL_SERVERADMIN;
    my $url       = $SiteDefs::ENSEMBL_STATIC_SERVER;
    my @news      = @{EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub)->fetch_news({ release => $release_id, species => $species })};

    my $rss = qq(
      <rss version="2.0">
        <channel>
          <language>en</language>
          <category>Bioinformatics</category>
          <category>Genomics</category>
          <category>Genome Browsers</category>
          <copyright>Copyright 2008 The Ensembl webteam</copyright>
          <managingEditor>$helpdesk</managingEditor>
          <webMaster>$webmaster</webMaster>
          <title>Ensembl release $release_id</title>
          <link>$url</link>
          <generator>Ensembl web API</generator>
          <image>
            <url>$url/img/e-rss.png</url>
            <title>Ensembl release $release_id</title>
            <link>$url</link>
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
    
    foreach my $item (@news) {
      next unless $item->{'title'} && $item->{'content'};
      
      my $content = $item->{'content'};
         $content = $1 if $content =~ /^\s*<p>(.*)<\/p>/;
         $content =~ s/<.*//sm;
      
      $rss .=
        "<item>
          <title>$item->{'title'}</title>
          <description>$content</description>
          <link>$url/info/website/news/index.html</link>
        </item>"; 
    }

    $rss .= '</channel></rss>';
    
    if (defined $MEMD) {
      my @tags = qw(STATIC RSS);
      push @tags, values %{$ENV{'CACHE_TAGS'}} if $ENV{'CACHE_TAGS'};
      
      $MEMD->set($ENV{'CACHE_KEY'}, $rss, $ENV{'CACHE_TIMEOUT'}, @tags);
    }
    
    $r->content_type('xml/rss');
    $r->print($rss);
  }
  
  return OK;
} # end of handler

1;
