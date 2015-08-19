use strict;
use warnings;

use Sys::Hostname;

use SiteDefs;

sub follow_paths {
  my ($base,$route,$out) = @_;

  my $here = "/".(join("/",@$base));
  push @$out,$here if @$base;
  if(@$route) {
    my @new_route = @$route;
    my @new_base = (@$base,(shift @new_route));
    # Literal path
    follow_paths(\@new_base,\@new_route,$out);
    # Any accompanying symlinks?
    if(opendir(DIR,$here)) {
      foreach my $link (grep { -l "$here/$_" } readdir(DIR)) {
        my $dest = readlink("$here/$link");
        $dest = "$here/$dest" unless $dest =~ m!^/!;
        my $there = "/".(join("/",@new_base));
        if($dest eq $there) {
          my @sym_base = (@$base,$link);
          follow_paths(\@sym_base,\@new_route,$out);
        }
      }
      closedir DIR;
    }
  }
}

$SiteDefs::ENSEMBL_IDENTITIES = [
  # Standard UNIX path
  sub {
    my $host = Sys::Hostname::hostname;
    my @path = split(m!/!,$SiteDefs::ENSEMBL_SERVERROOT);
    shift @path;
    my @out;
    foreach my $host (('',Sys::Hostname::hostname)) {
      my @paths;
      follow_paths([],\@path,\@paths);
      push @out,(map {"unix:$host:$_"} @paths);
    }
    return \@out;
  },
];

1;
