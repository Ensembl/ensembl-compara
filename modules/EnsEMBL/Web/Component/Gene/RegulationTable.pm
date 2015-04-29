=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Gene::RegulationTable;

use strict;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub caption {
  my $self = shift;
  return 'Regulatory elements located in the region of ' . $self->object->stable_id;
}

sub content {
  my $self         = shift;
  my $object       = $self->object;
  my @reg_factors  = @{$object->reg_factors};
  my @reg_features = $self->hub->species =~/Drosophila_melanogaster/ ? () : @{$object->reg_features};

  ## return if no regulatory elements ##
  if (scalar @reg_factors < 1 && scalar @reg_features < 1) {
    my $html = "<p><strong>There are no regulatory factors linked to this gene</strong></p>";
    return $html;
  }

  ## If there are factors to display ##
  my $gene_slice = $object->Obj->feature_Slice;
  my $offset = $gene_slice->start -1;
  my $str = "positive";

  my $table = $self->new_table([], [], { data_table => 1 });
  $table->add_columns(
    { key => 'feature',  title => 'Reg. region',            width => '21%', align => 'left', sort => 'html'           },
    { key => 'analysis', title => 'Analysis',               width => '16%', align => 'left', sort => 'html'           },
    { key => 'type',     title => 'Type',                   width => '18%', align => 'left', sort => 'html'         },
    { key => 'location', title => 'Location',               width => '20%', align => 'left', sort => 'position_html'  },
    { key => 'length',   title => 'Length (bp)',            width => '5%',  align => 'left', sort => 'numeric'        },
    { key => 'seq',      title => "Sequence ($str strand)", width => '20%', align => 'left', sort => 'none'           },
  );
  # First process Ensembl regulatory features
  foreach my $feature (@reg_features){
    my $regulation_obj      = $self->new_object('Regulation', $feature, $object->__data);
    my $summary_url         = $regulation_obj->get_summary_page_url;
    my $feature_id          = $feature->stable_id;
    my $feature_link        = qq(<a href=$summary_url>$feature_id</a>);
    my $analysis            = qq(<a rel="external" href="/info/genome/funcgen/index.html">Ensembl Regulatory Build</a>);
    my $type                = $feature->feature_type->name;
    my ($sequence, $length) = $self->get_sequence($regulation_obj);

    my $row = {
      feature   => $feature_link,
      analysis  => $analysis,
      type      => $type,
      location  => $self->get_location_link($regulation_obj),
      seq       => $sequence,
      length    => $length,
  };
    $table->add_row($row);
  }

  # Then add info from external sources
  foreach my $factor (@reg_factors){
    next if $factor->display_label =~/Search/;
    my ($sequence, $length) = $self->get_sequence($factor);
    my $row = {
      feature   => $self->get_id_link($factor),
      analysis  => $self->get_analysis($factor),
      type      => $self->get_type($factor),
      location  => $self->get_location_link($factor),
      seq       => $sequence,
      length    => $length,
    };

    $table->add_row($row);
  }

  return $table->render;
}

sub get_analysis {
  my ($self, $f) = @_;
  my $desc = $f->analysis->description;
  my $analysis;

  unless ($desc=~/www|http/){
     my @names = split(/\s+/, $desc);
     $analysis =  $self->hub->get_ExtURL_link($desc,  uc($names[0]), $desc);
     $analysis = $desc unless $analysis =~/\w+/;
  } else {
    # hack to get around problem with source data file for release 50
    if ($f->display_label  =~/cra.*/){
      $desc =~s/cisRED\smotif\ssearch/cisRED atomic motifs/;
      $desc =~s/www/http:\/\/www/;
    }
    my @temp = split(/\(|\)/, $desc);
    $analysis = qq(<a rel="external" href="$temp[1]">).$temp[0]."</a>";
  }
  return $analysis;
}

sub get_id_link {
  my ($self, $f )= @_;
  my $f_link = $f->display_label;
  return $f_link;
}

sub get_location_link {
  my ($self, $f) = @_;
  my $object = $self->object;
  my ($position, $type);
  
  if ($f->isa('Bio::EnsEMBL::Funcgen::ExternalFeature')) {
    my $seq_name = $f->slice->seq_region_name;
    my $f_slice  = $object->get_extended_reg_region_slice;
    my $f_offset = $f_slice->start - 1;
    my $f_start  = $f->start + $f_offset;
    my $f_end    = $f->end   + $f_offset;
    $position    = "$seq_name:$f_start-$f_end";
    $type        = sprintf 'regulatory_regions_funcgen_%s=normal', $f->feature_set->analysis->logic_name;
  } else {
    my $offset = $object->get_extended_reg_region_slice->start - 1;
    $position  = $f->location_string($offset);
    $type      = 'reg_feats_MultiCell=normal';
  }

  my $position_url = $self->hub->url({
    type              => 'Location',
    action            => 'View',
    r                 => $position,
    contigviewbottom  => $type,
  });
  
  return qq{<a href="$position_url">$position</a>};
}

sub get_sequence {
  my ($self, $f) = @_;
  my $object = $self->object;
  my $sequence;
  
  if ($f->isa('EnsEMBL::Web::Proxy::Object')){
    $sequence = $f->get_seq($object->Obj->feature_Slice->strand);
  } else {
    my $gene_slice = $object->get_extended_reg_region_slice;
    
    if ($f->isa('EnsEMBL::Web::Object::Regulation')){
      $sequence = $gene_slice->subseq($f->seq_region_start, $f->seq_region_end, 1);
    } else {
      $sequence = $gene_slice->subseq($f->start, $f->end, 1);
    }
  }

  $sequence =~ s/([\.\w]{60})/$1<br \/>/g;
  
  return (qq{<span class="sequence">$sequence</span>}, $self->thousandify(length $sequence));
}

sub get_type {
  my ($self, $f) = @_;
  my $hub        = $self->hub;
  my $type       = $f->feature_type->name;
  my $logic_name = $f->analysis->logic_name;
  my $ext_id     = $f->display_label;
  my $external_link;

  if ($logic_name =~ /cisred/i) {
    $ext_id         =~ s/\D*//g;
    $external_link = $hub->get_ExtURL_link($f->display_label, uc $logic_name, $ext_id);
  } elsif ($logic_name =~/miranda/i) {
    my @display_names = split /:/, $f->display_label;
    $external_link    = $hub->get_ExtURL_link($display_names[1], uc $logic_name, { ID => $display_names[1] });
  } elsif ($logic_name =~ /MICA/) {
     $external_link = $hub->get_ExtURL_link($type, uc $logic_name, $ext_id);
  } elsif ($logic_name =~ /REDFLY/i) {
    $external_link = $f->display_label;
  } elsif ($logic_name =~ /VISTA/i) {
    $ext_id =~ s/LBNL-//;
    $external_link = $hub->get_ExtURL_link($f->display_label, uc($logic_name) . 'EXT', $ext_id);
  }

  # add feature view link
  my $all_link    = $self->object->get_feature_view_link($f);
  $external_link .= " $all_link" if $all_link =~/\w+/;
  
  return $external_link;
}

1;
