=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

# $Id$

package EnsEMBL::Web::Component::Variation::PopulationGenotypes;

use strict;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self   = shift;
  my $object = $self->object;

  my $freq_data = $object->freqs;
  
  return $self->_info('Variation: ' . $object->name, '<p>No genotypes for this variation</p>') unless %$freq_data;
  
  my $table_array = $self->format_frequencies($freq_data);
  my $html        = '<a id="IndividualGenotypesPanel_top"></a>';
  
  if (scalar @$table_array == 1) {
    $html .= $table_array->[0]->[1]->render; # only one table to render (non-human or if no 1KG data)
  } else {
    my %table_order = (
      1000         => 1,
      HapMap       => 2,
      ESP          => 3,
      Mouse        => 4,
      Other        => 5,
      Inconsistent => 6,
      Observed     => 7,
    );
    
    my $species = $self->hub->species;
    my $main_tables_not_empty = 0;
    foreach (sort {$table_order{(split /\s+/, $a->[0])[0]} <=> $table_order{(split /\s+/, $b->[0])[0]}} @$table_array) {
      my ($title, $table) = @$_;
      my $id;

      # hide "other" and "failed" table
      if ($title =~ /other|inconsistent|population/i) {
        $id = $title =~ /other/i ? 'other' : ($title =~ /inconsistent/i ? 'inconsistent' : 'nopop');
        my $expanded = ($id eq 'other' && $species ne 'Homo_sapiens') ? 1 : ($id eq 'nopop' && $main_tables_not_empty == 0) ? 1 : 0;
        $html .= $self->toggleable_table($title, $id, $table, $expanded) if (scalar(@{$table->{'rows'}}) > 0);
      } else {
        $id = lc($title);
        $id =~ s/ //g;
        $id = (split(/\(/,$id))[0];
        $html .= $self->toggleable_table($title, $id, $table, 1);
      }
      $main_tables_not_empty = scalar(@{$table->{'rows'}}) if ($main_tables_not_empty == 0);
    }
  }
  
  return $html;
}

sub format_frequencies {
  my ($self, $freq_data, $tg_flag) = @_;
  my $hub        = $self->hub;

  my $is_somatic = $self->object->Obj->has_somatic_source;

  my (%columns, @rows, @table_array);
  
  my $table = $self->new_table([], [], { data_table => 1, sorting => [ 'pop asc', 'submitter asc' ] });
  
  my $al_colours = $self->object->get_allele_genotype_colours;

  # split off 1000 genomes, HapMap and failed if present
  if (!$tg_flag) {
    my ($tg_data, $hm_data, $fv_data, $no_pop_data, $mgp_data, $esp_data);
    
    foreach my $pop_id (keys %$freq_data) {
      if ($pop_id eq 'no_pop') {
        $no_pop_data = delete $freq_data->{$pop_id};
        next;
      }
      
      my $name = $freq_data->{$pop_id}{'pop_info'}{'Name'};
      if ($name =~ /^.+\:.+$/) {
        $freq_data->{$pop_id}{'pop_info'}{'Name'} =~ s/\:/\:<b>/;
        $freq_data->{$pop_id}{'pop_info'}{'Name'} .= '</b>';
      }
      foreach my $ssid (keys %{$freq_data->{$pop_id}{'ssid'}}) {
        
        if ($freq_data->{$pop_id}{'ssid'}{$ssid}{'failed_desc'}) {
          $fv_data->{$pop_id}{'ssid'}{$ssid}                = delete $freq_data->{$pop_id}{'ssid'}{$ssid};
          $fv_data->{$pop_id}{'pop_info'}                 = $freq_data->{$pop_id}{'pop_info'};
          $fv_data->{$pop_id}{'ssid'}{$ssid}{'failed_desc'} =~ s/Variation submission/Variation submission $ssid/;
        } elsif ($name =~ /^1000genomes\:phase.*/i) {
          $tg_data->{$pop_id}{'ssid'}{$ssid} = delete $freq_data->{$pop_id}{'ssid'}{$ssid};
          $tg_data->{$pop_id}{'pop_info'}  = $freq_data->{$pop_id}{'pop_info'};
        } elsif ($name =~ /^cshl\-hapmap/i) {
          $hm_data->{$pop_id}{'ssid'}{$ssid} = delete $freq_data->{$pop_id}{'ssid'}{$ssid};
          $hm_data->{$pop_id}{'pop_info'}  = $freq_data->{$pop_id}{'pop_info'};
        } elsif ($name =~ /^Mouse_Genomes_project/i) {
          $mgp_data->{$pop_id}{'ssid'}{$ssid} = delete $freq_data->{$pop_id}{'ssid'}{$ssid};
          $mgp_data->{$pop_id}{'pop_info'}  = $freq_data->{$pop_id}{'pop_info'};
        } elsif ($name =~ /^ESP/i) {
          $esp_data->{$pop_id}{'ssid'}{$ssid} = delete $freq_data->{$pop_id}{'ssid'}{$ssid};
          $esp_data->{$pop_id}{'pop_info'}  = $freq_data->{$pop_id}{'pop_info'};
        }
      }
    }
    
    # recurse this method with just the tg_data and a flag to indicate it
    push @table_array,  @{$self->format_frequencies($tg_data, '1000 Genomes')} if $tg_data;
    push @table_array,  @{$self->format_frequencies($hm_data, 'HapMap')}       if $hm_data;
    push @table_array,  @{$self->format_frequencies($fv_data, 'Inconsistent data')}  if $fv_data;
    push @table_array,  @{$self->format_frequencies($mgp_data, 'Mouse Genomes Project')}  if $mgp_data;
    push @table_array,  @{$self->format_frequencies($esp_data, 'ESP')}  if $esp_data;

    # special method for data with no pop/freq data
    if ($no_pop_data) {
      my $no_pop_table = $self->no_pop_data($no_pop_data);
      my $count_no_pop_data = scalar(@{$no_pop_table->{'rows'}});
      push @table_array,  ["Observed variant(s) without frequency or population ($count_no_pop_data)", $no_pop_table]  if $no_pop_data;
    }
  }
    
  # Other projects/populations
  foreach my $pop_id (keys %$freq_data) {
    my $pop_info = $freq_data->{$pop_id}{'pop_info'};
    
    foreach my $ssid (keys %{$freq_data->{$pop_id}{'ssid'}}) {
      my $data = $freq_data->{$pop_id}{'ssid'}{$ssid};
      my %pop_row;
      
      # SSID + Submitter
      if ($ssid) {
        $pop_row{'ssid'}      = $hub->get_ExtURL_link($ssid, 'DBSNPSS', $ssid) unless $ssid eq 'ss0';
        $pop_row{'submitter'} = $hub->get_ExtURL_link($data->{'submitter'}, 'DBSNPSSID', $data->{'submitter'});
      }  
      
      # Freqs alleles
      my @allele_freq = @{$data->{'AlleleFrequency'}};
      
      foreach my $gt (@{$data->{'Alleles'}}) {
        next unless $gt =~ /(\w|\-)+/;
        
        my $allele_count = shift @{$data->{'AlleleCount'}} || undef;
        
        $pop_row{'Allele count'}{$gt}      = "$allele_count <strong>($gt)</strong>" if defined $allele_count;
        $gt = substr($gt,0,10).'...' if (length($gt)>10);
        $pop_row{"Alleles $gt"} = $self->format_number(shift @allele_freq);
      }
      
      $pop_row{'Allele count'} = join ' , ', sort {(split /\(|\)/, $a)[1] cmp (split /\(|\)/, $b)[1]} values %{$pop_row{'Allele count'}} if $pop_row{'Allele count'};

      # Freqs genotypes
      my @genotype_freq = @{$data->{'GenotypeFrequency'} || []};
      
      foreach my $gt (@{$data->{'Genotypes'}}) {
        my $genotype_count = shift @{$data->{'GenotypeCount'}} || undef;
        
        $pop_row{'Genotype count'}{$gt} = "$genotype_count <strong>($gt)</strong>" if defined $genotype_count;
        $pop_row{"Genotypes $gt"}       = $self->format_number(shift @genotype_freq);
      }
      
      $pop_row{'Genotype count'}   = join ' , ', sort {(split /\(|\)/, $a)[1] cmp (split /\(|\)/, $b)[1]} values %{$pop_row{'Genotype count'}} if $pop_row{'Genotype count'};
      $pop_row{'pop'}              = $self->pop_url($pop_info->{'Name'}, $pop_info->{'PopLink'});
      $pop_row{'Description'}      = $pop_info->{'Description'} if $is_somatic;
      $pop_row{'failed'}           = $data->{'failed_desc'} if $tg_flag =~ /Inconsistent/i;
      $pop_row{'Super-Population'} = $self->sort_extra_pops($pop_info->{'Super-Population'});
      $pop_row{'Sub-Population'}   = $self->sort_extra_pops($pop_info->{'Sub-Population'});
      $pop_row{'detail'}           = $self->ajax_add($self->ajax_url(undef, { function => 'IndividualGenotypes', pop => $pop_id, update_panel => 1 }), $pop_id) if ($pop_info->{Size});;
      
      foreach my $al (keys(%$al_colours)) {
        $pop_row{'Allele count'} =~ s/$al/$al_colours->{$al}/g;           
        $pop_row{'Genotype count'} =~ s/$al/$al_colours->{$al}/g;
      }

      # HTML display for the allele counts
      my @al_count_array = split(',',$pop_row{'Allele count'});
      $pop_row{'Allele count'} = '';
      foreach my $al_count (@al_count_array) {
        my $padding = ($pop_row{'Allele count'} eq '') ? '' : ';padding-left:5px';
        $pop_row{'Allele count'} .= qq{<span style="min-width:55px;display:inline-block;text-align:right$padding">$al_count</span>};
      }

      # HTML display for the genotype counts
      my @gen_count_array = split(',',$pop_row{'Genotype count'});
      $pop_row{'Genotype count'} = '';
      foreach my $gen_count (@gen_count_array) {
        my $padding = ($pop_row{'Genotype count'} eq '') ? '' : ';padding-left:5px';
        $pop_row{'Genotype count'} .= qq{<span style="min-width:65px;display:inline-block;text-align:right$padding">$gen_count</span>};
      }

      # force ALL population to be displayed on top
      if($pop_info->{'Name'} =~ /ALL/) {
        $pop_row{'pop'} = qq{<span class="hidden">0</span>}.$pop_row{'pop'};
      }

      push @rows, \%pop_row;
      
      $columns{$_} = 1 for grep $pop_row{$_}, keys %pop_row;
    }
  }
  
  # Format table columns
  my @header_row;
  
  foreach my $col (sort { $b cmp $a } keys %columns) {
    next if $col =~ /pop|ssid|submitter|Description|detail|count|failed/;
    my ($type, $al_gen) = split (' ',$col);
    foreach my $al (keys(%$al_colours)) {
      $al_gen =~ s/$al/$al_colours->{$al}/g;
    }
    my $coloured_col = "$type $al_gen";
    unshift @header_row, { key => $col, align => 'left', label => $coloured_col, sort => 'numeric' };
  }
  
  if (exists $columns{'ssid'}) {
    unshift @header_row, { key => 'submitter', align => 'left', label => 'Submitter', sort => 'html'   };
    unshift @header_row, { key => 'ssid',      align => 'left', label => 'ssID',      sort => 'string' };
  }
  
  unshift @header_row, { key => 'Description',    align => 'left', label => 'Description',                           sort => 'none'   } if exists $columns{'Description'};
  unshift @header_row, { key => 'pop',            align => 'left', label => ($is_somatic ? 'Sample' : 'Population'), sort => 'html'   };
  push    @header_row, { key => 'Allele count',   align => 'left', label => 'Allele count',                          sort => 'none'   } if exists $columns{'Allele count'};
  push    @header_row, { key => 'Genotype count', align => 'left', label => 'Genotype count',                        sort => 'none'   } if exists $columns{'Genotype count'};
  push    @header_row, { key => 'detail',         align => 'left', label => 'Genotype detail',                       sort => 'none'   } if $self->object->counts->{'individuals'};
  push    @header_row, { key => 'failed',         align => 'left', label => 'Comment', width => '25%',               sort => 'string' } if $columns{'failed'};
  
  $table->add_columns(@header_row);
  $table->add_rows(@rows);
  
  push @table_array, [ sprintf('%s (%s)', $tg_flag || 'Other data', scalar @rows), $table ];

  return \@table_array;
}

sub format_number {
  ### Population_genotype_alleles
  ### Arg1 : null or a number
  ### Returns "unknown" if null or formats the number to 3 decimal places

  my ($self, $number) = @_;
  return defined $number ? sprintf '%.3f', $number : 'unknown';
}

sub sort_extra_pops {
  ### Population_table
  ### Arg1        : hashref with population data
  ### Example     :  my $super_string = sort_extra_pops($freq_data{$pop_id}{'pop_info'}{'Super-Population'});
  ### Description : returns string with Population name (size)<br> description
  ### Returns  string

  my ($self, $extra_pop) = @_;

  my @pops;
  
  foreach my $pop_id (keys %$extra_pop) {
    my $display_pop = $self->pop_url($extra_pop->{$pop_id}{'Name'}, $extra_pop->{$pop_id}{'PopLink'});
    my $size        = $extra_pop->{$pop_id}{'Size'};
       $size        = " (Size: $size)" if $size;
    my $string      = "$display_pop$size";
       $string     .= "<br /><small>$extra_pop->{$pop_id}{'Description'}</small>" if $extra_pop->{$pop_id}{'Description'};
  }
  
  return join '<br />', @pops;
}

sub pop_url {
   ### Arg1        : Population name (to be displayed)
   ### Arg2        : dbSNP population ID (variable to be linked to)
   ### Example     : $self->pop_url($pop_name, $pop_dbSNPID);
   ### Description : makes pop_name into a link
   ### Returns  string

  my ($self, $pop_name, $pop_dbSNP) = @_;
  
  my $pop_url;
  my $img_info = qq{<img src="/i/16/info.png" class="_ht" style="float:right;position:relative;top:2px;width:12px;height:12px;margin-left:4px" title="Click to see more information about the population" alt="info" />};

  if($pop_name =~ /^1000GENOMES/) {
    $pop_url = $pop_name.$self->hub->get_ExtURL_link($img_info, '1KG_POP', $pop_name); 
  }
  else {
    $pop_url = $pop_dbSNP ? $pop_name.$self->hub->get_ExtURL_link($img_info, 'DBSNPPOP', $pop_dbSNP->[0]) : $pop_name;
  }
  
  return $pop_url;
}

sub no_pop_data {
  my ($self, $data) = @_;
  
  my $hub = $self->hub;
  
  # get reference alleles
  my $vfs = $self->object->Obj->get_all_VariationFeatures;
  
  my (@alleles, %alleles);
  
  if(scalar @$vfs) {
    my $vf = $vfs->[0];
    @alleles = split /\//, $vf->allele_string;
    %alleles = map {$_ => 1} @alleles;
  }
  
  my @rows;
  
  foreach my $sub(keys %$data) {
    foreach my $ss(keys %{$data->{$sub}}) {
      my %unique = map {$_ => 1} @{$data->{$sub}{$ss}};
      
      my @ss_alleles = sort {
        (($b eq $alleles[0]) <=> ($a eq $alleles[0])) ||
        (defined($alleles{$b}) <=> defined($alleles{$a}))
      } keys %unique;
      
      my $flag = 0;
      foreach(@ss_alleles) {
        $flag = 1 if !defined($alleles{$_});
      }
      
      push @rows, {
        ssid      => $hub->get_ExtURL_link($ss, 'DBSNPSS', $ss),
        submitter => $hub->get_ExtURL_link($sub, 'DBSNPSSID', $sub),
        alleles   =>
          join("/",
            map {defined($alleles{$_}) ? $_ : '<span style="color:red">'.$_.'</span>'}
            @ss_alleles
          ).
          ($flag ? ' *' : ''),
      };
    }
  }
  
  my $table = $self->new_table([], [], { data_table => 1, sorting => [ 'pop asc', 'submitter asc' ] });
  $table->add_columns(
    { key => 'ssid',      title => 'ssID'              },
    { key => 'submitter', title => 'Submitter'         },
    { key => 'alleles',   title => 'Submitted alleles' }
  );
  $table->add_rows(@rows);
  
  return $table;
}


1;
