#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

use EnsEMBL::Root;
use EnsEMBL::Web::Tree;
use EnsEMBL::Web::Hub;
use EnsEMBL::Web::Builder;
use EnsEMBL::Web::Document::Page::Dynamic;
use EnsEMBL::Web::OldLinks;

my $hub     = new EnsEMBL::Web::Hub;
my $builder = new EnsEMBL::Web::Builder({ hub => $hub });
my (@object_types, %old_links);

while (my ($k, $v) = each (%{$hub->species_defs->OBJECT_TO_SCRIPT})) {
  push @object_types, $k if $v eq 'Page' && $k ne 'Tools' && $k ne 'Search';
} 

my %mappings;

## Convert real URLs into node keys for comparison matching
while (my ($k, $v) = each (%EnsEMBL::Web::OldLinks::archive_mapping)) {
  my ($type, $action, $function) = split('/', $k);
  $action .= '_'.$function if $function;
  $mappings{$type.'/'.$action} = 1;
}

my $errors;

foreach my $type (@object_types) {
  my $conf_module = "EnsEMBL::Web::Configuration::$type";
  
  if (EnsEMBL::Root::dynamic_use(undef, $conf_module)) {
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
      next if $node->data->{'external'};
      next if $action eq 'Output' || $action eq 'Unknown';

      my $route = join('/', $type, $action);
      
      unless ($mappings{$route}) { 
        print "!!! NO MAPPING FOR PAGE $route\n";
        $errors++;
      }
    }
  }
}

print "\nALL PAGES HAVE BEEN MAPPED!\n" unless $errors;

exit;

__END__

=head1 NAME

check_oldlinks.pl

=head1 SYNOPSIS

Written by Anne Parker <ap5@sanger.ac.uk>

=cut

1;
