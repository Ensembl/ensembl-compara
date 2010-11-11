#!/usr/local/bin/perl

use strict;

use File::Basename qw(dirname);
use FindBin qw($Bin);
use Data::Dumper;

BEGIN {
  my $serverroot = dirname($Bin);
  unshift @INC, "$serverroot/conf", $serverroot;
  
  require SiteDefs;
  
  unshift @INC, $_ for @SiteDefs::ENSEMBL_LIB_DIRS;

  require EnsEMBL::Web::DBSQL::WebsiteAdaptor;
  require EnsEMBL::Web::Hub;  
}

my $hub = new EnsEMBL::Web::Hub;
my $dbh = new EnsEMBL::Web::DBSQL::WebsiteAdaptor($hub)->db;
my $sd  = $hub->species_defs;
my $sth;

$dbh->prepare(
  'create table if not exists gene_autocomplete (
    species       varchar(255) DEFAULT NULL,
    stable_id     varchar(128) NOT NULL DEFAULT "",
    display_label varchar(128) DEFAULT NULL,
    db            varchar(32)  NOT NULL DEFAULT "core",
    KEY i  (species, display_label),
    KEY i2 (species, stable_id),
    KEY i3 (species, display_label, stable_id)
  )'
)->execute;

foreach my $dataset (@ARGV ? @ARGV : @$SiteDefs::ENSEMBL_DATASETS) {
  warn $dataset;
  
  my $dbs = $sd->get_config($dataset, 'databases');
  
  next unless $dbs;
  
  foreach my $db (grep $dbs->{'DATABASE_' . uc}, qw(core otherfeatures)) {
      
    my $adaptor = $hub->get_adaptor('get_GeneAdaptor', $db, $dataset);
    
    if (!$adaptor) {
      warn "$db doesn't exist for $dataset\n";
      next;
    }
    
    $sth = $adaptor->prepare("SELECT species_id, meta_value FROM meta WHERE meta_key = 'species.production_name'");
    $sth->execute;
    my %species_hash = map { $_->[0], $_->[1]} @{$sth->fetchall_arrayref};
 
    
    my %analysis_ids;
    
    $sth = $adaptor->prepare(
      'select ad.analysis_id, ad.web_data 
        from analysis_description ad, analysis a 
        where a.analysis_id = ad.analysis_id and 
              a.logic_name != "estgene" and 
              ad.displayable = 1'
    );
    
    $sth->execute;
    
    foreach my $row (@{$sth->fetchall_arrayref}) {
      next if $analysis_ids{$row->[0]};
      
      my $web_data = eval($row->[1]);
      $analysis_ids{$row->[0]} = 1 unless ref $web_data eq 'HASH' and $web_data->{'gene'}->{'do_not_display'};
    }
    
    my $ids = join ',', keys %analysis_ids;
    
    next unless $ids;
    
    $sth = $adaptor->prepare(
      "SELECT gs.stable_id, xr.display_label, cs.species_id 
        FROM gene g, gene_stable_id gs, xref xr, seq_region sr, coord_system cs
        WHERE g.display_xref_id = xr.xref_id AND
              g.gene_id = gs.gene_id AND
              g.seq_region_id = sr.seq_region_id AND
              sr.coord_system_id = cs.coord_system_id AND
              g.analysis_id in ($ids)
              "
    );
    
    $sth->execute;
      
    my $insert;
    $insert .= sprintf(qq{('$species_hash{$_->[2]}', '$_->[0]', %s, '$db'),\n}, $dbh->quote($_->[1])) 
      for sort { $a->[1] cmp $b->[1] } grep { $_->[0] ne $_->[1] } @{$sth->fetchall_arrayref};
    
    $insert =~ s/,$//;
        
    $dbh->do("delete from gene_autocomplete where species IN ('" . join("', '", values %species_hash) . "')");
    $dbh->do("insert into gene_autocomplete (species, stable_id, display_label, db) values $insert") if $insert;
  
  }
  
}

$dbh->disconnect;

1;
