#!/usr/local/bin/perl

# Use this script to generate google sitemaps for your Ensembl site.
# By default sitemaps will be generated for all species in the site, but you 
# can also specify which species you want to create maps for. e.g.
#
#   $ make_google_sitemap_by_species.pl
#   $ make_google_sitemap_by_species.pl Aspergillus_clavatus Aspergillus_flavus
#
# The sitemap files will be created in the 'sitemaps' folder. For each species, the 
# maps are split into numbered files, each containing 20,000 urls. e.g.
#
#   sitemaps/index.xml
#            main.xml
#            <species_name>_1.xml
#            <species_name>_2.xml
#            <species_name>_<n>.xml
#
# Don't forget to add a line to your robots.txt file, e.g.
#
#   Sitemap: http://fungi.ensembl.org/sitemaps/index.xml 

use strict;
use File::Basename qw(dirname);
use FindBin qw($Bin);
use Search::Sitemap;
use Search::Sitemap::Index;
use Search::Sitemap::URL;

BEGIN {
  unshift @INC, "$Bin/../../conf";
  unshift @INC, "$Bin/../..";
  require SiteDefs;
  unshift @INC, $_ for @SiteDefs::ENSEMBL_LIB_DIRS;
  require EnsEMBL::Web::Hub;  
}

my $hub = new EnsEMBL::Web::Hub;
my $sd = $hub->species_defs;
my $domain = sprintf 'http://%s.ensembl.org', $sd->GENOMIC_UNIT || 'www';
my @sitemaps;

mkdir('sitemaps') unless -d 'sitemaps';

# create the 'main' sitemap for non-species pages
my $map = Search::Sitemap->new();
$map->add(Search::Sitemap::URL->new(
  loc => "$domain/index.html",
  changefreq => 'monthly',
  priority => 1.0,
  lastmod => 'now'
));
$map->write('sitemaps/main.xml');
push @sitemaps, 'sitemaps/main.xml';

# create the sitemaps for each dataset
foreach my $dataset (@ARGV ? @ARGV : @$SiteDefs::ENSEMBL_DATASETS) {
  print "$dataset\n";
  my $adaptor = $hub->get_adaptor('get_GeneAdaptor', 'core', $dataset);
  if (!$adaptor) {
    warn "core db doesn't exist for $dataset\n";
    next;
  }
  my @urls = get_dataset_urls($sd, $adaptor, $dataset);
  push @sitemaps, create_dataset_sitemaps($dataset, \@urls); 
}

# create the sitemap index
my $index = Search::Sitemap::Index->new();
foreach (@sitemaps) {
  $index->add(Search::Sitemap::URL->new(
    loc => "$domain/$_", 
    lastmod => 'now'
  ));
}
$index->write('sitemaps/index.xml');

exit;

#------------------------------------------------------------------------------

sub get_dataset_urls {
  my ($sd, $adaptor, $dataset) = @_;
  
  my %url_template = (
    'gene'       => "/Gene/Summary?g=",
    'transcript' => "/Transcript/Summary?t=",
  );
    
  my $sth = $adaptor->prepare('SELECT species_id, meta_value FROM meta WHERE meta_key = "species.production_name"');
  $sth->execute;
  my %species_path = map { $_->[0] => $sd->species_path($_->[1]) } @{$sth->fetchall_arrayref};
  
  my @urls;
  
  foreach my $type (qw/gene transcript/) {  
    my $sth = $adaptor->prepare(
      "SELECT gs.stable_id, cs.species_id 
       FROM ${type} g, ${type}_stable_id gs, seq_region sr, coord_system cs
       WHERE g.${type}_id = gs.${type}_id         
       AND   g.seq_region_id = sr.seq_region_id   
       AND   sr.coord_system_id = cs.coord_system_id 
       AND   g.analysis_id IN (" . join(', ', get_analysis_ids($adaptor)) . ")"
    );
    $sth->execute;
    
    my @rows = @{$sth->fetchall_arrayref};
    foreach my $row (@rows) {
      my ($stable_id, $species_id) = @{$row};       
      push @urls, $species_path{$species_id} . $url_template{$type} . $stable_id;       
    }    
  }

  print "  Urls " . scalar @urls . "\n"; 
  return @urls;
}

sub get_analysis_ids {
  my ($adaptor) = @_;
  
  my $sth = $adaptor->prepare(
      "SELECT ad.analysis_id, ad.web_data 
       FROM analysis_description ad, analysis a 
       WHERE a.analysis_id = ad.analysis_id  
       AND   ad.displayable = 1"
  );
  $sth->execute;
  
  my %analysis_ids;
  foreach my $row (@{$sth->fetchall_arrayref}) {
    next if $analysis_ids{$row->[0]};
    my $web_data = eval($row->[1]);
    $analysis_ids{$row->[0]} = 1 unless ref $web_data eq 'HASH' && $web_data->{'gene'}->{'do_not_display'};
  }
  
  return keys %analysis_ids;
}

sub create_dataset_sitemaps {
  my ($dataset, $urls_ref) = @_;
  my @urls = @$urls_ref;
  
  my $batch_size = 20000;
  my $batch_count = 0;
  my $total_count = 0;
  my $suffix = 1;
  my $map = Search::Sitemap->new();
  
  my @files;
  foreach my $url (@urls) {
    $map->add(
      loc        => $url,
      priority   => 1.0,
      lastmod    => 'now',
      changefreq => 'monthly'
    );
    $batch_count++;
    $total_count++;
    
    if ($batch_count == $batch_size or $total_count == $#urls) {
      my $filename = "sitemaps/${dataset}_${suffix}.xml";
      $map->write($filename);
      print "  Wrote $filename\n";
      push @files, $filename;
      # get ready for next batch...
      $map = Search::Sitemap->new();
      $batch_count = 0;
      $suffix++;
    }
  }
  
  return @files;
}
