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

# TODO - change this according to new Blast code

use strict;
use FindBin qw($Bin);


# Load libraries needed for reading config # 

use DBI;
use Carp;
use Getopt::Long;
use Data::Dumper;
use Search::Sitemap;
use Search::Sitemap::Index;
use Search::Sitemap::URL;
use Regexp::Common qw /URI/;

BEGIN {
   unshift @INC, "$Bin/../../conf";
   unshift @INC, "$Bin/../..";
   eval { require SiteDefs; SiteDefs->import; };
   if ($@) { die "Can't use SiteDefs.pm - $@\n"; }
   map { unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS; 
}

use EnsEMBL::Web::BlastView::BlastDefs;
our $DEFS = EnsEMBL::Web::BlastView::BlastDefs->new;

my ( $host, $user, $pass, $port, $inifile, $chromosome, $start, $end, $transcript, $gene, $robots );

# prepare sitemaps dir
if (-d 'sitemaps') {
  print "emptying old sitemaps dir\n";
  `rm sitemaps/*`;
} else {
  print "creating sitemaps dir\n";
  mkdir('sitemaps');
}

my %rHash = map { $_ } @ARGV;
if ( $inifile = $rHash{'-inifile'} ) {
   my $icontent = `cat $inifile`;
   warn $icontent;
   eval $icontent;
}


GetOptions(
   "host=s", \$host, "port=i",    \$port, "user=s", \$user,"pass=s", \$pass, "inifile=s", \$inifile, "robots", \$robots);

my $species_list = [ $DEFS->dice( -out => 'species' ) ];

use EnsEMBL::Web::SpeciesDefs;
my $SPECIES_DEFS = EnsEMBL::Web::SpeciesDefs->new(); $host ||= $SPECIES_DEFS->DATABASE_HOST; $port ||= $SPECIES_DEFS->DATABASE_HOST_PORT;$user ||= 'ensro';
my $sitemap_index = Search::Sitemap::Index->new();

my $domain = sprintf 'http://%s.ensembl.org', $SPECIES_DEFS->GENOMIC_UNIT || 'www';
print "domain: $domain\n";

if ($robots) {
  print "creating sitemaps/robots.txt\n";
  open ROBOTS, ">", "sitemaps/robots.txt" or die $!;
  print ROBOTS "Sitemap: $domain/sitemap-index.xml\n";
  close ROBOTS;
}

my $COUNTER;
my $SITEMAP_NUM = 1;

my %lookup = (
   'gene' =>
     sub { return "$_[0]->{species_path}/Gene/Summary?g=$_[0]->{stable_id}" },
   'transcript' => sub {
       return "$_[0]->{species_path}/Transcript/Summary?t=$_[0]->{stable_id}";
   },
);

my $sample_sp_path = $SPECIES_DEFS->species_path( @{$species_list}->[0] );
$sample_sp_path =~ /$RE{URI}{HTTP}{-keep}/; 
my $toplevel = $domain . $3 . '/';

my $map = Search::Sitemap->new();
$map->add(
   Search::Sitemap::URL->new(
       loc        => qq{$toplevel/index.html},
       changefreq => 'monthly',
       priority   => 1.0,
       lastmod    => 'now'
   )
);

$COUNTER++;

foreach my $species (@$species_list) {   
  my $sp_path = $SPECIES_DEFS->species_path($species);
  $sp_path =~ /$RE{URI}{HTTP}{-keep}/;
  print $species,"\n";

  my $dsn = "DBI:mysql:host=$host";
  $dsn .= ";port=$port" if ($port);
  my $db_name = $SPECIES_DEFS->get_config( $species, 'databases' )->{DATABASE_CORE}->{NAME};
  
  my $dbh = DBI->connect( "$dsn:$db_name", $user, $pass )or die "DBI::error";
  
  my $entry;
  $entry->{species_path} = $SPECIES_DEFS->species_path($species);
  
  foreach my $type (qw/gene transcript/) {  
    my $type_id = $type.qq{_id}; 
    my $query = qq{select stable_id,$type_id from $type} . qq{_stable_id}; 
    my $stable_ids = $dbh->selectall_arrayref($query);

    foreach my $stable_id (@$stable_ids) {
      $entry->{stable_id} = $stable_id->[0];
      my $url = eval { $lookup{$type}($entry) };

      #generating full URL with gene,location and transcript
      my $id = $stable_id->[1];
      my $sql_query = qq{select ts.stable_id,seq_region_start,seq_region_end,sr.name,gs.stable_id from seq_region sr, transcript t, transcript_stable_id ts,gene_stable_id gs where gs.gene_id=t.gene_id and sr.seq_region_id=t.seq_region_id and t.transcript_id=ts.transcript_id and t.$type_id=$id};
      my $details = $dbh->selectall_arrayref($sql_query);
      my $count = @$details;
      
      foreach my $region (@$details)
      {
        $chromosome = $region->[3];
        $start = $region->[1];
        $end = $region->[2];
        $transcript = $region->[0];
        $gene = $region->[4];
      }
      $url = qq{$domain$url;r=$chromosome:$start-$end};
      $url .= qq{;t=$transcript}    if ($count == 1 && $type eq 'gene');     #only if there is one transcript add it to the url
      $url .= qq{;g=$gene} if($type eq 'transcript');
      
# print $url,"\n";
# next;
      $map->add(
        loc        => $url,
        priority   => 1.0,
        lastmod    => 'now',
        changefreq => 'monthly'
      );
      
      $COUNTER++;
      
      if ( $COUNTER == 20000 ) {      
        #write out what's there
        my $sitemap_name = 'sitemaps/sitemap' . $SITEMAP_NUM . '.xml';
        my $sitemap_path = $toplevel . $sitemap_name;
        $map->write($sitemap_name);
        
        # add that to the index
        $sitemap_path =~ s/sitemaps\///;
        $sitemap_index->add(
            Search::Sitemap::URL->new(
              loc     => $sitemap_path,
              lastmod => 'now',
            )
        );        
        # create a new map
        $map = Search::Sitemap->new();
        
        # reset the counter
        $COUNTER = 0;
        
        $SITEMAP_NUM++;
      }    
    }
  }
}

my $sitemap_name = 'sitemaps/sitemap' . $SITEMAP_NUM . '.xml'; my $sitemap_path = $toplevel . $sitemap_name; $map->write($sitemap_name);

# add that to the index
$sitemap_path =~ s/sitemaps\///;
$sitemap_index->add(
   Search::Sitemap::URL->new(
       loc     => $sitemap_path,
       lastmod => 'now',
   )
);

$sitemap_index->write('sitemaps/sitemap-index.xml');
