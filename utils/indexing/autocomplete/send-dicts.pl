#! /usr/bin/env perl

use warnings;
use strict;

my $uid = getpwuid($<);
die "You must be www-ens\n" unless $uid eq 'www-ens';
unless(-e "dict.txt" and -e "dict2.txt" and -e "dict3.txt") {
  die "dict.txt etc must be in cwd\n";
}
print <<EOF;
Enter machines to send dict files to:
  Can omit initial ensweb-solr. Also for slave machines can omit slave.
  eg. dev-01 03 04 = ensweb-solrdev-01 ensweb-solrslave-03 ensweb-solrslave-04
EOF

my $input = <STDIN>;

my @servers = map {
  $_ = "slave-$_" unless /-/;
  $_ = "ensweb-solr$_";
  $_;
} grep { /\w/ } split(' ',$input);

die "No servers specified\n" unless @servers;
print "Sending to these machines. Correct? [y/n]\n";
print join("\n",map { "  $_" } @servers,)."\n";
my $yn = <STDIN>;
die "No confirmation\n" unless $yn =~ /^[Yy]/;
foreach my $server (@servers) {
  print "Sending to $server\n"; 
  system("scp dict*.txt ens-srch\@$server:/www/java/solr/sanger/ensembl_core/conf") && die "Copy failed: $!\n";
  foreach my $final (qw(spell suggest directlink)) {
    my $port;
    system("nc -z $server.internal.sanger.ac.uk 8000") or $port = 8000;
    system("nc -z $server.internal.sanger.ac.uk 8001") or $port = 8001;
    die "No port $port\n" unless $port;
    print "Starting build of dictionary '$final' on $server port $port\n";
    my $url = "http://$server.internal.sanger.ac.uk:$port/solr-sanger/ensembl_core/$final?spellcheck=true&spellcheck.q=xxx&spellcheck.build=true";
    system("curl -s -f '$url' >/dev/null") && die "Could not start curl ( $url )";
  }
}

1;

