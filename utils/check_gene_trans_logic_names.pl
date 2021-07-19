#!/usr/bin/env perl
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


# Runs across all databases to look for transcripts / genes that are not configured
# to be coloured correctly in COLOUR.ini
# Will also report on gene/transcript logic_names that are present in more than one
# database type for a species


use FindBin qw($Bin);
use File::Basename qw(dirname);
use Data::Dumper;
use strict;
use warnings;
no warnings 'uninitialized';

BEGIN {
   unshift @INC, "$Bin/../conf";
   unshift @INC, "$Bin/..";
   eval { require SiteDefs; SiteDefs->import; };
   if ($@) { die "Can't use SiteDefs.pm - $@\n"; }
   map { unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS; 
}

use EnsEMBL::Web::SpeciesDefs;

my $SD = new EnsEMBL::Web::SpeciesDefs;

my @species = @ARGV ? @ARGV : @{$SD->multi_hash->{'ENSEMBL_DATASETS'}};
my $sitetype = $SD->ENSEMBL_SITETYPE;
my ($colour_ini_keys, $logic_names);

foreach my $sp ( @species ) {
  print "$sp\n";
  my $tree = $SD->{_storage}{$sp};
  foreach my $db_name ( qw(DATABASE_CORE DATABASE_OTHERFEATURES DATABASE_CDNA) ) {
    next unless $tree->{'databases'}->{$db_name}{'NAME'};
    my %anal_descs;
    print "  $db_name\n";
    my $dbh = db_connect( $tree, $db_name );


    #get all transcript and gene analysis details
    my $sql = qq(select distinct a.logic_name, a.analysis_id, ad.web_data, g.biotype
                    from gene g, analysis a, analysis_description ad 
                   where g.analysis_id = a.analysis_id
                     and a.analysis_id = ad.analysis_id
                     and ad.displayable = 1);
    my $sth = $dbh->prepare($sql);
    $sth->execute;
    my $g_analyses = $sth->fetchall_arrayref();
    $anal_descs{'gene'} = $g_analyses;


    $sql = qq(select distinct a.logic_name, a.analysis_id, ad.web_data, t.biotype
                from transcript t, analysis a, analysis_description ad 
               where t.analysis_id = a.analysis_id
                 and a.analysis_id = ad.analysis_id
                 and ad.displayable = 1);
    $sth = $dbh->prepare($sql);
    $sth->execute;
    my $t_analyses = $sth->fetchall_arrayref();
    $anal_descs{'transcript'} = $t_analyses;

    foreach my $feat (keys %anal_descs) {
      my $analyses = $anal_descs{$feat};
    LN:
      foreach my $lnbt (@$analyses) {
	my $dets = {
	  biotype    => $lnbt->[3],
	  logic_name => $lnbt->[0],
	};
	my $wd      = eval($lnbt->[2]);
	if (exists($wd->{'gene'}{'do_not_display'})) {
	  next LN;
	}
	my ($db_key,$ini_key);
	if ($db_key = $wd->{'colour_key'}) {

	  #parse correct value for web_data colour key
	  while ($db_key =~ /(\[*\w+\]*)/g) {
	    my $key = $1;
	    next if $key eq '_';
	    if ($key =~ /\[+(\w+)\]+/g) {
	      $key = $1;
	      $key =~ s/^_//;
	      $key =~ s/_$//;
	      print STDERR "[WARN] Place holder $key not parsed " if (! exists $dets->{$key});
	      $ini_key = $ini_key ? $ini_key.'_'.$dets->{$key} : $dets->{$key};
	    }
	    else {
	      $key =~ s/^_//;
	      $key =~ s/_$//;
	      $ini_key = $ini_key ? $ini_key.'_'.$key : $key;
	    }
	  }
	}
	else {
	  #if there is no colour_key entry then biotype is used
	  $ini_key = $dets->{'biotype'};
	}

	#store
	$colour_ini_keys->{$dets->{'biotype'}}{lc($ini_key)}{$sp}{$db_name}{$feat}{'logic_name'} = $dets->{'logic_name'};
  if($dets->{'logic_name'} ne 'gsten') {
    push @{$logic_names->{$dets->{'logic_name'}}{$sp}}, $db_name unless grep {$_ eq $db_name} @{$logic_names->{$dets->{'logic_name'}}{$sp}};
  }
      }
    }
  }
}

#any non-configured keys ?
my $colour_conf = $SD->colour('gene');
foreach my $bt (keys %$colour_ini_keys) {
  foreach my $key (keys %{$colour_ini_keys->{$bt}}) {
    if (! $colour_conf->{$key} ) {
      print "biotype $bt (colour key = $key) is not configured in COLOUR.INI. Feature present in ", join ' ', Dumper($colour_ini_keys->{$bt}{$key}),"\n";
    }
  }
}

#any duplicated logic_names ?
foreach my $ln (keys %$logic_names ) {
  foreach my $sp (keys %{$logic_names->{$ln}}) {
    if (scalar (@{$logic_names->{$ln}{$sp}} > 1)) {
      print "Logic_name $ln is displayed from more than one database for $sp:", join ' ', @{$logic_names->{$ln}{$sp}},". This might be OK but you should check\n";
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
