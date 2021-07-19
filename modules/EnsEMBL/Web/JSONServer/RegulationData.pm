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

package EnsEMBL::Web::JSONServer::RegulationData;

use strict;
use warnings;

use JSON;

use parent qw(EnsEMBL::Web::JSONServer);

sub databases { return $_[0]->hub->species_defs->get_config($_[0]->hub->param('species'), 'databases'); }

sub json_data {
  my $self = shift;
  my $hub  = $self->hub;
  my $db   = $hub->database('funcgen', $hub->param('species'));
  my $final = {};

  my $db_tables     = {};

  if ( defined $self->databases->{'DATABASE_FUNCGEN'} ) {
    $db_tables      = $self->databases->{'DATABASE_FUNCGEN'}{'tables'};
  }
  else {
    return {};
  }
  my $adaptor       = $db->get_FeatureTypeAdaptor;
  my $evidence_info = $adaptor->get_regulatory_evidence_info; #get all experiment  
  my ($evidence, $cell_types, %all_types); 

  $final->{extra_dimensions} = ['epigenomic_activity', 'segmentation_features'];
  
  $final->{data}->{epigenomic_activity} = {
    label => 'Epigenomic activity',
    set => 'reg_feats',
    renderer => "normal",
    popupType => "column-cell",
    defaultState => "track-on"
  };

  $final->{data}->{segmentation_features} = {
    label => 'Segmentation features',
    set => 'seg_Segmentation',
    renderer => "peak",
    popupType => "column-cell",
    defaultState => "track-off"
  };

  # evidence is the other name for experiment on the web interface
  # get all evidence and their corresponding evidence_type as a hash
  # e.g.: {histone -> {evidence_type -> [h2ka,...], name -> histone}, ....}
  foreach my $set (qw(core non_core)) {
    $all_types{$set} = [];
    foreach (@{$evidence_info->{$set}{'classes'}}) {
      next if $_ eq 'Transcription Factor Complex'; #looks like an API bug, this shouldnt be coming back from the API as we dont need this for web display
      
      my $evidence_group = $_ eq 'Transcription Factor' ? 'Transcription factors' :  $_;
      $evidence_group =~ s/[^\w\-]/_/g;
      $evidence->{$evidence_group} = {
        "name"          => $_ eq 'Transcription Factor' ? 'Transcription factors' :  $_,
        "listType"      => $_ eq 'Transcription Factor' ?  'alphabetRibbon' : '', #for the js side to list the track either its bullet point or alphabet ribbon 
        'set'           => "reg_feats_$set"
      } if($evidence_group ne 'Polymerase');

      foreach (@{$adaptor->fetch_all_having_PeakCalling_by_class($_)}) {
        next if $_->class eq 'Transcription Factor Complex'; #ignoring this group as its not used
        my $group = $_->class eq 'Transcription Factor' || $_->class eq 'Polymerase'  ? 'Transcription factors' : $_->class; #merging polymerase data and transcription factor data
        $group =~ s/[^\w\-]/_/g;
        push @{$evidence->{$group}->{"data"}}, $_->name;
        push @{$all_types{$set}},$_;
      }
    }
  }
  $final->{data}->{evidence}->{'name'}   = 'evidence';
  $final->{data}->{evidence}->{'label'}  = 'Evidence';
  $final->{data}->{evidence}->{'data'} = $evidence;
  $final->{data}->{evidence}->{'subtabs'} = 1;
  $final->{data}->{evidence}->{'popupType'} = 'peak-signal';
  $final->{data}->{evidence}->{'renderer'} = 'peak-signal';
  #get all cell types and the evidence type related to each of them (e.g: A549 -> [{evidence_type = 'HH3K27ac', on = 1},{evidence_type='H3K36me3', on = 0},....]) 
  foreach (keys %{$db_tables->{'cell_type'}{'ids'}||{}}) {
    my $id_key = $_;
    (my $name = $_) =~ s/:\w+$//;

    my $set_info;
    $set_info->{'core'}     = $db_tables->{'feature_types'}{'core'}{$name}     || {};
    $set_info->{'non_core'} = $db_tables->{'feature_types'}{'non_core'}{$name} || {};
    my $cell_evidence = [];
    my $tmp_hash = ();
    foreach my $set (qw(core non_core)) {
      foreach (@{$all_types{$set}||[]}) {
        if ($set_info->{$set}{$_->dbID}) {
          my $hash = {
            dimension => 'evidence',
            val => $_->name,
            set => "reg_feats_$set",
            defaultState => "track-on"
          };
          push @$cell_evidence, $hash;

          # Add regulatory features only of it is available.
          if ($db_tables->{'cell_type'}{'ids'}->{$id_key}) {
            foreach my $k (@{$final->{extra_dimensions}}) {
              my $ex = $final->{data}->{$k};
              if (!$tmp_hash->{$ex->{label}}) {
                # print Data::Dumper::Dumper $tmp_hash;
                $tmp_hash->{$ex->{label}} = 1;
                $hash =  {
                  dimension => $k,
                  val => $ex->{label},
                  set => $ex->{set},
                  defaultState => $ex->{defaultState} || "track-off"
                };
                push @$cell_evidence, $hash;
              }
            }
          }
        }
      }
    }

    $cell_types->{$name} = $cell_evidence if(@$cell_evidence);
  }

  #use Data::Dumper;warn Dumper($cell_types);
  $final->{data}->{epigenome}->{'name'}   = 'epigenome';
  $final->{data}->{epigenome}->{'label'}  = 'Cell/Tissue';
  $final->{data}->{epigenome}->{'data'} = $cell_types;
  $final->{data}->{epigenome}->{'listType'} = 'alphabetRibbon';
  $final->{dimensions} = ['epigenome', 'evidence'];

  return $final;
}

sub json_info {
  my $self = shift;
  my $hub  = $self->hub;
  my $db   = $hub->database('funcgen', $hub->param('species'));
  my $final = {};

  my $db_tables     = {};

  if ( defined $self->databases->{'DATABASE_FUNCGEN'} ) {
    $db_tables      = $self->databases->{'DATABASE_FUNCGEN'}{'tables'};
  }
  else {
    return {};
  }

  foreach (keys %{$db_tables->{'cell_type'}{'ids'}||{}}) {
    my $id_key = $_;
    (my $name = $_) =~ s/:\w+$//;
    $final->{info} = $db_tables->{'cell_type'}{'info'};
  }

  my $adaptor       = $db->get_FeatureTypeAdaptor;
  my $evidence_info = $adaptor->get_regulatory_evidence_info; #get all experiment  
  my ($evidence); 

  # evidence is the other name for experiment on the web interface
  # get all evidence and their corresponding evidence_type as a hash
  # e.g.: {histone -> {evidence_type -> [h2ka,...], name -> histone}, ....}
  foreach my $set (qw(core non_core)) {
    foreach (@{$evidence_info->{$set}{'classes'}}) {
      next if $_ eq 'Transcription Factor Complex'; #looks like an API bug, this shouldnt be coming back from the API as we dont need this for web display
      foreach (@{$adaptor->fetch_all_having_PeakCalling_by_class($_)}) {
        next if $_->class eq 'Transcription Factor Complex'; #ignoring this group as its not used
        my $group = $_->class eq 'Transcription Factor' || $_->class eq 'Polymerase'  ? 'Transcription factors' : $_->class; #merging polymerase data and transcription factor data
        $group =~ s/[^\w\-]/_/g;
        $final->{info}->{$_->name}->{'description'} = $_->description;
      }
    }
  }

  return $final;
}

1;

