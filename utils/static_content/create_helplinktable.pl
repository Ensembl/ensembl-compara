#!/usr/local/bin/perl
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


use strict;
use warnings;
use Carp;
use Data::Dumper;
use FindBin qw($Bin);
use File::Basename qw( dirname );

use Pod::Usage;
use Getopt::Long;

my ( $SERVERROOT, $help, $info, $date);

BEGIN{
  &GetOptions( 
	      'help'      => \$help,
	     );
  
  pod2usage(-verbose => 2) if $info;
  pod2usage(1) if $help;
  
  $SERVERROOT = dirname( $Bin );
  $SERVERROOT =~ s#/utils##;
  unshift @INC, "$SERVERROOT/conf";
  eval{ require SiteDefs; SiteDefs->import; };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

use EnsEMBL::Web::Data::View;
use EnsEMBL::Web::Data::HelpLink;

print "\n\n";

my @records = EnsEMBL::Web::Data::View->search({'status' => 'live'});

foreach my $r (@records) {
  my $link = EnsEMBL::Web::Data::HelpLink->new();
  my $url = $r->ensembl_object.'/'.$r->ensembl_action;
  $link->page_url($url);
  $link->help_record_id($r->id);
  warn Dumper($link);
  $link->save;
}
