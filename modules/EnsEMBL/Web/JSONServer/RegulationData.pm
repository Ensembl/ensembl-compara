=head1 LICENSE
our $final = {};

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::JSONServer::RegulationData;

use strict;
use warnings;

use JSON;

use parent qw(EnsEMBL::Web::JSONServer);

sub databases { return $_[0]->hub->species_defs->get_config($_[0]->hub->param('species'), 'databases'); }
our $final = {};

sub json_data {
  my $self = shift;
  my $hub  = $self->hub;
  my $db   = $hub->database('funcgen', $hub->param('species'));

  my $db_tables     = {};

  if ( defined $self->databases->{'DATABASE_FUNCGEN'} ) {
    $db_tables      = $self->databases->{'DATABASE_FUNCGEN'}{'tables'};
  }
  my $adaptor       = $db->get_FeatureTypeAdaptor;
  my $evidence_info = $adaptor->get_regulatory_evidence_info; #get all experiment  
  
  my ($evidence, $cell_types, %all_types); 
  
  # evidence is the other name for experiment on the web interface
  # get all evidence and their corresponding evidence_type as a hash
  # e.g.: {histone -> {evidence_type -> [h2ka,...], name -> histone}, ....}
  foreach my $set (qw(core non_core)) {
    $all_types{$set} = [];
    foreach (@{$evidence_info->{$set}{'classes'}}) {
      next if $_ eq 'Transcription Factor Complex'; #looks like an API bug, this shouldnt be coming back from the API as we dont need this for web display
      
      my $evidence_group = $_ eq 'Transcription Factor' ? 'TFBS' :  $_;
      $evidence_group =~ s/[^\w\-]/_/g;
      $evidence->{$evidence_group} = {
        "name"          => $_ eq 'Transcription Factor' ? 'TFBS' :  $_,
        "listType"      => $_ eq 'Transcription Factor' ?  'alphabetRibbon' : '', #for the js side to list the track either its bullet point or alphabet ribbon 
        "evidence_type" => []
      };
      
      foreach (@{$adaptor->fetch_all_by_class($_)}) {
        next if $_->class eq 'Transcription Factor Complex'; #ignoring this group as its not used
        my $group = $_->class eq 'Transcription Factor' ? 'TFBS' : $_->class;
        $group =~ s/[^\w\-]/_/g;
        push @{$evidence->{$group}->{"evidence_type"}}, $_->name;
        push @{$all_types{$set}},$_;
      }      
    }
  }
  
  $final->{evidence}      = $evidence;
  
  #by default these track are on
  my %default_evidence_types = (
    CTCF     => 1,
    DNase1   => 1,
    H3K4me3  => 1,
    H3K36me3 => 1,
    H3K27me3 => 1,
    H3K9me3  => 1,
    PolII    => 1,
    PolIII   => 1,
  );
  #get all cell types and the evidence type related to each of them (e.g: A549 -> [{evidence_type = 'HH3K27ac', on = 1},{evidence_type='H3K36me3', on = 0},....]) 
  foreach (keys %{$db_tables->{'cell_type'}{'ids'}||{}}) {
    (my $name = $_) =~ s/:\w+$//;
    my $set_info;
    $set_info->{'core'}     = $db_tables->{'feature_types'}{'core'}{$name}     || {};
    $set_info->{'non_core'} = $db_tables->{'feature_types'}{'non_core'}{$name} || {};
    my $cell_evidence = [];
    
    foreach my $set (qw(core non_core)) {
      foreach (@{$all_types{$set}||[]}) {
        if ($set_info->{$set}{$_->dbID}) {
          my $hash = {
            evidence_type => $_->name,
            defaultOn     => $default_evidence_types{$_->name} ? 1 : 0
          };
          push @$cell_evidence, $hash;
        }
      }
    }
    $cell_types->{$name} = $cell_evidence if($cell_evidence);   
  }  

  #use Data::Dumper;warn Dumper($cell_types);
  $final->{cell_lines} = $cell_types;
  return $final;
}

1;

