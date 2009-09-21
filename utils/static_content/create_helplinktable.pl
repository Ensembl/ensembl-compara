#!/usr/local/bin/perl

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
  eval{ require SiteDefs };
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
