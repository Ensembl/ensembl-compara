=head1 LICENSE

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
  my $is_somatic = $object->Obj->has_somatic_source;
  my $freq_data = $object->freqs;
  
  return $self->_info('Variation: ' . $object->name, '<p>No genotypes for this variation</p>') unless %$freq_data;
  
  my $table_array = $self->format_frequencies($freq_data);
  my $html        = '<a id="SampleGenotypesPanel_top"></a>';
  
  if (scalar @$table_array == 1 && $is_somatic) {
    $html .= $table_array->[0]->[1]->render;
  }
  elsif (scalar @$table_array == 1) {
    my ($title, $table, $pop_url) = @{$table_array->[0]};
    my $id;
    if ($title =~ /other|inconsistent|population/i) {
      $id = $title =~ /other/i ? 'other' : ($title =~ /inconsistent/i ? 'inconsistent' : 'nopop');
    }
    else {
      $id = lc($title);
      $id =~ s/ //g;
      $id = (split(/\(/,$id))[0];
    }

    $html .= $self->toggleable_table($title, $id, $table, 1);
    $html .= $self->generic_group_link($title,$pop_url) if ($pop_url);

  } else {
    
    my $species = $self->hub->species;
    my $main_tables_not_empty = 0;

    my $table_html = '';
    my @id_title = ();

    foreach ( @$table_array) {
      my ($title, $table, $pop_url) = @$_;
      my $id;

      # hide "other" and "failed" table
      if ($title =~ /other|inconsistent|population/i) {
        $id = $title =~ /other/i ? 'other' : ($title =~ /inconsistent/i ? 'inconsistent' : 'nopop');
        my $expanded = ($id eq 'other' && $species ne 'Homo_sapiens') ? 1 : ($id eq 'nopop' && $main_tables_not_empty == 0) ? 1 : 0;
        $table_html .= $self->toggleable_table($title, $id, $table, $expanded) if (scalar(@{$table->{'rows'}}) > 0);
      } else {
        $id = lc($title);
        $id =~ s/ //g;
        $id = (split(/\(/,$id))[0];
        $table_html .= $self->toggleable_table($title, $id, $table, 1);
        push @id_title, [$id, $title];
      }
      $table_html .= $self->generic_group_link($title,$pop_url) if ($pop_url);

      $main_tables_not_empty = scalar(@{$table->{'rows'}}) if ($main_tables_not_empty == 0);
    }

    $html .=
      '<div style="padding: 5px; background-color: #eaeeff; border: 1px solid #bcf; margin-bottom: 1em;"><i>Jump to: </i><b>'.
      join(' | ', map {'<a href="#'.$_->[0].'_anchor">'.$_->[1].'</a>'} @id_title).'</b></div>'
      if scalar @id_title > 1;
    $html .= $table_html;
  }
  
  return $html;
}

## divide frequency data into different types & create tables
sub format_frequencies {

  my ($self, $freq_data) = @_;


  my $priority_data;  ###  priority data 
  my $fv_data;        ###  inconsistent data 
  my $standard_data;  ###  non-priority frequency data
  my $no_pop_data;    ###  observations without pops

  my %group_name;     ###  display name for priority population group
 
  ########################################################
  ## divide into project/ type specific hashes
  ########################################################

  foreach my $pop_id (keys %$freq_data) {

    if ($pop_id eq 'no_pop') {
      ### variation observation without population or frequency data
      $no_pop_data = delete $freq_data->{$pop_id};
      next;
    }

    ### format population name      
    my $name = $freq_data->{$pop_id}{'pop_info'}{'Name'};
    # Display the last part of the population name in bold
    if ($name =~ /^.+\:.+$/ and $name !~ /(http|https):/) {
      my @composed_name = split(':', $name);
      $composed_name[$#composed_name] = '<b>'.$composed_name[$#composed_name].'</b>';
      $freq_data->{$pop_id}{'pop_info'}{'Name'} = join(':',@composed_name);

      # 1KG population names
      if ($freq_data->{$pop_id}{'pop_info'}{'PopGroup'} && $freq_data->{$pop_id}{'pop_info'}{'PopGroup'} =~ /^(1000\s*genomes|hapmap)/i ) {
        $freq_data->{$pop_id}{'pop_info'}{'Label'} = $composed_name[$#composed_name];
      }
    }

    ### loop through frequency data for this population putting it in the destination array for display purposes
    foreach my $ssid (keys %{$freq_data->{$pop_id}{'ssid'}}) {

	    ## is it a priority project 
	    my $priority_level =  $freq_data->{$pop_id}{'pop_info'}{'GroupPriority'};
	  
	    if( defined $priority_level){

	      ### store frequency data
	      $priority_data->{$priority_level}->{$pop_id}{'ssid'}{$ssid}     = delete $freq_data->{$pop_id}{'ssid'}{$ssid};
	      $priority_data->{$priority_level}->{$pop_id}{'pop_info'}        = $freq_data->{$pop_id}{'pop_info'};
	      $priority_data->{$priority_level}->{$pop_id}{'missing_alleles'} = $freq_data->{$pop_id}{'missing_alleles'};
	      ### pull out group display name for the group with this priority to use later
	      $group_name{$priority_level} = $freq_data->{$pop_id}{'pop_info'}{'PopGroup'} unless defined $group_name{$priority_level};
	    } 
	  
	  
	    elsif ($freq_data->{$pop_id}{'ssid'}{$ssid}{'failed_desc'}) {

	      ### hold failed data separately to display separately
	      $fv_data->{$pop_id}{'ssid'}{$ssid}     = delete $freq_data->{$pop_id}{'ssid'}{$ssid};
	      $fv_data->{$pop_id}{'pop_info'}        = $freq_data->{$pop_id}{'pop_info'};
	      $fv_data->{$pop_id}{'missing_alleles'} = $freq_data->{$pop_id}{'missing_alleles'};
	      $fv_data->{$pop_id}{'ssid'}{$ssid}{'failed_desc'} =~ s/Variation submission/Variation submission $ssid/;
      } 
	    else {
	      $standard_data->{$pop_id}{'ssid'}{$ssid}     = delete $freq_data->{$pop_id}{'ssid'}{$ssid};
	      $standard_data->{$pop_id}{'pop_info'}        = $freq_data->{$pop_id}{'pop_info'};
	      $standard_data->{$pop_id}{'missing_alleles'} = $freq_data->{$pop_id}{'missing_alleles'};
	    }
    }
  }
    
  ##########################################################
  # format the tables storing them in display priority order
  ##########################################################

  my @table_array;  ## holds formatted tables

  my $name_for_standard_data = 'Frequency data'; ## Call the standard stuff 'other' only if there are priority projects

  ## store priority tables first
  foreach my $priority_level (sort(keys %{$priority_data})){    
    push @table_array,  $self->format_table($priority_data->{$priority_level},  $group_name{$priority_level} );
    $name_for_standard_data = 'Other frequency data';
  }

  ## non-priority project frequency data
  push @table_array,  $self->format_table($standard_data,  $name_for_standard_data )  if $standard_data;
  
  ## inconsistent data
  push @table_array,  $self->format_table($fv_data,  'Inconsistent data')        if $fv_data;
    

  # special method for data with no pop/freq data
  if ($no_pop_data) {
    my $no_pop_table = $self->no_pop_data($no_pop_data);
    my $count_no_pop_data = scalar(@{$no_pop_table->{'rows'}});
    push @table_array,  ["Observed variant(s) without frequency or population information ($count_no_pop_data)", $no_pop_table]  if $no_pop_data;
  }

  return \@table_array;
}
    

sub format_table {
  my ($self, $freq_data, $table_header) = @_;

  my $hub        = $self->hub;
  my $is_somatic = $self->object->Obj->has_somatic_source;
  my $al_colours = $self->object->get_allele_genotype_colours;
  my $vf         = $hub->param('vf');
  my $vf_object  = $vf ? $hub->database('variation')->get_VariationFeatureAdaptor->fetch_by_dbID($vf) : undef;
  my $ref_allele = $vf_object ? $vf_object->ref_allele_string : '';

  my $has_pop_with_samples = 0;
  my $bar_width = 100;

  my %columns;
  my @header_row;
  my @rows;

  ## Sort into super-populations and sub-populations
  ## and get links
  my ($tree, $all, $has_super, %pop_urls, $unique_urls, %urls_seen, $generic_pop_url);
  foreach my $pop_id (keys %$freq_data) {
    my $name  = $freq_data->{$pop_id}{'pop_info'}{'Name'};

    ## Get URL
    my $url = $self->pop_url($name, $freq_data->{$pop_id}{'pop_info'}{'PopLink'});
    if ($url) {
      $pop_urls{$pop_id} = $url;
      $urls_seen{$url}++;
    }

    ## Make the tree
    if ($name =~ /(\W+|_)ALL/) {
      $all = $pop_id;
      next;
    }

    my $hash = $freq_data->{$pop_id}{'pop_info'}{'Super-Population'};
    my ($super) = keys %{$hash||{}};
    if ($super) {
      $tree->{$super}{'children'}{$pop_id} = $name;
      $tree->{$super}{'name'} = $freq_data->{$super}{'pop_info'}{'Name'} if (!$tree->{$super}{'name'});
      $has_super++;
    }
    else {
      $tree->{$pop_id}{'name'} = $name;
    }
  }

  my @ids;
  push @ids, $all if $all;
  my @super_order = sort {$tree->{$a}{'name'} cmp $tree->{$b}{'name'}} keys (%$tree);
  foreach my $super (@super_order) {
    my $children = $tree->{$super}{'children'} || {};
    my $next_level_has_children = 0;
    foreach my $child_id (keys %$children) {
      if ($tree->{$child_id}{'children'}) {
        $next_level_has_children = 1;
      }
    }
    if ($all && $super == $all) {
      next if ($next_level_has_children); # Skip the 3 layers structure, which leads to duplicated rows
    } else {
      push @ids, $super;
    }
    push @ids, sort {$children->{$a} cmp $children->{$b}} keys (%$children);
  }

  if (scalar(keys %urls_seen) < 2) {
    $generic_pop_url = $pop_urls{$ids[0]};
  }

  ## Now build table rows
  foreach my $pop_id (@ids) {
    my $pop_info = $freq_data->{$pop_id}{'pop_info'};

    my ($row_class, $group_member);
    if ($pop_info->{'Name'} =~ /(\W+|_)ALL/ && $tree->{$pop_id}{'children'}) {
      $row_class = 'supergroup';
    }
    elsif ($tree->{$pop_id}{'children'}) {
      $row_class = 'subgroup';
    }
    elsif (scalar keys %$tree > 1) {
      $group_member = 1;
    }

    foreach my $ssid (keys %{$freq_data->{$pop_id}{'ssid'}}) {
      my $data = $freq_data->{$pop_id}{'ssid'}{$ssid};
      my %pop_row;
      $pop_row{'options'}{'class'} = $row_class if $row_class;
     
      # SSID + Submitter
      if ($ssid) {
        if ($hub->species eq 'Homo_sapiens') {
          $pop_row{'ssid'}      = $hub->get_ExtURL_link($ssid, 'DBSNPSS', $ssid) unless $ssid eq 'ss0';
          $pop_row{'submitter'} = ($data->{'submitter'}) ? $hub->get_ExtURL_link($data->{'submitter'}, 'DBSNPSSID', $data->{'submitter'}) : '-';
        }
        else {
          $pop_row{'ssid'} = $ssid unless $ssid eq 'ss0';
          $pop_row{'submitter'} = ($data->{'submitter'}) ? $data->{'submitter'} : '-';
        }
      }

      # Column "Allele: frequency (count)"
      my $allele_content = $self->format_allele_genotype_content($data,'Allele',$ref_allele,$is_somatic);
      if($freq_data->{$pop_id}{'missing_alleles'} && scalar keys %{$freq_data->{$pop_id}{'missing_alleles'}}) {
        $allele_content .= sprintf(
          '<span style="float:right" class="_ht sprite info_icon" title="%s has data not shown for the following alleles: <ul>%s</ul>'.
          'These alleles are not defined in %s but may be present in overlapping variants."></span>',
          $pop_info->{'Name'},
          join("", map {"<li>$_</li>"} sort {$a cmp $b} keys %{$freq_data->{$pop_id}{'missing_alleles'}}),
          $self->object->name,
        );
      }
      $pop_row{'Allele'} = qq{<div>$allele_content<div style="clear:both"/></div>} if ($allele_content);


      # Column "Genotype: frequency (count)"
      my $genotype_content = $self->format_allele_genotype_content($data,'Genotype',$ref_allele);
      $pop_row{'Genotype'} = qq{<div>$genotype_content<div style="clear:both"/></div>} if ($genotype_content);

      # bar chart
      $pop_row{'bar'} = $self->frequency_bar($data, $ref_allele, $bar_width);


      ## Add the population description: this will appear when the user move the mouse on the population name
      my $pop_name = ($pop_info->{'Label'}) ? $pop_info->{'Label'} : $pop_info->{'Name'}; # 1KG population names
      if (!$is_somatic && $pop_info->{'Description'}) {
        my $desc = $self->strip_HTML($pop_info->{'Description'});
        my $ht_class = ((scalar(keys %urls_seen) > 1 || scalar(keys %pop_urls) == 1 )) ? '' : ' ht';
        $pop_name = qq{<span class="_ht$ht_class" title="$desc">$pop_name</span>};
      }
      if ($pop_info->{'Label'}) { # 1KG population names
        $pop_name .= qq{<span class="hidden export">;}.$pop_info->{'Name'}.qq{</span>};
      }

      ## Only link on the population name if there's more than one URL for this table
      my $pop_url = (scalar(keys %urls_seen) > 1 || scalar(keys %pop_urls) == 1 ) ? sprintf('<a href="%s" rel="external">%s</a>', $pop_urls{$pop_id}, $pop_name) : $pop_name;

      ## Hacky indent, because overriding table CSS is a pain!
      $pop_row{'pop'}              = $group_member ? '&nbsp;&nbsp;'.$pop_url : $pop_url;

      $pop_row{'Description'}      = $pop_info->{'Description'} if $is_somatic;
      $pop_row{'failed'}           = $data->{'failed_desc'} if $table_header =~ /Inconsistent/i;
      $pop_row{'Super-Population'} = $self->sort_extra_pops($pop_info->{'Super-Population'});
      $pop_row{'Sub-Population'}   = $self->sort_extra_pops($pop_info->{'Sub-Population'});
      if ($pop_info->{Size}) {
        $pop_row{'detail'} = $self->ajax_add($hub->url('Component', { action => 'Sample', function => 'sample',  pop => $pop_id, update_panel => 1 }), $pop_id);
        $has_pop_with_samples  = 1;
      }
      
      push @rows, \%pop_row;
      $columns{$_} = 1 for grep $pop_row{$_}, keys %pop_row;
    }
  }
  delete $columns{'options'};
  
  # Format table columns
  
  # Allele frequency columns
  foreach my $col (sort { $a cmp $b } keys %columns) {
    next if $col =~ /pop|ssid|submitter|Description|detail|count|failed|Genotype|bar/; # Exclude all but 'Allele X'
    my $label_suffix = ($is_somatic) ? '' : ' (count)';
    push @header_row, { key => $col, align => 'left', label => "$col: frequency$label_suffix", sort => 'none' };
  }
  
  unshift @header_row, { key => 'bar', label => '', align => 'left', sort => 'none', width => ($bar_width + 10).'px' };
  unshift @header_row, { key => 'Description', align => 'left', label => 'Description',                           sort => 'none' } if exists $columns{'Description'};
  unshift @header_row, { key => 'pop',         align => 'left', label => ($is_somatic ? 'Sample' : 'Population'), sort => 'none', width => '150px'   };


  # Genotype frequency columns
  foreach my $col (sort { $a cmp $b } keys %columns) {
    next if $col =~ /pop|ssid|submitter|Description|detail|count|failed|Allele|bar/; # Exclude all but 'Genotype X|X'
    push @header_row, { key => $col, align => 'left', label => "$col: frequency (count)", sort => 'none' };
  }

  if (exists $columns{'ssid'}) {
    push @header_row, { key => 'ssid',      align => 'left', label => 'ssID',      sort => 'string' };
    push @header_row, { key => 'submitter', align => 'left', label => 'Submitter', sort => 'html'   };
  }

  push @header_row, { key => 'detail', align => 'left', label => 'Genotypes',               sort => 'none' } if ($self->object->counts->{'samples'} && $has_pop_with_samples == 1);
  push @header_row, { key => 'failed', align => 'left', label => 'Comment', width => '25%', sort => 'none' } if $columns{'failed'};

  my $table = $self->new_table([], [], { data_table => 1 });
  $table->add_columns(@header_row);
  $table->add_rows(@rows);
 
  return [sprintf('%s (%s)', $table_header, scalar @rows), $table, $generic_pop_url];

}


sub format_number {
  ### Population_genotype_alleles
  ### Arg1 : null or a number
  ### Returns "unknown" if null or formats the number to 3 decimal places

  my ($self, $number) = @_;

  if (defined($number)) {
    my $rounded_number = sprintf '%.3f', $number;
    if (($rounded_number eq '0.000' && $number != 0) ||
        ($rounded_number eq '1.000' && $number != 1)) {
      $rounded_number = $number;
    }
    return $rounded_number;
  }
  else {
    return 'unknown';
  }
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
        ssid      => ($hub->species eq 'Homo_sapiens') ? $hub->get_ExtURL_link($ss, 'DBSNPSS', $ss) : $ss,
        submitter => ($hub->species eq 'Homo_sapiens') ? $hub->get_ExtURL_link($sub, 'DBSNPSSID', $sub) : $sub,
        alleles   =>
          join("/",
            map {defined($alleles{$_}) ? qq{<span style="font-weight:bold">$_</span>} : qq{<span style="color:red">$_</span>}}
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

sub generic_group_link {
  my $self    = shift;
  my $title   = shift;
  my $pop_url = shift;

  return '' if ($title =~ /PRJEB\d+/i);

  $title =~ /^(.+)\s*\(\d+\)/;
  my $project_name = ($1) ? $1 : $title;

  my $terms = '';
  my $pop_use_url;
  if ($project_name =~ /ncbi alfa/i) {
    $pop_use_url = $self->hub->get_ExtURL('ALFA_POP_USE');
    if ($pop_use_url) {
      $terms = sprintf(' (<a href="%s" rel="external">Terms of Use</a>)', $pop_use_url);
    }
  } elsif ($project_name =~ /gem-j/i) {
    $pop_use_url = $self->hub->get_ExtURL('GEM_J_POP_USE');
    if ($pop_use_url) {
      $terms = sprintf(' (<a href="%s" rel="external">Terms of Use</a>)', $pop_use_url);
    }
  }

  $project_name = ($project_name =~ /(project|consortium|ncbi alfa)/i) ? "<b>$project_name</b> " : '';

  return sprintf('<div style="clear:both"></div><p><a href="%s" rel="external">More information about the %spopulations</a>%s</p>', $pop_url, $project_name, $terms);
}

sub format_allele_genotype_content {
  my $self       = shift;
  my $data       = shift;
  my $type       = shift; # 'Allele' or 'Genotype'
  my $ref_allele = shift;
  my $is_somatic = shift;

  my $al_colours = $self->object->get_allele_genotype_colours;
  my $raw_allele_colours = $self->object->raw_allele_colours();
  my @other_colours = @{$self->other_colours};

  my %data_list;
  my @freqs = @{$data->{$type.'Frequency'} || []};
  foreach my $gt (@{$data->{$type.'s'}}) {
    next unless $gt =~ /(\w|\-)+/;
    my $gt_freq  = $self->format_number(shift @freqs);
    my $gt_count = shift @{$data->{$type.'Count'}} || undef;
    $data_list{$gt} = {'freq' => $gt_freq, 'count' => $gt_count};
  }

  my $content;
  my $count_data = 0;
  my $regex = ($type eq 'Genotype') ? $ref_allele.'\|'.$ref_allele : $ref_allele;
  my @sorted_gts = sort { ($a !~ /$regex/ cmp $b !~ /$regex/) || $a cmp $b } keys %data_list;

  my $any_long_alleles = grep {!/^[ACGT\-]$/} @sorted_gts;

  foreach my $gt (@sorted_gts) {

    my ($gt_label, $trimmed);
    if(length($gt) > 10) {
      $gt_label = substr($gt, 0, 10).'...';
      $trimmed = 1;
    }
    else {
      $gt_label = $gt;
    }

    if(!$any_long_alleles) {
      foreach my $al (keys(%$al_colours)) {
        $gt_label =~ s/$al/$al_colours->{$al}/g;
      }
    }

    # make a helptip showing the full allele if it is long
    if($trimmed) {
      my $ht_gt = $gt;
      $ht_gt =~ s/(.{30})/$1\&\#8203\;/g;
      $ht_gt =~ s/(\|)/ $1 /g;
      $gt_label = sprintf('<span class="ht _ht" title="%s">%s</span>', $ht_gt, $gt_label);
    }

    $count_data ++;
    my $class;
    if ($type eq 'Allele') {
      $class  = (length($gt) > 1) ? 'allele_long' : 'allele_short';
      $class .= ($count_data == scalar(keys(%data_list))) ? '' : ' allele_padding';

      $gt_label = sprintf(
        '<span class="colour" style="background-color:%s">&nbsp;</span> %s',
        $raw_allele_colours->{$gt} || shift @other_colours || 'grey',
        $gt_label
      ) if $any_long_alleles;
    }
    elsif ($type eq 'Genotype') {
      $class  = (length($gt) > 4) ? 'genotype_long' : 'genotype_short';
      $class .= ($count_data == scalar(keys(%data_list))) ? '' : ' genotype_padding';
    }

    if ($is_somatic) {
      $content .= sprintf(qq{<div class="%s"><b>%s</b>: %s </div>},
                          $class, $gt_label, $data_list{$gt}{'freq'});
    } else {
      $content .= sprintf(qq{<div class="%s"><b>%s</b>: %s%s </div>},
                          $class, $gt_label, $data_list{$gt}{'freq'},
                          defined($data_list{$gt}{'count'}) ? ' ('.$data_list{$gt}{'count'}.')' : '');
    }
  }

  return $content;
}

sub frequency_bar {
  my $self       = shift;
  my $data       = shift;
  my $ref_allele = shift;
  my $bar_width  = shift || 100;

  return unless @{$data->{'AlleleFrequency'}};

  my $content; 
  $content .= '<div class="_no_export" style="position: relative; white-space: nowrap; width:'.($bar_width + 5).'px;">';
  $content .= sprintf('<div style="position:absolute; width: %ipx; z-index: 5; border-right: 1px dotted white;height: 1em; ">&nbsp;</div>', int($bar_width / 2) - 1);
  $content .= '<div style="position:absolute; left: 0px; top: 0px; z-index: 3;">';

  my $raw_allele_colours = $self->object->raw_allele_colours();
  my @other_colours = @{$self->other_colours};

  my @alleles = @{$data->{'Alleles'}};
  my $added_width = 0;
  my %alleles_seen;

  for my $i(sort { ($alleles[$a] !~ /$ref_allele/ cmp $alleles[$b] !~ /$ref_allele/) || $alleles[$a] cmp $alleles[$b] } 0..$#alleles) {
    my $allele = $alleles[$i];
    next if ($alleles_seen{$allele});
    $alleles_seen{$allele} = 1;
    my $width = sprintf('%.0f', $data->{'AlleleFrequency'}->[$i] * $bar_width);
    $added_width += $width;

    $content .= sprintf(
      '<div style="width:%.0fpx; background-color: %s; float: left; display: inline; height: 1em; "></div>',
      $width,
      $raw_allele_colours->{$allele} || shift @other_colours || 'grey'
    );
  }

  # sometimes the data we extract won't add to 1
  # add an indicator at the end to fill up the bar
  $content .= sprintf(
    '<div style="width:%.0fpx; float: left; display: inline; height: 1em; border-right: 1px dotted black"></div>',
    ($bar_width - $added_width)
  ) if $added_width < $bar_width;

  $content .= '</div></div>';

  return $content;
}

sub other_colours {
  return [qw(#008080 #FF00FF #7B68EE cyan)];
}

1;
