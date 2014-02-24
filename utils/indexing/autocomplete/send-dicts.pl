#! /usr/bin/env perl

use warnings;
use strict;

my $proxy_machine = "wwwcache.sanger.ac.uk";
$ENV{'http_proxy'} = "http://$proxy_machine:3128";

my $uid = getpwuid($<);
die "You must be www-ens\n" unless $uid eq 'www-ens';
unless(-e "dict.txt" and -e "dict2.txt" and -e "dict3.txt") {
  die "dict.txt etc must be in cwd\n";
}
print <<EOF;
Enter machines to send dict files to:
  Can omit initial ensweb-solr. Also for slave machines can omit slave.
  Mirrors can be specified with "e<num>" cluster name (eg "e75").
  Individual mirror servers cannot be updated (at present).
  eg. dev-01 03 04 = ensweb-solrdev-01 ensweb-solrslave-03 ensweb-solrslave-04
EOF

my $input = <STDIN>;

my @servers = grep { /\w/ } split(' ',$input);

die "No servers specified\n" unless @servers;

# Mirrors
my (@clusters,@mirrors);
@servers = grep { if(/^([a-z]\d+)$/) { push @clusters,$1; 0; } else { 1; } } @servers;
if(@clusters) {
  foreach my $cluster (@clusters) {
    print "  Involves mirror machines. Retireving mirror info. Please wait.\n";
    open(MIRROR,"../../../../sanger-plugins/utils/mirrors/bin/current-mirror-backend-ips.pl $cluster |") or die "Cannot get mirror ips";
    while(<MIRROR>) {
      my @line = split(' ',$_);
      push @mirrors,$line[1] if $line[3] eq 'solr';
    }
    close MIRROR;
  }
}
my $keys = "-i ~/.ssh/id_dsa -i ~/.ssh/uswest-web -i ~/.ssh/ensweb-key -i ~/.ssh/e59-asia.pem";

# Local
@servers = map {
  $_ = "slave-$_" unless /-/;
  $_ = "ensweb-solr$_.internal.sanger.ac.uk";
  $_;
} @servers;

#
push @servers,@mirrors;
print "Sending to these machines. Correct? [y/n]\n";
print join("\n",map { "  $_" } @servers)."\n";
my $yn = <STDIN>;
die "No confirmation\n" unless $yn =~ /^[Yy]/;
foreach my $server (@servers) {
  my $user = "";
  $user = "ens-srch\@" if $server =~ /ensweb-/;
  print "Sending to $server\n"; 
  system("scp $keys dict*.txt $user$server:/www/java/solr/sanger/ensembl_core/conf") && die "Copy failed: $!\n";
  foreach my $final (qw(spell suggest directlink)) {
    my $port;
    system("curl -f -m 2 http://$server:8000/solr-sanger/ >/dev/null 2>&1") or $port = 8000;
    system("curl -f -m 2 http://$server:8001/solr-sanger/ >/dev/null 2>&1") or $port = 8001;
    die "No port\n" unless $port;
    print "Starting build of dictionary '$final' on $server port $port\n";
    my $url = "http://$server:$port/solr-sanger/ensembl_core/$final?spellcheck=true&spellcheck.q=xxx&spellcheck.build=true";
    system("curl -s -f '$url' >/dev/null") && die "Could not start curl ( $url )";
  }
}

1;

