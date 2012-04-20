#!/usr/bin/env perl

##############################################################################
#
# SCRIPT TO CHECK THAT E::W::OldLinks IS UP-TO-DATE
#
##############################################################################


##---------------------------- CONFIGURATION ---------------------------------

use strict;
use warnings;

use FindBin qw($Bin);
use File::Basename qw( dirname );

use vars qw( $SERVERROOT $SCRIPT_ROOT );

BEGIN{
  $SCRIPT_ROOT = dirname( $Bin );
  ($SERVERROOT = $SCRIPT_ROOT) =~ s#/utils##;

  unshift @INC, "$SERVERROOT/conf";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

use EnsEMBL::Web::Root;
use EnsEMBL::Web::Tree;
use EnsEMBL::Web::Hub;
use EnsEMBL::Web::Builder;
use EnsEMBL::Web::Document::Page::Dynamic;
use EnsEMBL::Web::OldLinks;

my $hub = EnsEMBL::Web::Hub->new();
my $builder = EnsEMBL::Web::Builder->new({'hub'=>$hub});

my @object_types;
while (my($k, $v) = each (%{$hub->species_defs->OBJECT_TO_SCRIPT})) {
  push @object_types, $k if ($v eq 'Page');
} 

my $old_links;
while (my($k, $v) = each (%EnsEMBL::Web::OldLinks::mapping)) {
  foreach my $mapping (@$v) {
    $old_links->{$mapping->{'type'}}{$mapping->{'action'}}++;
  }
}

foreach my $type (@object_types) {
  my $conf_module = 'EnsEMBL::Web::Configuration::'.$type;
  if (EnsEMBL::Web::Root::dynamic_use(undef, $conf_module)) {
    ## We need to fake a web page so that we can get the LH menu
    my $page = EnsEMBL::Web::Document::Page::Dynamic->new({
      hub          => $hub,
      species_defs => $hub->species_defs,
    });;
    my $data = {
      tree         => new EnsEMBL::Web::Tree,
      default      => undef,
      action       => undef,
      configurable => 0,
      page_type    => 'Dynamic',
    };
    my $conf = $conf_module->new($page, $hub, $builder, $data);
    my @nodes = $conf->tree->nodes;
    foreach my $node (@nodes) {
      my $action = $node->id;
      if ($old_links->{$type}{$action}) {
        #warn "... PAGE $type/$action has a mapping";
      }
      else {
        warn "!!! NO MAPPING FOR PAGE $type/$action";
      }
    }
    warn ".........";
  }
}


exit;

__END__

=head1 NAME

check_oldlinks.pl

=head1 SYNOPSIS

Written by Anne Parker <ap5@sanger.ac.uk>

=cut

1;
