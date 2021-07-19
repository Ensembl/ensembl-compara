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

package EnsEMBL::Draw::GlyphSet::phenotype_feature;

### Draws phenotype feature track on Variation/Context

use strict;

use base qw(EnsEMBL::Draw::GlyphSet_simple);

sub colour_key    { return lc $_[1]->type; }
sub label_overlay { return 1; }

sub my_config { 
  my $self = shift;
	my $term = shift;
	
  if($term eq 'depth' && $self->{'display'} eq 'gene_nolabel') {
    return 999;
  }
  if($term eq 'height' && $self->{'display'} eq 'compact') {
    return 5;
  }
  
	return $self->{'my_config'}->get($term);
}

sub feature_label {
  my ($self, $f) = @_;
  return $self->{'display'} eq 'compact' ? undef : $f->phenotype->description;
}

sub features {
  my $self = shift; 
  my $id   = $self->{'my_config'}->id;
  
  if (!$self->cache($id)) {
    my $slice    = $self->{'container'};
    my $type     = $self->my_config('type');
    my $study_name = $self->my_config('study_name');
    my $var_db     = $self->my_config('db') || 'variation';
    my $pf_adaptor = $self->{'config'}->hub->get_adaptor('get_PhenotypeFeatureAdaptor', $var_db);
    my $features;

    if ($study_name) {
      my $study_obj = $self->{'config'}->hub->get_adaptor('get_StudyAdaptor', $var_db)->fetch_by_name($study_name);
      $features = $pf_adaptor->fetch_all_by_Slice_Study($slice, $study_obj, undef)    ;
    }
    elsif($type) {
      $features = [grep {$_->{_phenotype_id}} @{$pf_adaptor->fetch_all_by_Slice_type($slice, $type)}];
    }
    else {
      $features = [grep {$_->{_phenotype_id}} @{$pf_adaptor->fetch_all_by_Slice($slice)}];
    }
    
    $self->cache($id, $features);
  }
  
  my $features_list = $self->cache($id);
  if (scalar @$features_list) {
    return $features_list;
  }
  else {
    my $track_name = $self->my_config('name');
    $self->errorTrack("No $track_name data for this region");
    return [];
  }
}


sub tag {
  my ($self, $f) = @_;
  my $colour = $self->my_colour($self->colour_key($f), 'tag');
  my @tags;
  
  return @tags;
}

sub href {
  my ($self, $f) = @_;
  
  my $type = $f->type;
  my $link;
  my $hub = $self->{'config'}->hub;
  
  # link to search for SSVs
  if($type eq 'SupportingStructuralVariation') {
    my $params = {
      'type'   => 'Search',
      'action' => 'Results',
      'q'      => $f->object_id,
      __clear  => 1
    };
    
    $link = $hub->url($params);
  }
  
  # link to ext DB for QTL
  elsif($type eq 'QTL') {
    my $source = $f->source_name;
    my $species = uc(join("", map {substr($_,0,1)} split(/\_/, $hub->species)));

    $source .= '_SEARCH' if ($source eq 'RGD');
    $link = $hub->get_ExtURL(
      $source,
      { ID => $f->object_id, TYPE => $type, SP => $species}
    );
  }
  
  # link to gene or variation page
  else {
    # work out the ID param (e.g. v, g, sv)
    my $id_param = $type;
    $id_param =~ s/[a-z]//g;
    $id_param = lc($id_param);
    
    my $params = {
      'type'      => $type,
      'action'    => 'Phenotype',
      'ph'        => $hub->param('ph') || undef,
      $id_param   => $f->object_id,
      __clear     => 1
    };

    $link = $hub->url($params);
  }

  return $link;
}

sub title {
  my ($self, $f) = @_;
  my $id     = $f->object_id;
  my $phen   = $f->phenotype->description;
  my $source = $f->source_name;
  my $type   = $f->type;
  my $loc    = $f->seq_region_name.":".$f->seq_region_start."-".$f->seq_region_end;
  my $hub    = $self->{'config'}->hub;
  
  # convert the object type e.g. from StructuralVariation to Structural Variation
  # but don't want to convert QTL to Q T L
  $type =~ s/([A-Z])([a-z])/ $1$2/g;
  $type =~ s/^s+//;
  
  # link to phenotype page
  my $url = $hub->url({
    type => 'Phenotype',
    action => 'Locations',
    ph => $f->phenotype->dbID,
    __clear => 1,
  });
  $phen = sprintf('<a href="%s">%s</a>', $url, $phen);
  
  my $string = "$type: $id; Phenotype: $phen; Source: $source; Location: $loc";
  
  # add phenotype attributes, skip internal dbID ones
  my %attribs = %{$f->get_all_attributes};
  foreach my $attrib(sort grep {!/sample|strain/} keys %attribs) {
    my $value = $attribs{$attrib};
    
    if($attrib eq 'external_id') {
      my $url = $hub->get_ExtURL(
        $f->source,
        { ID => $value, TAX => $hub->species_defs->TAXONOMY_ID }
      );
      
      $value = '<a href="'.$url.'" target="_blank">'.$value.'</a>' if $url;
    }
    $string .= "; $attrib: $value";
  }
  
  return $string;
}

1;
