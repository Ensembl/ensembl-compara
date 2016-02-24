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

package EnsEMBL::Web::Component::Transcript::Haplotypes;

use strict;
use warnings;
no warnings 'uninitialized';

use HTML::Entities qw(encode_entities);
use JSON;

use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $object = $self->object;
  
  my $html = '';
  
  # tell JS what panel type this is
  $html .= '<input type="hidden" class="panel_type" value="TranscriptHaplotypes" />';

  my $c = $self->get_haplotypes;
  
  my $table = $self->new_table(
    [], [], {
      data_table => 1,
      download_table => 1,
      sorting => [ 'freq desc' ],
      # data_table_config => {iDisplayLength => 10}, 
    }
  );
  
  my $total_counts = $c->total_population_counts();
  
  my $pop_objs = $c->get_all_Populations();
  my $pop_struct = $self->population_structure($pop_objs);
  
  my %pop_descs = map {$_->name => $_->description} @$pop_objs;
  
  my @pop_cols =
    map {{
      key => $self->short_population_name($_),
      title => $self->short_population_name($_),
      sort => 'numeric',
      help => sprintf('Frequency in %s: %s population (count)', $_, $pop_descs{$_})
    }}
    sort keys %$pop_struct;

  my $type = $self->hub->param('ht_type') || 'protein';
  my %titles = (
    'protein' => 'Protein',
    'cds'     => 'CDS',
  );
  my $other_type = $type eq 'protein' ? 'cds' : 'protein';

  $table->add_columns(
    {
      key   => 'haplotype',
      title => $titles{$type}.' haplotype',
      sort  => 'html_numeric',
      help  => 'Haplotype names represent a comma-separated list of differences to the reference sequence'
    },
    {
      key   => 'flags',
      title => 'Flags',
      sort  => 'html_numeric',
      help  => 'Flags indicating features of interest for each haplotype'
    },
    {
      key   => 'freq',
      title => 'Frequency (count)',
      sort  => 'numeric',
      help  => 'Combined frequency across all samples and observed count in parentheses'
    },
    @pop_cols,
  );
  
  my @rows;
  my $count = 0;
  my $method = 'get_all_'.$titles{$type}.'Haplotypes';

  my $haplotypes = $c->$method;

  foreach my $ht(@$haplotypes) {    
    $table->add_row($self->render_haplotype_row($ht));
  }

  my $url = $self->hub->url({ht_type => lc($other_type)});
  $html .= sprintf(
    '<h4><a href="%s">Switch to %s view</a> <img src="/i/16/reload.png" height="12px"></h4>',
    $url, $titles{$other_type}
  );
  
  $html .= $table->render;

  # send through JSON version of the container
  my $json = JSON->new();

  $html .= sprintf(
    '<input class="js_param" type="hidden" name="haplotype_data" value="%s" />',
    encode_entities($json->allow_blessed->convert_blessed->encode($c))
  );

  # and send population stuff
  $html .= sprintf(
    '<input class="js_param" type="hidden" name="population_info" value="%s" />',
    encode_entities(
      $self->jsonify(
        {
          population_structure => $pop_struct,
          population_descriptions => {map {$_->name => $_->description} @$pop_objs},
          sample_population_hash => $c->_get_sample_population_hash,
        }
      )
    )
  );

  # add anchors for every haplotype hex
  $html .= join("", map {'<a name="'.$_->_hex().'"/>'} @$haplotypes);

  # add element for displaying details
  $html .= '<div class="details-view" id="details-view">&nbsp;</div>';

  return $html;
}

sub get_haplotypes {
  my $self = shift;
  
  my $tr = $self->object->Obj;
  
  my $vdb = $tr->adaptor->db->get_db_adaptor('variation');
  
  # find VCF config
  my $sd = $self->object->species_defs;

  my $c = $sd->ENSEMBL_VCF_COLLECTIONS;

  if($c && $vdb->can('use_vcf')) {
    $vdb->vcf_config_file($c->{'CONFIG'});
    $vdb->vcf_root_dir($sd->DATAFILE_BASE_PATH);
    $vdb->use_vcf($c->{'ENABLED'});
  }
  
  my $thca = $vdb->get_TranscriptHaplotypeAdaptor();

  return $thca->get_TranscriptHaplotypeContainer_by_Transcript($tr);
}

sub short_population_name {
  my $self = shift;
  my $name = shift;
  
  my $short = $name;
  $short =~ s/1000GENOMES:phase_3://i;
  
  return $short;
}

sub population_structure {
  my $self = shift;
  my $pop_objs = shift;
  
  if(!exists($self->{_population_structure})) {
    my %pop_struct;
    foreach my $pop(@$pop_objs) {
      next if $pop->name =~ /:ALL$/;
      my $subs = $pop->get_all_sub_Populations();
      next unless $subs && scalar @$subs;
      @{$pop_struct{$pop->name}} = map {$_->name} @$subs;
    }
    
    $self->{_population_structure} = \%pop_struct;
  }
  
  return $self->{_population_structure};
}

sub population_objects {
  my $self = shift;
  my $total_counts = shift;
  
  if(!exists($self->{_population_objects})) {
    # generate population structure
    my $pop_adaptor = $self->object->Obj->adaptor->db->get_db_adaptor('variation')->get_PopulationAdaptor;
    my @pop_objs = grep {defined($_)} map {$pop_adaptor->fetch_by_name($_)} keys %$total_counts;
    
    $self->{_population_objects} = \@pop_objs;
  }
  
  return $self->{_population_objects};
}

sub render_haplotype_row {
  my $self = shift;
  my $ht = shift;
  
  my $pop_objs = $self->population_objects();
  my $pop_struct = $self->population_structure;
  my %pop_descs = map {$_->name => $_->description} @$pop_objs;

  my @flags = $ht->can('get_all_flags') ? @{$ht->get_all_flags()} : ();
  my $flags_html;

  my $score = 0;
  my %scores = (
    'deleterious_sift_or_polyphen' => 2,
    'indel' => 3,
    'stop_change' => 4,
  );
  $score += $scores{$_} || 1 for @flags;

  $flags_html = sprintf(
    '<span class="hidden">%i</span><div style="width: 6em">%s</div>',
    $score,
    join(" ", map {$self->render_flag($_)} sort {($scores{$b} || 1) <=> ($scores{$a} || 1)} @flags)
  );
  
  # create base row
  my $row = {
    haplotype => $self->render_haplotype_name($ht),
    flags     => $flags_html,
    freq      => sprintf("%.3g (%i)", $ht->frequency, $ht->count),
  };
  
  # add per-population frequencies
  my $pop_freqs = $ht->get_all_population_frequencies;
  my $pop_counts = $ht->get_all_population_counts;
  
  foreach my $pop(keys %$pop_counts) {
    my $short_pop = $self->short_population_name($pop);
    
    $row->{$short_pop} = sprintf("%.3g (%i)", $pop_freqs->{$pop}, $pop_counts->{$pop});
  }
  
  return $row;
}

sub render_haplotype_name {
  my $self = shift;
  my $ht = shift;
  
  my $name = $ht->name;
  $name =~ s/^.+?://;

  my $display_name = $name;
  my $hidden = '';

  if(length($display_name) > 50) { 
    $display_name = substr($display_name, 0, 50);
    $display_name =~ s/\,[^\,]+$// unless substr($display_name, 50, 1) eq ',';
    $display_name .= '...';

    $hidden = sprintf('<span class="hidden">%s</span>', $name);
  }

  # introduce line-breaking zero-width spaces
  $name =~ s/\,/\,\&\#8203\;/g;

  my $title = "Details for ".($name eq 'REF' ? 'reference haplotype' : 'haplotype '.$name);

  return sprintf(
    '%s<span class="_ht" title="%s"><a href="#%s" class="details-link" rel="%s">%s</a></span>',
    $hidden,
    $title,
    $ht->_hex,
    $ht->_hex,
    $display_name
  );
}

sub render_flag {
  my $self = shift;
  my $flag = shift;

  my $char = uc(substr($flag, 0, 1));
  my $tt = ucfirst($flag);
  $tt =~ s/\_/ /g;

  my %colours = (
    D => ['yellow',  'black'],
    S => ['red',     'white'],
    I => ['#ff69b4', 'white'],
  );

  return sprintf(
    '<div style="background-color:%s; color:%s; black; width: 1.5em; display: inline-block; font-weight: bold;" class="_ht score" title="%s">%s</div>',
    $colours{$char}->[0],
    $colours{$char}->[1],
    $tt,
    $char
  );
}

1;
