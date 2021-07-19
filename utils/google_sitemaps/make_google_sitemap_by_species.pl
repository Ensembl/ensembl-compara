#!/usr/local/bin/perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2021] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Use this script to generate google sitemaps for your Ensembl site.
# By default sitemaps will be generated for all species in the site, but you 
# can also specify which species you want to create maps for. e.g.
#
#   $ make_google_sitemap_by_species.pl
#   $ make_google_sitemap_by_species.pl aspergillus_clavatus aspergillus_flavus
#
# The sitemap files will be created in the 'sitemaps' folder. For each species, the 
# maps are split into numbered files, each containing 20,000 urls. e.g.
#
#   index.xml
#   main.xml
#   <species_name>_1.xml
#   <species_name>_2.xml
#   <species_name>_<n>.xml
#
# Don't forget to add a line to your robots.txt file, e.g.
#
#   Sitemap: http://fungi.ensembl.org/index.xml
#
# If you want to change the location of the sitemaps use --sitemap_path e.g. 
#
#   $ make_google_sitemap_by_species.pl --sitemap_path=/foo/bar/
#
# and change your robots.txt file accordingly, e.g,.
#
#   Sitemap: http://fungi.ensembl.org/foo/bar/index.xml 
#

use strict;
use File::Basename qw(dirname);
use FindBin qw($Bin);
use Getopt::Long;
use Search::Sitemap;
use Search::Sitemap::Index;
use Search::Sitemap::URL;
use Data::Dumper;

BEGIN {
  unshift @INC, "$Bin/../../conf";
  unshift @INC, "$Bin/../..";
  require SiteDefs; SiteDefs->import;
  unshift @INC, $_ for @SiteDefs::ENSEMBL_LIB_DIRS;
  require EnsEMBL::Web::DBHub;
}

my $skip_list;
GetOptions("skip=s", \$skip_list);

my $hub = EnsEMBL::Web::DBHub->new;
my $sd = $hub->species_defs;
my $domain = sprintf 'http://%s.ensembl.org', $sd->GENOMIC_UNIT || 'www';
my @sitemaps;

my $this_release = $sd->ENSEMBL_VERSION;

my $sitemap_path = $sd->GOOGLE_SITEMAPS_PATH;

mkdir($sitemap_path) unless -d $sitemap_path;

my $sitemap_url = $sd->GOOGLE_SITEMAPS_URL;
if ($sitemap_url) {
  $sitemap_url =~ s/^\///;
  $sitemap_url =~ s/\/$//;
  $sitemap_url = "$domain/$sitemap_url";
} else {
  $sitemap_url = $domain;
}

warn "Writing files to $sitemap_path";
warn "Actual URL will be $sitemap_url\n\n";

# create the 'common' sitemap for non-species urls
my $map = Search::Sitemap->new();
warn "\n\n"; ## Add some space because of deprecation warnings
$map->add(Search::Sitemap::URL->new(
  loc => "$domain/index.html",
  changefreq => 'monthly',
  priority => 1.0,
  lastmod => 'now'
));
$map->write("${sitemap_path}/sitemap-common.xml");
push @sitemaps, "sitemap-common.xml";

my @skip = split /,/, $skip_list;

# create the sitemaps for each dataset
foreach my $dataset (@ARGV ? @ARGV : @$SiteDefs::PRODUCTION_NAMES) {
  next if grep { $_ eq $dataset } @skip;
  
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
    loc => "$sitemap_url/$_", 
    lastmod => 'now'
  ));
}
$index->write("${sitemap_path}/sitemap-index.xml");

#if($domain eq "http://www.ensembl.org") {
#  print ("Moving sitemaps to /ensemblweb/www/www_$this_release/ensembl-webcode/htdocs/ \n");
#  system("rm -r /ensemblweb/www/www_$this_release/ensembl-webcode/htdocs/sitemaps") if(-d "/ensemblweb/www/www_$this_release/ensembl-webcode/htdocs/sitemaps");
#  system("mv sitemaps /ensemblweb/www/www_$this_release/ensembl-webcode/htdocs/");
#}

exit;

#------------------------------------------------------------------------------

sub get_dataset_urls {
  my ($sd, $adaptor, $dataset) = @_;
  
  my %url_template = (
    'species'    => "/Info/Index",
    'gene'       => "/Gene/Summary?g=",
    'transcript' => "/Transcript/Summary?t=",
  );
   
  my $sth = $adaptor->prepare('SELECT species_id, meta_value FROM meta WHERE meta_key = "species.production_name"');
  $sth->execute;
  
  my %species_path = map { $_->[0] => $sd->species_path(valid_species_name($sd, $_->[1])) } @{$sth->fetchall_arrayref};
  
  my @urls = map { $domain . $species_path{$_} . $url_template{'species'} } keys %species_path;
  my @analysis_ids = get_analysis_ids($adaptor);
  if(! @analysis_ids){
    print "Cannot fetch genes and transcripts - no analysis_ids\n";
    return @urls;
  }
  #foreach my $type (qw/gene transcript/) {  
  foreach my $type (qw/gene/) {  
    my $query = 
      "SELECT g.stable_id, g.${type}_id, cs.species_id 
       FROM ${type} g, seq_region sr, coord_system cs
       WHERE g.seq_region_id = sr.seq_region_id   
       AND   sr.coord_system_id = cs.coord_system_id 
       AND   g.analysis_id IN (" . join(', ', @analysis_ids) . ")";
    my $sth = $adaptor->prepare($query);
    $sth->execute;
    
    my @rows = @{$sth->fetchall_arrayref};
    foreach my $row (@rows) {
      my ($stable_id, $id, $species_id) = @{$row};     
      
      # generating full URL with gene, location and transcript
      my $sth = $adaptor->prepare(
        "SELECT t.stable_id, t.seq_region_start, t.seq_region_end, sr.name, g.stable_id 
         FROM seq_region sr, transcript t, gene g 
         WHERE g.gene_id=t.gene_id 
         AND sr.seq_region_id=t.seq_region_id 
         AND t.${type}_id = ?"
      );
      $sth->execute($id);
      
      my @regions = @{$sth->fetchall_arrayref};
      my $region = $regions[0];
      
      my $transcript = $region->[0];
      my $start = $region->[1];
      my $end = $region->[2];
      my $chromosome = $region->[3];
      my $gene = $region->[4];
      
      my $url = $species_path{$species_id} . $url_template{$type} . $stable_id;
      $url .= ";r=$chromosome:$start-$end";
      $url .= ";t=$transcript" if (@regions == 1 && $type eq 'gene');     #only if there is one transcript add it to the url
      $url .= ";g=$gene" if($type eq 'transcript');
      
      $url = "$domain/$url" if $url !~ /^http/;
      
      push @urls, $url;       
    }    
  }
  print "  Urls " . scalar @urls . "\n"; 
  return @urls;
}

sub valid_species_name {
  my ($sd, $species) = @_;
  # make sure the letter-case we use in the url is the version from valid_species
  # this will avoid an unwanted 307 Redirect
  foreach ($sd->valid_species) {
    return $_ if uc $_ eq uc $species;
  }
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
    
    if ($batch_count == $batch_size or $total_count == scalar @urls) {
# jh15: fixed a bug here, "$total_count == $#urls" was wrong. The loop ended 1 early and last url was never written
# and no file was written if total_count < batch_count
      my $filename = "sitemap_${dataset}_${suffix}.xml";
      $map->write("${sitemap_path}/$filename");
      print "  Wrote ${sitemap_path}/$filename\n";
      push @files, $filename;
      # get ready for next batch...
      $map = Search::Sitemap->new();
      $batch_count = 0;
      $suffix++;
    }
  }
  
  return @files;
}
