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

package EnsEMBL::Web::ZMenu::RegFeature;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self              = shift;
  my $hub               = $self->hub;
  my $feature           = $hub->database('funcgen')->get_ExternalFeatureAdaptor->fetch_by_dbID($hub->param('dbid'));
  my $location          = $feature->slice->seq_region_name . ':' . $feature->start . '-' . $feature->end;
  my $display_label     = $feature->display_label;
  my $feature_name      = $feature->feature_type->name;
  my $external_link     = $self->get_external_link($feature); 
  my $feature_view_link = $self->get_feature_view_link($feature);
  
  $self->caption('Regulatory Region');

  $self->add_entry ({
    type   => 'Name',
    label  => $display_label,
  });

  if ($external_link =~ /http/) {
    my $label = $feature->analysis->logic_name =~ /TarBase/i ? 'Tarbase miRNA target' : $feature_name;
    $self->add_entry ({
      type       => 'FeatureType',
      label_html => $label,
      link       => $external_link,
    });
  } else {
    $self->add_entry ({
      type  => 'FeatureType',
      label => $feature_name,
    });
  }

  $self->add_entry({
    type       => 'bp',
    label_html => $location,
    link_class => '_location_change _location_mark',
    link       => $hub->url({
      type   => 'Location',
      action => 'View',
      r      => $location
    })
  });
  
  if ($feature_view_link){
    $self->add_entry({
      label_html => 'View all locations',
      link       => $feature_view_link, 
    });
  }
}

sub get_external_link {
  my ($self, $f) = @_;
  my $ext_id     = $f->display_label;
  
  return if $ext_id =~ /Search/;
  
  my $hub        = $self->hub;
  my $type       = $f->feature_type->name;
  my $logic_name = $f->analysis->logic_name;
  my $external_link;

  if ($logic_name =~ /cisred/i) {
    $ext_id        =~ s/\D*//g;
    $external_link = $hub->get_ExtURL_link($f->display_label, uc $logic_name, $ext_id);
  } elsif ($logic_name =~ /miranda/i) {
    my @display_names = split /:/, $f->display_label;
    $external_link    = $hub->get_ExtURL_link($display_names[1], uc $logic_name, { ID => $display_names[1] });
  } elsif ($logic_name =~ /MICA/) {
     $external_link = $hub->get_ExtURL_link($type, uc $logic_name, $ext_id);
  } elsif ($logic_name =~ /REDFLY/i) {
    $external_link = $f->display_label;
  } elsif ($logic_name =~ /VISTA/i) {
    $ext_id        =~ s/LBNL-//;
    $external_link = $hub->get_ExtURL_link($f->display_label, uc($logic_name) . 'EXT', $ext_id );
  } elsif ($logic_name =~ /TarBase/i) {
    $external_link = $hub->get_ExtURL_link('Tarbase miRNA target', 'TARBASE', $ext_id );
  }
  
  if ($external_link =~ /href/) { 
    my @link_info  = split /href\=|\>|\"/, $external_link;
    $external_link = $link_info[2]; 
  }
  
  return $external_link;
}

sub get_feature_view_link {
  my ($self, $feature) = @_;
  my $feature_id  = $feature->display_label;
  my $feature_set = $feature->feature_set->name;
  
  return if $feature_set =~ /cisRED|CRM|FANTOM|VISTA/i;
  
  my $link = $self->hub->url({
    type   => 'Location',
    action => 'Genome',
    ftype  => 'RegulatoryFactor',
    fset   => $feature_set,
    id     => $feature_id,
  });
  
  return $link;
}

1;
