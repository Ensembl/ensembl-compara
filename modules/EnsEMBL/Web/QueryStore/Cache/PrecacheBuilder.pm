package EnsEMBL::Web::QueryStore::Cache::PrecacheBuilder;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(compile_precache identity);

use Fcntl qw(SEEK_SET SEEK_END SEEK_CUR :flock);
use FindBin qw($Bin);
use File::Basename qw( dirname );
use File::Find;
use Sys::Hostname;
use Digest::MD5 qw(md5_base64);

use SiteDefs;
use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_require);

sub populate_precache {
  my ($name,$here,$precache) = @_;

  push @$precache,$name if exists $here->{'precache'} and $name;
  foreach my $k (keys %$here) {
    next unless $k =~ /::$/;
    populate_precache("$name$k",$here->{$k},$precache);
  }
}

sub compile_precache {
# Load modules
  my @roots = ($SiteDefs::ENSEMBL_WEBROOT);
  for(my $i=1;$i<@{$SiteDefs::ENSEMBL_PLUGINS};$i+=2) {
    push @roots,$SiteDefs::ENSEMBL_PLUGINS->[$i];
  }
  foreach my $root (@roots) {
    my $path = "$root/modules/EnsEMBL/Web/Query";
    next unless -e $path;
    find(sub {
      my $fn = $File::Find::name;
      return unless -f $fn;
      return if $fn =~ m!/\.!;
      $fn =~ s/^$path\//EnsEMBL::Web::Query::/;
      $fn =~ s/\//::/g;
      $fn =~ s/\.pm$//;
      return if $@;
      dynamic_require($fn);
    },$path);
  }

  # Find packages
  my @precache;
  populate_precache('',\%EnsEMBL::Web::Query::,\@precache);
  return \@precache;
}

sub identity {
  my $out = md5_base64(hostname.".".$$);
  $out =~ s!/!,!g;
  return $out;
}

1;
