#!/usr/local/bin/perl

use FindBin qw($Bin);
use File::Basename qw(dirname);
use strict;
use warnings;

BEGIN{
  warn dirname( $Bin );
  unshift @INC, "$Bin/../conf";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

use EnsEMBL::Web::SpeciesDefs;

my $SD = new EnsEMBL::Web::SpeciesDefs;

my %queries = (
  'Sequence regions' => qq(
     select cs.name, count(*) as n
       from coord_system as cs, seq_region as sr
      where cs.coord_system_id = sr.coord_system_id
      group by cs.coord_system_id
      order by name),
  'Simple' => qq(
     select a.logic_name as name, count(*) as n
       from simple_feature as f, analysis as a
      where a.analysis_id = f.analysis_id
      group by a.analysis_id
      order by name),
  'Protein align' => qq(
     select a.logic_name as name, count(*) as n
       from protein_align_feature as f, analysis as a
      where a.analysis_id = f.analysis_id
      group by a.analysis_id
      order by name),
  'Dna align' => qq(
     select a.logic_name as name, count(*) as n
       from dna_align_feature as f, analysis as a
      where a.analysis_id = f.analysis_id
      group by a.analysis_id
      order by name),
  'Gene features' => qq(
     select concat( ifnull(f.biotype,    '--'), ' : ',
                    ifnull(f.source,     '--'), ' : ',
                    ifnull(f.status, '--'), ' : ',
                    ifnull(a.logic_name, '--') ) as name,
            count(*) as n
       from gene as f, analysis as a
      where a.analysis_id = f.analysis_id
      group by name
      order by name),
  'Prediction transcripts' => qq(
     select a.logic_name as name, count(*) as n
       from prediction_transcript as f, analysis as a
      where a.analysis_id = f.analysis_id
      group by name
      order by name),
  'Transcript' => qq(
     select concat( ifnull(f.biotype,    '--'), ' : ',
                    ifnull(f.status, '--'), ' : ',
                    ifnull(a1.logic_name, '--'), ' : ',
                    ifnull(g.biotype,    '--'), ' : ',
                    ifnull(g.source,     '--'), ' : ',
                    ifnull(g.status, '--'), ' : ',
                    ifnull(a.logic_name, '--') ) as name,
            count(*) as n
       from transcript as f, gene as g, analysis as a, analysis as a1
      where a.analysis_id = g.analysis_id and g.gene_id = f.gene_id and f.analysis_id = a1.analysis_id
      group by name
      order by name),
  'Repeats' => qq(
     select rc.repeat_type as name, count(*) as n
       from repeat_consensus as rc, repeat_feature as rf
      where rc.repeat_consensus_id = rf.repeat_consensus_id
      group by rc.repeat_type
      order by name)
);

my @species = @ARGV ? @ARGV : @{$SD->ENSEMBL_SPECIES};

foreach my $sp ( @species ) {
  my $tree = $SD->{_storage}{$sp};
  foreach my $db_name ( qw(ENSEMBL_DB ENSEMBL_VEGA ENSEMBL_EST ENSEMBL_CDNA) ) {
    next unless $tree->{'databases'}->{$db_name}{'NAME'};
    my $dbh = $SD->db_connect( $tree, $db_name );
    foreach my $K ( sort keys %queries ) {
      my $results = $dbh->selectall_arrayref( $queries{$K} );
      next unless $results;
      next unless @{$results};
      foreach( @{$results} ) {
        print join "\t", $sp, $db_name, $K, @{$_},"\n";
      }
    }
  }
}
