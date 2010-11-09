#!/usr/local/bin/perl

use strict;

use File::Basename qw(dirname);
use FindBin qw($Bin);

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

$dbh->prepare('truncate table gene_autocomplete')->execute;

foreach my $species (@ARGV ? @ARGV : $sd->valid_species) {
  warn $species;
  
  my $dbs = $sd->get_config($species, 'databases');
  my $insert;
  
  next unless $dbs;
  
  foreach my $db (grep $dbs->{'DATABASE_' . uc}, qw(core otherfeatures)) {
    my $adaptor = $hub->get_adaptor('get_GeneAdaptor', $db, $species);
    
    if (!$adaptor) {
      warn "$db doesn't exist for $species\n";
      next;
    }
    
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
      
      $analysis_ids{$row->[0]} = 1 
        unless ref $web_data eq 'HASH' and $web_data->{'gene'}->{'do_not_display'};
    }
    
    my $ids = join ',', keys %analysis_ids;
    
    next unless $ids;
    
    $sth = $adaptor->prepare(
      "select gs.stable_id, x.display_label 
        from gene g, gene_stable_id gs, xref x
        where g.display_xref_id = x.xref_id and
              g.gene_id = gs.gene_id and
              g.analysis_id in ($ids)"
    );
    
    $sth->execute;
    
    $insert .= sprintf(qq{('$species', '$_->[0]', %s, '$db'),\n}, $dbh->quote($_->[1])) for sort { $a->[1] cmp $b->[1] } grep { $_->[0] ne $_->[1] } @{$sth->fetchall_arrayref};
  }
  
  $insert =~ s/,$//;
  
  $dbh->prepare("delete from gene_autocomplete where species = '$species'")->execute;
  $dbh->prepare("insert into gene_autocomplete (species, stable_id, display_label, db) values $insert")->execute if $insert;
}

$dbh->disconnect;

1;
