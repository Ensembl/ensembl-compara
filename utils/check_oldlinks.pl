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
use File::Basename qw(dirname);

use vars qw( $SERVERROOT $SCRIPT_ROOT );

BEGIN {
  $SCRIPT_ROOT = dirname($Bin);
  ($SERVERROOT = $SCRIPT_ROOT) =~ s#/utils##;

  unshift @INC, "$SERVERROOT/conf";
  eval { require SiteDefs };
  die "Can't use SiteDefs.pm - $@\n" if $@;
  unshift @INC, $_ for @SiteDefs::ENSEMBL_LIB_DIRS;
}

use EnsEMBL::Web::Root;
use EnsEMBL::Web::Tree;
use EnsEMBL::Web::Hub;
use EnsEMBL::Web::Builder;
use EnsEMBL::Web::Document::Page::Dynamic;
use EnsEMBL::Web::OldLinks;

my $hub     = new EnsEMBL::Web::Hub;
my $builder = new EnsEMBL::Web::Builder({ hub => $hub });
my (@object_types, %old_links);

while (my ($k, $v) = each (%{$hub->species_defs->OBJECT_TO_SCRIPT})) {
  push @object_types, $k if $v eq 'Page' && $k !~ /^(Info|Blast)$/;
} 

while (my ($k, $v) = each (%EnsEMBL::Web::OldLinks::mapping)) {
  $old_links{$_->{'type'}}{$_->{'action'}}++ for @$v;
}

foreach my $type (@object_types) {
  my $conf_module = "EnsEMBL::Web::Configuration::$type";
  
  if (EnsEMBL::Web::Root::dynamic_use(undef, $conf_module)) {
    ## We need to fake a web page so that we can get the LH menu
    my $page = EnsEMBL::Web::Document::Page::Dynamic->new({
      hub          => $hub,
      species_defs => $hub->species_defs,
    });
    
    my $data = {
      tree         => new EnsEMBL::Web::Tree,
      default      => undef,
      action       => undef,
      configurable => 0,
      page_type    => 'Dynamic',
    };
    
    my $conf  = $conf_module->new($page, $hub, $builder, $data);
    my @nodes = $conf->tree->nodes;
    
    foreach my $node (@nodes) {
      my $action = $node->id;
      
      next unless $node->data->{'components'};
      next if $node->data->{'no_menu_entry'};
      next if $node->data->{'external'};
      next if $action eq 'Output';
      
      if ($old_links{$type}{$action}) {
        #warn "... PAGE $type/$action has a mapping";
      } else {
        warn "!!! NO MAPPING FOR PAGE $type/$action\n";
      }
    }
    warn "\n";
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
