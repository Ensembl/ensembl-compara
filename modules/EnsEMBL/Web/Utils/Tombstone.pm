=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Utils::Tombstone;

### We have a lot of code that is potentially obsolete, but it's difficult and
### time-consuming to work out if it's actually still in use somewhere. 
### This simple module allows you to tag any method and log the calling of 
### that method.

### Usage: in any method, add the following line before any others:
### tombstone('00-00-0000', 'yourname);
### substituting the current date. Don't forget to add a 'use' line
### to the module or its parent!

### One log file is created per username and date combination, and to 
### prevent these files from growing enormous, a size limit is set - 
### generally we don't care how often a call is made, only that it is called

### Code based on Lokku::Tombstone by Lokku Ltd, adapted to Ensembl environment

use strict;
use warnings;

use Devel::StackTrace;
use JSON qw(to_json);
use Fcntl qw(:flock);

use Exporter qw(import);
our @EXPORT_OK = qw(tombstone);

use SiteDefs;

sub tombstone {
  my ($date, $username) = @_;

  ## Just in case the parameters were omitted...
  $username ||= $SiteDefs::ENSEMBL_USER;
  unless ($date) {
    my ($sec, $min, $hour, $day, $month, $year) = gmtime;
    $date = sprintf('%s-%s-%s', $day, $month+1, $year+1900);
  }

  ## Create/open individual log file for this user and date
  my $log_dir   = $SiteDefs::ENSEMBL_LOGDIR;
  $log_dir =~ s|(?<!/)$|/|;
  my $log_file  = $log_dir.sprintf('tombstone_%s_%s.log', $username, $date);
  my $log       = open(LOG, ">>$log_file") or do { 
                    warn "!!! Couldn't open tombstone log $log_file: $!"; 
                    return; 
                  }; 
  ## Check we haven't exceeded the file allocation for this tombstone
  my $current_size  = tell(LOG);
  my $max_size      = $SiteDefs::MAX_TOMBSTONE_LOG_SIZE || 10 * 1024 * 1024; ## 10MB
  if ($current_size == -1) {
    warn "!!! Tombstone tell failed: $!";
    return;
  } elsif ($current_size >= $max_size) {
    warn "!!! Tombstone log size exceeded!";
    return;
  }

  ## IMPORTANT: Don't break if can't get a lock on log file!
  flock(LOG, LOCK_EX | LOCK_NB) or return; 

  ## Get the stacktrace for the method call
  my $StackTrace  = Devel::StackTrace->new(no_args => 1);
  my $FirstFrame  = $StackTrace->frame(1);
  my $SecondFrame = $StackTrace->frame(2) || $StackTrace->frame(1);

  ## Turn the information into a JSON string and write it to the log
  my $log_entry = {
                    gmtime      => [gmtime],
                    stack_trace => $StackTrace->as_string(),
                    author      => $username,
                    rip         => $date,
                    filename    => $FirstFrame->filename,
                    line        => $FirstFrame->line,
                    subroutine  => $SecondFrame->subroutine,
                  };
  my $eval_log = eval {
                        my $string = to_json($log_entry)."\n";
                        print LOG $string 
                            or warn "Could not print to '$log_file': $!";
                        1;
                  };
  if (!$eval_log || $@) {
    warn $@;
  }

  close LOG or warn "Could not close '$log_file': $!";;
  return;
}

1;

