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

  ## Check we have uniquely determined variation
  return $self->_info('A unique location can not be determined for this Variation', $object->not_unique_location) if $object->not_unique_location;
 
  my $freq_data = $object->freqs;
  
  return $self->_info('Variation: ' . $object->name, '<p>No genotypes for this variation</p>') unless %$freq_data;
  return $self->format_frequencies($freq_data)->render;
}

sub format_frequencies {
  my ($self, $freq_data) = @_;
  my $hub        = $self->hub;
  my $is_somatic = $self->object->Obj->is_somatic;
  my %columns;
  my @rows;
  my $table = $self->new_table([], [], { data_table => 1, sorting => [ 'pop asc', 'submitter asc' ] });

  foreach my $pop_id (keys %$freq_data) { 
    foreach my $ssid (keys %{$freq_data->{$pop_id}}) { 
      my %pop_row;
      
      # SSID + Submitter  -----------------------------------------
      if ($freq_data->{$pop_id}{$ssid}{'ssid'}) {
        my $submitter         = $freq_data->{$pop_id}{$ssid}{'submitter'};
        $pop_row{'ssid'}      = $hub->get_ExtURL_link($freq_data->{$pop_id}{$ssid}{'ssid'}, 'DBSNPSS', $freq_data->{$pop_id}{$ssid}{'ssid'});
        $pop_row{'submitter'} = $hub->get_ExtURL_link($submitter, 'DBSNPSSID', $submitter);
      }  
      
      # Freqs alleles ---------------------------------------------
      my @allele_freq = @{$freq_data->{$pop_id}{$ssid}{'AlleleFrequency'}};
      
      foreach my $gt (@{$freq_data->{$pop_id}{$ssid}{'Alleles'}}) {
        next unless $gt =~ /\w+/;
        my $freq = $self->format_number(shift @allele_freq);
        $pop_row{"Alleles&nbsp;<br />$gt"} = $freq;
      }
      
      # Freqs genotypes ---------------------------------------------
      my @genotype_freq = @{$freq_data->{$pop_id}{$ssid}{'GenotypeFrequency'} || []};
      
      foreach my $gt (@{$freq_data->{$pop_id}{$ssid}{'Genotypes'}}) {
        my $freq = $self->format_number(shift @genotype_freq);
        $pop_row{"Genotypes&nbsp;<br />$gt"} = $freq;
      }
      
      # Add a name, size and description if it exists ---------------------------
      $pop_row{'pop'}         = $self->pop_url($freq_data->{$pop_id}{$ssid}{'pop_info'}{'Name'}, $freq_data->{$pop_id}{$ssid}{'pop_info'}{'PopLink'}) . '&nbsp;';
      $pop_row{'Size'}        = $freq_data->{$pop_id}{$ssid}{'pop_info'}{'Size'};
      $pop_row{'Description'} = $freq_data->{$pop_id}{$ssid}{'pop_info'}{'Description'} if $is_somatic;
      
      # Super and sub populations ----------------------------------------------
      my $super_string = $self->sort_extra_pops($freq_data->{$pop_id}{$ssid}{'pop_info'}{'Super-Population'});
      $pop_row{'Super-Population'} = $super_string;

      my $sub_string = $self->sort_extra_pops($freq_data->{$pop_id}{$ssid}{'pop_info'}{'Sub-Population'});
      $pop_row{'Sub-Population'} = $sub_string;

      push @rows, \%pop_row;
      map { $columns{$_} = 1 } grep $pop_row{$_}, keys %pop_row;
    }
  }
  
 # Format table columns ------------------------------------------------------
  my @header_row;
  
  foreach my $col (sort { $b cmp $a } keys %columns) {
    next if $col =~ /pop|ssid|submitter|Description/;
    unshift @header_row, { key => $col, align => 'left', title => $col, sort => 'numeric' };
  }
  
  if (exists $columns{'ssid'}) {
    unshift @header_row, { key => 'submitter', align => 'left', title => 'Submitter', sort => 'html'   };
    unshift @header_row, { key => 'ssid',      align => 'left', title => 'ssID',      sort => 'string' };
  }
  
  if (exists $columns{'Description'}) {
    unshift @header_row, { key => 'Description', align => 'left', title => 'Description', sort => 'none' };
  }
  
  unshift @header_row, { key => 'pop', align =>'left', title => ($is_somatic ? 'Sample' : 'Population'), sort => 'html' };
  
  $table->add_columns(@header_row);
  $table->add_rows(@rows);

  return $table;
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
    $size           = " (Size: $size)" if $size;
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
  return $pop_name unless $pop_dbSNP;
  return $self->hub->get_ExtURL_link($pop_name, 'DBSNPPOP', $pop_dbSNP->[0]);
}


1;
