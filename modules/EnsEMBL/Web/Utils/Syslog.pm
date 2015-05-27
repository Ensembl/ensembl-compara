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

package EnsEMBL::Web::Utils::Syslog;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(syslog);

use SiteDefs;

sub syslog {
  my ($str) = @_;

  my $cmd = $SiteDefs::SYSLOG_COMMAND; 
  return unless $cmd;
  if(ref($cmd) eq 'CODE') {
    $cmd->($str);
  } else {
    $cmd =~ s/\[\[TEXT\]\]/$str/g;
    system($cmd);
  }
}

1;

