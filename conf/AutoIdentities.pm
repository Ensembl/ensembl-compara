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

### The script pushes a subroutine to ENSEMBL_IDENTITIES that goes through the ENSEMBL_SERVERROOT and
### the machine hostname to generate possible identities that can be used to match in AutoPlugins.pm

use strict;
use warnings;

use Sys::Hostname;
use List::MoreUtils qw(uniq);
use Cwd qw(abs_path);

sub follow_paths {
  ## Populates the $out array with all the possible paths matching to the given $route
  ## @param (Arrayref) Base path
  ## @param (String) Path to be split into sub paths
  ## @param (Arrayref) Output matching path
  my ($base, $route, $out) = @_;

  my $here = abs_path("/".(join("/", @$base)));
  push @$out, $here if @$base;
  if(@$route) {
    my @new_route = @$route;
    my @new_base  = (@$base, shift @new_route);

    # Recursively get all the sub paths
    follow_paths(\@new_base, \@new_route, $out);
  }
}

sub add_symlinks {
  ## Adds symlinks to the $out array that are matching with any of the literal paths already present in the $out
  ## @param (Arrayref) Literal paths array - the symlink paths get added to the same array
  ## @param (Hashref) Symlinks already done - needed to avoid infinite recursion
  my ($out, $done,$depth) = @_;

  return unless $depth;
  foreach my $here (@$out) {
    if (opendir(my $dir, $here)) {
      foreach my $link (grep { !$done->{$_} } grep -l, map "$here/$_", readdir($dir)) {
        next if $link =~ /latest\/latest/; #stop expanding latest symlinks
        my $dest = readlink($link);
           $dest &&= abs_path($dest =~ m!^/! ? $dest : "$here/$dest");
        next if !$dest; # ignore broken links
        next if $here =~ /^\Q$dest\E(\/|$)/; # prevent infinite loop in case symlink points to a parent dir
        foreach my $matching_dest (grep { $_ eq $dest } @$out) {
          push @$out, map { $_ =~ s/^\Q$matching_dest\E/$link/r } grep { m/^\Q$matching_dest\E/ } @$out;
          $done->{$link} = 1;
          add_symlinks($out, $done,$depth-1);
        }
      }
      closedir $dir;
    }
  }
}

$SiteDefs::ENSEMBL_IDENTITIES = [
  # Standard UNIX path
  sub {
    my $hostname  = Sys::Hostname::hostname;
    my @path      = grep $_, split m!/!, $SiteDefs::ENSEMBL_SERVERROOT;
    my (@paths, @out);
    follow_paths([],\@path,\@paths);
    add_symlinks(\@paths, {},5);
    foreach my $host (uniq('', $hostname, $hostname =~ s/\..*//r)) {
      push @out, map {"unix:$host:$_"} @paths;
      push @out, "host:$host";
    }
    push @out, map { "path:$_" } @paths;
    @out = sort @out;
    return \@out;
  }
];

1;
