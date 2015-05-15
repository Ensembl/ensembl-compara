#!/usr/local/bin/perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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


use strict;

use File::Basename qw(dirname);
use FindBin qw($Bin);
use Getopt::Long;

BEGIN {
  my $serverroot = dirname($Bin);
  unshift @INC, "$serverroot/conf", $serverroot;
  
  require SiteDefs;
  
  unshift @INC, $_ for @SiteDefs::ENSEMBL_LIB_DIRS;

  require EnsEMBL::Web::DBSQL::WebsiteAdaptor;
  require EnsEMBL::Web::Hub;  
}

my $nodelete = 0;
GetOptions ('nodelete' => \$nodelete);

my $hub = new EnsEMBL::Web::Hub;
my $dbh = new EnsEMBL::Web::DBSQL::WebsiteAdaptor($hub)->db;
my $sd  = $hub->species_defs;
my $sth;

$dbh->do(
  'CREATE TABLE IF NOT EXISTS gene_autocomplete (
    species       varchar(255) DEFAULT NULL,
    stable_id     varchar(128) NOT NULL DEFAULT "",
    display_label varchar(128) DEFAULT NULL,
    location      varchar(60)  DEFAULT NULL,
    db            varchar(32)  NOT NULL DEFAULT "core",
    KEY i  (species, display_label),
    KEY i2 (species, stable_id),
    KEY i3 (species, display_label, stable_id)
  )'
);

if (!@ARGV and !$nodelete) {
  my %existing_species = map { lc $_ => 1 } @$SiteDefs::ENSEMBL_DATASETS;
  my @delete = grep !$existing_species{$_}, @{$dbh->selectcol_arrayref('select distinct(species) from gene_autocomplete')};
  
  if (@delete) {
    warn sprintf "Deleting old species: %s\n", join ', ', @delete;
    $dbh->do(sprintf "DELETE FROM gene_autocomplete WHERE species IN ('%s')", join "', '", @delete);
  }
}

foreach my $dataset (@ARGV ? @ARGV : @$SiteDefs::ENSEMBL_DATASETS) {
  warn "$dataset\n";
  
  my $dbs = $sd->get_config($dataset, 'databases');
  
  next unless $dbs;
  
  my (%species_hash, $delete, @insert);
  
  foreach my $db (grep $dbs->{'DATABASE_' . uc}, qw(core otherfeatures)) {
    my $adaptor = $hub->get_adaptor('get_GeneAdaptor', $db, $dataset);
    
    if (!$adaptor) {
      warn "$db doesn't exist for $dataset\n";
      next;
    }
    
    if (!scalar keys %species_hash) {
      $sth = $adaptor->prepare('SELECT species_id, meta_value FROM meta WHERE meta_key = "species.production_name"');
      $sth->execute;
      
      %species_hash = map { $_->[0] => $_->[1] } @{$sth->fetchall_arrayref};
      $delete       = join "', '", values %species_hash;
    }
    
    $sth = $adaptor->prepare(
      'SELECT ad.analysis_id, ad.web_data 
        FROM analysis_description ad, analysis a 
        WHERE a.analysis_id = ad.analysis_id      AND 
              a.logic_name != "estgene"           AND 
              a.logic_name NOT LIKE "%refseq%"    AND 
              ad.displayable = 1'
    );
    
    $sth->execute;
    
    my %analysis_ids;
    
    foreach my $row (@{$sth->fetchall_arrayref}) {
      next if $analysis_ids{$row->[0]};
      
      my $web_data = eval($row->[1]);
      $analysis_ids{$row->[0]} = 1 unless ref $web_data eq 'HASH' && $web_data->{'gene'}->{'do_not_display'};
    }
    
    my $ids = join ',', keys %analysis_ids;
    
    next unless $ids;
    
    $sth = $adaptor->prepare(
      "SELECT g.stable_id, xr.display_label, cs.species_id, sr.name, g.seq_region_start, g.seq_region_end
        FROM gene g, xref xr, seq_region sr, coord_system cs
        WHERE g.display_xref_id  = xr.xref_id         AND
              g.seq_region_id    = sr.seq_region_id   AND
              sr.coord_system_id = cs.coord_system_id AND
              g.analysis_id IN ($ids)"
    );
    
    $sth->execute;
    
    push(@insert, sprintf("('$species_hash{$_->[2]}', '$_->[0]', %s, %s, '$db')", $dbh->quote($_->[1]), $dbh->quote("$_->[3]:$_->[4]-$_->[5]"))) for sort { $a->[1] cmp $b->[1] } grep { $_->[0] ne $_->[1] } @{$sth->fetchall_arrayref};
  }
  
  $dbh->do("DELETE FROM gene_autocomplete WHERE species IN ('$delete')") if $delete;
  
  # insert in batches of 10,000
  while (@insert) {
    my $values = join(',', splice(@insert, 0, 10000));
    $dbh->do("INSERT INTO gene_autocomplete (species, stable_id, display_label, location, db) VALUES $values");
  }  
}

$dbh->do("OPTIMIZE TABLE gene_autocomplete");
$dbh->disconnect;

1;
