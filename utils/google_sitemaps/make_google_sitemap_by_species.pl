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
  require SiteDefs;
  unshift @INC, $_ for @SiteDefs::ENSEMBL_LIB_DIRS;
  require EnsEMBL::Web::Hub;  
}

my $hub = new EnsEMBL::Web::Hub;
my $sd = $hub->species_defs;
my $domain = sprintf 'http://%s.ensembl.org', $sd->GENOMIC_UNIT || 'www';
my $ouput_dir = 'sitemaps'; 
my @sitemaps;

my $sitemap_path; # default setting is htdocs root
GetOptions("sitemap_path=s", \$sitemap_path);

if ($sitemap_path) {
  $sitemap_path =~ s/^\///;
  $sitemap_path =~ s/\/$//;
  $sitemap_path = "$domain/$sitemap_path";
} else {
  $sitemap_path = $domain;
}
#`rm -r $ouput_dir` if(-d $ouput_dir);
mkdir($ouput_dir) unless -d $ouput_dir;

# create the 'common' sitemap for non-species urls
my $map = Search::Sitemap->new();
$map->add(Search::Sitemap::URL->new(
  loc => "$domain/index.html",
  changefreq => 'monthly',
  priority => 1.0,
  lastmod => 'now'
));
$map->write("${ouput_dir}/sitemap-common.xml");
push @sitemaps, "sitemap-common.xml";

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
    loc => "$sitemap_path/$_", 
    lastmod => 'now'
  ));
}
$index->write("${ouput_dir}/sitemap-index.xml");

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
  
  my %species_path = map { $_->[0] => $sd->species_path(valid_species_name($sd, $_->[1])) } @{$sth->fetchall_arrayref};
  
  my @urls;
  
  foreach my $type (qw/gene transcript/) {  
    my $sth = $adaptor->prepare(
      "SELECT gs.stable_id, g.${type}_id, cs.species_id 
       FROM ${type} g, ${type}_stable_id gs, seq_region sr, coord_system cs
       WHERE g.${type}_id = gs.${type}_id         
       AND   g.seq_region_id = sr.seq_region_id   
       AND   sr.coord_system_id = cs.coord_system_id 
       AND   g.analysis_id IN (" . join(', ', get_analysis_ids($adaptor)) . ")"
    );
    $sth->execute;
    
    my @rows = @{$sth->fetchall_arrayref};
    foreach my $row (@rows) {
      my ($stable_id, $id, $species_id) = @{$row};     
      
      # generating full URL with gene, location and transcript
      my $sth = $adaptor->prepare(
        "SELECT ts.stable_id, seq_region_start, seq_region_end, sr.name, gs.stable_id 
         FROM seq_region sr, transcript t, transcript_stable_id ts, gene_stable_id gs 
         WHERE gs.gene_id=t.gene_id 
         AND sr.seq_region_id=t.seq_region_id 
         AND t.transcript_id=ts.transcript_id 
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
      
      $url = "$domain$url" if $url !~ /^http/;
      
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
    
    if ($batch_count == $batch_size or $total_count == $#urls) {
      my $filename = "sitemap_${dataset}_${suffix}.xml";
      $map->write("${ouput_dir}/$filename");
      print "  Wrote ${ouput_dir}/$filename\n";
      push @files, $filename;
      # get ready for next batch...
      $map = Search::Sitemap->new();
      $batch_count = 0;
      $suffix++;
    }
  }
  
  return @files;
}
