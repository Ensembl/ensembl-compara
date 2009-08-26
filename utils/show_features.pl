#!/usr/local/bin/perl

use FindBin qw($Bin);
use File::Basename qw(dirname);
use strict;
use warnings;
no warnings 'uninitialized';

BEGIN{
  warn dirname( $Bin );
  unshift @INC, "$Bin/../conf";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

use EnsEMBL::Web::SpeciesDefs;
use XHTML::Validator;

my $SD = new EnsEMBL::Web::SpeciesDefs;

my %queries = (
  'Oligos' => qq(
    select of.analysis_id, oa.name , count(*) as n
      from oligo_feature as of, oligo_probe as op, oligo_array as oa
     where of.oligo_probe_id = op.oligo_probe_id and op.oligo_array_id = oa.oligo_array_id
     group by of.analysis_id, oa.name
     order by analysis_id, name),
#  'Regulatory Fact' => qq(
#    select rr.analysis_id, rf.type, count(*) as n
#      from regulatory_feature as rr left join regulatory_factor as rf on rr.regulatory_factor_id = rf.regulatory_factor_id
#     group by rr.analysis_id,rf.type
#     order by analysis_id, type),
#  'Regulatory Search' => qq(
#    select analysis_id,'',count(*) as n
#      from regulatory_search_region
#     group by analysis_id
#     order by analysis_id),
  'QTLs' => qq(
    select analysis_id,'',count(*) as n
      from qtl_feature
     group by analysis_id
     order by analysis_id),
  'Identity Xref' => qq(
    select analysis_id, '', count(*) as n
      from identity_xref
     group by analysis_id
     order by analysis_id),
  'Unmapped' => qq(
    select uo.analysis_id, ed.db_name, count(*) as n
      from unmapped_object as uo left join external_db as ed on uo.external_db_id = ed.external_db_id
     group by uo.analysis_id
     order by analysis_id,db_name),
  'Markers' => qq(
    select analysis_id, '', count(*) as n
      from marker_feature
     group by analysis_id
     order by analysis_id),
  'Sequence regions' => qq(
     select 0, cs.name, count(*) as n
       from coord_system as cs, seq_region as sr
      where cs.coord_system_id = sr.coord_system_id
      group by cs.coord_system_id
      order by cs.coord_system_id),
  'Density' => qq(
     select dt.analysis_id, '', count(*) as n
       from density_feature as df, density_type as dt
      where dt.density_type_id = df.density_type_id
      group by dt.analysis_id
      order by analysis_id),
  'Simple' => qq(
     select analysis_id, '', count(*) as n
       from simple_feature
      group by analysis_id
      order by analysis_id),
  'Protein' => qq(
     select analysis_id, '', count(*) as n
       from protein_feature
      group by analysis_id
      order by analysis_id),
  'Protein align' => qq(
     select analysis_id, '', count(*) as n
       from protein_align_feature
      group by analysis_id
      order by analysis_id),
  'Dna align' => qq(
     select analysis_id, '',count(*) as n
       from dna_align_feature
      group by analysis_id
      order by analysis_id),
  'Gene features' => qq(
     select analysis_id,
            concat( ifnull(biotype,    '--'), ' : ',
                    ifnull(source,     '--'), ' : ',
                    ifnull(status, '--') 
                  )  as name,
            count(*) as n
       from gene
      group by analysis_id,name
      order by analysis_id),
  'Prediction transcripts' => qq(
     select analysis_id, '', count(*) as n
       from prediction_transcript as f
      group by analysis_id
      order by analysis_id),
  'Transcript' => qq(
     select f.analysis_id, concat( ifnull(f.biotype,    '--'), ' : ',
                    ifnull(f.status, '--'), ' : ',
                    ifnull(a.logic_name, '--'), ' : ',
                    ifnull(g.biotype,    '--'), ' : ',
                    ifnull(g.source,     '--'), ' : ',
                    ifnull(g.status, '--') 
            ) as name,
            count(*) as n
       from transcript as f, gene as g left join analysis as a on g.analysis_id = a.analysis_id
      where g.gene_id = f.gene_id 
      group by f.analysis_id, name
      order by f.analysis_id, name),
  'Repeats' => qq(
     select rf.analysis_id, rc.repeat_type as name, count(*) as n
       from repeat_consensus as rc, repeat_feature as rf
      where rc.repeat_consensus_id = rf.repeat_consensus_id
      group by rf.analysis_id, rc.repeat_type
      order by analysis_id,repeat_type)
);

#%queries = map { ($_=>$queries{$_}) } ('Gene features');

my @species = @ARGV ? @ARGV : @{$SD->ENSEMBL_DATASETS};

my $x = XHTML::Validator->new();

print join "\t",
  "Species", "DB", "Type", "Logic name", "ID", "Sub-type", "Count",
  "Displayable", "Label", "Description", "Web", "Error\n";
foreach my $sp ( @species ) {
  my $tree = $SD->{_storage}{$sp};
  foreach my $db_name ( qw(DATABASE_CORE DATABASE_VEGA DATABASE_OTHERFEATURES DATABASE_CDNA) ) {
    next unless $tree->{'databases'}->{$db_name}{'NAME'};
    my $dbh = db_connect( $tree, $db_name );
use Data::Dumper;
    $tree->{'databases'}->{$db_name}{'tables'}=undef;
    $tree->{'databases'}->{$db_name}{'meta_info'}=undef;
    my $analyses = $dbh->selectall_hashref(
      'select a.analysis_id, a.logic_name, ad.display_label,
              ad.displayable, ad.web_data, ad.description
         from analysis as a left join analysis_description as ad on
              a.analysis_id = ad.analysis_id', 'analysis_id'
    );
    foreach ( keys %$analyses ) {
      $analyses->{$_}{'description'} =~ s/\s+/ /g; $analyses->{$_}{'description'} =~ s/^ //; $analyses->{$_}{'description'} =~ s/ $//;
      $analyses->{$_}{'web_data'}    =~ s/\s+/ /g; $analyses->{$_}{'web_data'}    =~ s/^ //; $analyses->{$_}{'web_data'}    =~ s/ $//;
      $analyses->{$_}{'valid'}       = $x->validate( $analyses->{$_}{'description'} );
      $analyses->{$_}{'valid'}       =~ s/\s+/ /g; $analyses->{$_}{'valid'}       =~ s/^ //; $analyses->{$_}{'valid'}       =~ s/ $//;
    }
    $analyses->{0} = { 'analysis_id'=>0,'logic_name'=>'fake_coord','display_label'=> 'Co-ordinate systems', 'web_data'=>'{}', 'description' => 'Fake', 'displayable' => 0, 'valid' => 1 };
    my %used     = map {($_=>1)} keys %$analyses;

    foreach my $K ( sort keys %queries ) {
      my $results = $dbh->selectall_arrayref( $queries{$K} );
      next unless $results && @{$results};
      foreach( @{$results} ) {
        my $a = $analyses->{$_->[0]}||{};
        print join "\t", $sp, $db_name, $K,
          $a->{'logic_name'}||'-missing-',
          $_->[0],
          $_->[1],
          $_->[2],
          $a->{'displayable'} ? 'YES' : exists($a->{'displayable'})?'NO':'--',
          $a->{'display_label'},
          $a->{'description'},
          $a->{'web_data'},
          "$a->{'valid'}\n";
        delete $used{$_->[0]};
      }
    }
    foreach( sort keys %used ) {
      my $a = $analyses->{$_};
      print join "\t", $sp, $db_name, 'ununsed',
        $a->{'logic_name'}||'-missing-',
        $_,
        "",
        0,
        $a->{'displayable'} ? 'YES' : exists($a->{'displayable'})?'NO':'--',
        $a->{'display_label'},
        $a->{'description'},
        $a->{'web_data'},
        "$a->{'valid'}\n";
    }
  }
}

sub db_connect {
  ### Connects to the specified database
  ### Arguments: configuration tree (hash ref), database name (string)
  ### Returns: DBI database handle
  my $tree    = shift @_ || die( "Have no data! Can't continue!" );
  my $db_name = shift @_ || confess( "No database specified! Can't continue!" );

  my $dbname  = $tree->{'databases'}->{$db_name}{'NAME'};
  if($dbname eq '') {
    warn( "No database name supplied for $db_name." );
    return undef;
  }

  #warn "Connecting to $db_name";
  my $dbhost  = $tree->{'databases'}->{$db_name}{'HOST'};
  my $dbport  = $tree->{'databases'}->{$db_name}{'PORT'};
  my $dbuser  = $tree->{'databases'}->{$db_name}{'USER'};
  my $dbpass  = $tree->{'databases'}->{$db_name}{'PASS'};
  my $dbdriver= $tree->{'databases'}->{$db_name}{'DRIVER'};
  my ($dsn, $dbh);
  eval {
    if( $dbdriver eq "mysql" ) {
      $dsn = "DBI:$dbdriver:database=$dbname;host=$dbhost;port=$dbport";
      $dbh = DBI->connect(
        $dsn,$dbuser,$dbpass, { 'RaiseError' => 1, 'PrintError' => 0 }
      );
    } else {
      print STDERR "\t  [WARN] Can't connect using unsupported DBI driver type: $dbdriver\n";
    }
  };

  if( $@ ) {
    print STDERR "\t  [WARN] Can't connect to $db_name\n", "\t  [WARN] $@";
    return undef();
  } elsif( !$dbh ) {
    print STDERR ( "\t  [WARN] $db_name database handle undefined\n" );
    return undef();
  }
  return $dbh;
}

