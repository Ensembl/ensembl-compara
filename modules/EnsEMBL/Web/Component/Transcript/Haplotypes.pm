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

sub buttons {
### Custom export button, because this view displays sequence using JavaScript
  my $self = shift;
  my $hub = $self->hub;

  my $url = sprintf '%s/transcript_haplotypes/%s/%s?content-type=application/json;sequence=1', 
                      $hub->species_defs->ENSEMBL_REST_URL, 
                      lc($hub->species), 
                      $hub->param('t');
  my @buttons;

  push @buttons, {
      'url'       => $url,
      'caption'   => 'Export data as JSON',
      'class'     => 'export popup',
    };

  my $type = $self->hub->param('ht_type') || 'protein';
  my %titles = (
    'protein' => 'Protein',
    'cds'     => 'CDS',
  );
  my $other_type = $type eq 'protein' ? 'cds' : 'protein';

  $url = $self->hub->url({ht_type => lc($other_type)});
  my $html .= sprintf(
    '<h4><a href="%s" style="vertical-align:middle">Switch to %s view</a> <img src="/i/16/reload.png" style="vertical-align:middle"></h4>',
    $url, $titles{$other_type}
  );

  push @buttons, {
      'url'       => $url,
      'caption'   => sprintf('Switch to %s view', $titles{$other_type}),
      'class'     => 'view',
    };

  return @buttons;

}

sub content {
  my $self = shift;
  my $object = $self->object;
  
  my $html = '';

  # filter?
  my $filter;
  if($self->param('filter_enabled') eq 'on') {
    
    # warn user filtering is enabled
    $html .= $self->_info(
      'Variant frequency filtering enabled',
      'Haplotypes may not be representative of true observed sequences '.
      'as variants with frequency less than '.
      $self->hub->param('filter_frequency').
      ' have been filtered out'
    );
    
    $filter = {frequency => {frequency => $self->hub->param('filter_frequency')}};
  }
  
  my $c = $object->get_haplotypes($filter);
  return unless $c;
  
  # tell JS what panel type this is
  $html .= '<input type="hidden" class="panel_type" value="TranscriptHaplotypes" />';

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

  my @cols = (
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

  push @cols, {
    key   => 'variants',
    title => 'Variants',
    sort  => 'html_numeric',
    help  => 'Variants that contribute to this haplotype\'s difference(s) to the reference',
  } if $self->param('show_variants') eq 'on';

  $table->add_columns(@cols);
  
  my @rows;
  my $count = 0;
  my $method = 'get_all_'.$titles{$type}.'Haplotypes';

  my $haplotypes = $c->$method;

  foreach my $ht(@$haplotypes) {    
    $table->add_row($self->render_haplotype_row($ht));
  }
  
  $html .= $table->render;

  $c->_prefetch_everything();

  # send through JSON version of the container
  my $json = JSON->new();
  my $params_to_client = {'protein_haplotypes' => $c->get_all_ProteinHaplotypes,
                          'cds_haplotypes'     => $c->get_all_CDSHaplotypes };
  $html .= sprintf(
    '<input class="js_param" type="hidden" name="haplotype_data" value="%s" />',
    encode_entities($json->allow_blessed->convert_blessed->encode($params_to_client))
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
      next if scalar( @{$pop->get_all_sub_Populations} );
      my @super_pops = @{$pop->get_all_super_Populations};
      push @super_pops, $pop unless scalar( @super_pops );
      foreach my $super_pop( @super_pops ) {
        $pop_struct{$super_pop->name} ||= [];
        push @{$pop_struct{$super_pop->name}}, $pop->name;
      }
    }
    $self->{_population_structure} = \%pop_struct;
  }
  return $self->{_population_structure};
}

sub render_haplotype_row {
  my $self = shift;
  my $ht = shift;
  
  my $pop_objs    = $self->object->population_objects;
  my $pop_struct  = $self->population_structure($pop_objs);
  my %pop_descs   = map {$_->name => $_->description} @$pop_objs;

  my $flags = $ht->can('get_all_flags') ? $ht->get_all_flags() : [];
  
  my $flags_html;

  my $score = 0;
  my %scores = (
    'deleterious_sift_or_polyphen' => 2,
    'indel' => 3,
    'stop_change' => 4,
    'resolved_frameshift' => 1,
    'frameshift' => 4,
  );
  $score += $scores{$_} || 1 for @$flags;

  $flags_html = sprintf(
    '<span class="hidden">%i</span><div style="width: 6em">%s</div>',
    $score,
    join(" ", map {$self->render_flag($_)} sort {($scores{$b} || 1) <=> ($scores{$a} || 1)} @$flags)
  );
  
  # create base row
  my $row = {
    haplotype => $self->render_haplotype_name($ht),
    flags     => $flags_html,
    freq      => sprintf("%.3g (%i)", $ht->frequency, $ht->count),
  };

  $row->{variants} = join(", ", map {$self->render_var_link($_)} @{$ht->get_all_VariationFeatures}) if $self->param('show_variants') eq 'on';
  
  # add per-population frequencies
  my $pop_freqs = $ht->get_all_population_frequencies;
  my $pop_counts = $ht->get_all_population_counts;
  
  foreach my $pop(keys %$pop_struct) {
    my $short_pop = $self->short_population_name($pop);
    
    $row->{$short_pop} = sprintf("%.3g (%i)", $pop_freqs->{$pop} || 0, $pop_counts->{$pop} || 0);
  }
  
  return $row;
}

sub render_var_link {
  my $self = shift;
  my $vf = shift;

  my $hub = $self->hub;

  my ($var, $vf_id) = ($vf->variation_name, $vf->dbID);

  my $zmenu_url = $hub->url({
    type    => 'ZMenu',
    action  => 'Variation',
    v       => $var,
    vf      => $vf_id,
  });

  return sprintf('<a class="zmenu" href="%s">%s</a>', $zmenu_url, $var);
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
