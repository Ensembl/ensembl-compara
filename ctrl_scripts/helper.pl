# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2022] EMBL-European Bioinformatics Institute
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
# helper for ctrl scripts

use strict;
use warnings;

use FindBin qw($Bin);

BEGIN { require "$Bin/../conf/includeSiteDefs.pl" }

sub warn_line {
  warn sprintf "%s\n", '=' x 78;
}

sub warn_string {
  warn sprintf " %s\n", @_;
}

sub die_string {
  warn_string(@_);
  exit 1;
}

sub before_after_hooks {
  ## Walk through the plugin tree and see if there's 'ctrl_scripts/*' in there
  ## any files starting with 00_start* to 49_start* will be executed before apache
  ## any files starting with 50_start* to 99_start* will be executed after
  ## same happens with stop_server
  ## all scripts must be perl scripts, as they are 'required'
  my $action = shift;
  my (@before, @after);

  my @plugins = reverse @{$SiteDefs::ENSEMBL_PLUGINS || []};

  while (my ($dir, $name) = splice @plugins, 0, 2) {
    $dir = "$dir/ctrl_scripts";

    if (opendir DIR, $dir) {
      my @files = readdir(DIR);
      push @before, map "$dir/$_", grep /^[0-4]?[0-9]_$action/, @files;
      push @after,  map "$dir/$_", grep /^[5-9][0-9]_$action/,  @files;
      closedir DIR;
    }
  }
  @before = sort @before;
  @after = sort @after;
  return (\@before, \@after);
}

sub run_script {
  ## It's like running a perl script with system but as a part of the same script, with INC maintained
  my ($script, $argv, $err_ref) = @_;

  local @ARGV = @{$argv || []};
  local $@    = undef;

  my $return;

  if (-f $script && -r $script) {
    eval '
      no warnings qw(redefine);
      require subs;
      subs->import(qw(exit));
      sub exit(;$) {
        die("EXIT:".($_[0] << 8));
      }
    ';
    do $script;
    if ($@) {
      if ($@ =~ /^EXIT:(\d+)\s/) {
        $return = $1;
      } else {
        $$err_ref = $@;
      }
    }
  } else {
    $$err_ref = "Not a script: $script\n";
  }
  return $return || 0;
}

1;
