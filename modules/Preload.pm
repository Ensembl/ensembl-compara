=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package Preload;

use strict;
use warnings;

# This file potentially contains a load of statements for modules which
# are needed by worker processes to service requests. These get loaded at
# child-init time, which is before a request comes in, so stops the first
# request being delayed. This seems to affect 20%-25% of requests, so is
# significant.
#

use EnsEMBL::Root;
use EnsEMBL::Web::Utils::DynamicLoader;
use EnsEMBL::Web::Exceptions;
use Image::Minifier;

our $REALSTDERR;
sub preload_capture_stderr {
  open($REALSTDERR,'>&STDERR');
  close STDERR;
  open(STDERR,">>$SiteDefs::ENSEMBL_LOGDIR/preload-errors.log");
}

sub preload_release_stderr {
  open(STDERR,'>&',$REALSTDERR);
  close $REALSTDERR;
}

sub load {
  preload_capture_stderr;
  eval {
    EnsEMBL::Web::Utils::DynamicLoader::dynamic_use($_[0],1);
  };
  preload_release_stderr;
}

our $MOANED = 0;
sub moan {
  return if $MOANED;
  if(-s "$SiteDefs::ENSEMBL_LOGDIR/preload-errors.log") {
    $MOANED = 1;
    warn <<"EOF";

===
Some modules failed to preload. They will probably fail when they are
used "for real" by this website. For details see
$SiteDefs::ENSEMBL_LOGDIR/preload-errors.log
This is a probably not a problem with preload: it just identified a
problem with other modules, earlier than otherwise would have happened.
This does not in itself stop the site starting but you might want to
take a look, as advance notice about what pages may be broken here.
===

EOF
  }
}

sub import {
  $MOANED = 1 if -e "$SiteDefs::ENSEMBL_LOGDIR/preload-errors.log";

  if(open(PRELOADS,"$SiteDefs::ENSEMBL_WEBROOT/conf/preload_modules.txt")) {
    while(my $x = <PRELOADS>) {
      chomp $x;
      next unless $x;
      load($x,1);
    }
    close PRELOADS;
  } else {
    warn "Not preloading\n";
  }
  Image::Minifier::kit_complete;
  Image::Minifier::preload_config;
  moan;
}

sub preload_orm {
  ## Preloads the code provided as callback only if orm db connections for the given db types is valid is valid
  my ($plugin, $db_types, $on_success_callback) = @_;
  my @error;
  my @dbh;

  eval {
    require ORM::EnsEMBL::Rose::DbConnection;
  };

  if ($@) {
    @error = ($@);
  } else {

    foreach my $db_type (@$db_types) {
      my $db = ORM::EnsEMBL::Rose::DbConnection->new('type' => $db_type);

      try {
        push @dbh, $db->init_dbh;
      } catch {
        push @error, $_->message(1);
      };
    }
  }

  if (@dbh) {
    $on_success_callback->(@dbh);
  } else {
    warn sprintf "Preload Error: Not preloading '%s' plugin for the reason(s):\n", $plugin;
    warn "  $_\n" for @error;
  }
}

1;
