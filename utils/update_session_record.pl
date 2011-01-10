#!/usr/local/bin/perl

use strict;

use DBI;
use File::Basename qw(dirname);
use FindBin qw($Bin);
use JSON qw(to_json);
use Data::Dumper;
use Time::HiRes;
$Data::Dumper::Indent   = 0;
$Data::Dumper::Maxdepth = 0;

BEGIN {
  my $serverroot = dirname($Bin);
  unshift @INC, "$serverroot/conf", $serverroot;
  
  require SiteDefs;
  
  unshift @INC, $_ for @SiteDefs::ENSEMBL_LIB_DIRS;

  require EnsEMBL::Web::Hub;
}

my $time = Time::HiRes::time;
my $hub = new EnsEMBL::Web::Hub;
my $sd  = $hub->species_defs;

my $dbh = DBI->connect(
  sprintf('DBI:mysql:database=%s;host=%s;port=%s', $sd->ENSEMBL_USERDB_NAME, $sd->ENSEMBL_USERDB_HOST, $sd->ENSEMBL_USERDB_PORT),
  $sd->ENSEMBL_USERDB_USER, $sd->ENSEMBL_USERDB_PASS, { AutoCommit => 0 }
);

$dbh->do('CREATE TABLE session_record_tmp LIKE session_record');
$dbh->do('INSERT INTO session_record_tmp SELECT * FROM session_record');
$dbh->commit;

my $sth = $dbh->prepare('SELECT session_id, code, data FROM session_record_tmp WHERE type="script"');
$sth->execute;

my $i;

foreach (@{$sth->fetchall_arrayref}) {
  my ($session_id, $code, $data_string) = @$_;
  
  my $data = eval $data_string;
  
  if ($data->{'image_configs'}) {
    foreach my $ic_code (grep scalar keys %{$data->{'image_configs'}->{$_}}, keys %{$data->{'image_configs'}}) {
      my $image_config = Dumper $data->{'image_configs'}->{$ic_code};
      $image_config =~ s/^\$VAR1 = //;
      
      if ($ic_code =~ /^genesnpview_(gene|transcript)$/ && $code eq 'Gene::Splice') {
        $ic_code = "genespliceview_$1";
      }
      
      $dbh->do(sprintf "INSERT INTO session_record_tmp VALUES ('', $session_id, 0, 'image_config', '$ic_code', %s, now(), now(), '0000-00-00 00:00:00')", $dbh->quote($image_config));
      $i++;
    }
  }
  
  if ($data->{'diffs'} && scalar keys %{$data->{'diffs'}}) {
    my $view_config = Dumper $data->{'diffs'};
    $view_config =~ s/^\$VAR1 = //;
    
    $dbh->do(sprintf "INSERT INTO session_record_tmp VALUES ('', $session_id, 0, 'view_config', '$code', %s, now(), now(), '0000-00-00 00:00:00')", $dbh->quote($view_config));
    $i++;
  }
  
  $dbh->commit unless $i % 5000;
}

$dbh->commit;
$dbh->do('DELETE FROM session_record_tmp WHERE type="script"');
$dbh->do("ALTER TABLE session_record_tmp modify type enum('view_config','image_config','das','tmp','url','upload','message','custom_page','blast','bam') DEFAULT 'url'");
$dbh->do('RENAME TABLE session_record TO session_record2, session_record_tmp TO session_record');
#$dbh->do('DROP TABLE session_record2'); ********* DO THIS MANUALLY ONCE YOU'VE CHECKED EVERYTHING IS OK *********
$dbh->disconnect;