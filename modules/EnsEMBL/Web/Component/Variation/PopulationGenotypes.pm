package EnsEMBL::Web::Component::Variation::PopulationGenotypes;

use strict;

use EnsEMBL::Web::Document::SpreadSheet;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}


sub content {
  my $self = shift;
  my $object = $self->object;

  ## Check we have uniquely determined variation
  if ( $object->not_unique_location ){
    return $self->_info(
      'A unique location can not be determined for this Variation',
      $object->not_unique_location
    );
  }
 
  my $freq_data = $object->freqs; 
  unless (%$freq_data ){
    my $html = "<p>No genotypes for this variation</p>"; 
    return $self->_info(
    'Variation: '. $object->name,
    $html );
  }

  my $table = format_frequencies($object, $freq_data); 
  return $table->render;
}


sub format_frequencies {
  my ( $object, $freq_data ) = @_;
  my %freq_data = %{ $freq_data };
  my %columns;
  my @rows;
  my $table = new EnsEMBL::Web::Document::SpreadSheet([], [], { data_table => 1, sorting => [ 'pop asc', 'submitter asc' ] });

  foreach my $pop_id (keys %freq_data) { 
    foreach my $ssid (keys %{$freq_data{$pop_id}}) { 
      my %pop_row;
      
      # SSID + Submitter  -----------------------------------------
      if ($freq_data{$pop_id}{$ssid}{'ssid'}) {
        my $submitter         = $freq_data{$pop_id}{$ssid}{'submitter'};
        $pop_row{'ssid'}      = $freq_data{$pop_id}{$ssid}{'ssid'};
        $pop_row{'submitter'} = $object->get_ExtURL_link($submitter, 'DBSNPSSID', $submitter);
      }  
      
      # Freqs alleles ---------------------------------------------
      my @allele_freq = @{$freq_data{$pop_id}{$ssid}{'AlleleFrequency'}};
      
      foreach my $gt (@{$freq_data{$pop_id}{$ssid}{'Alleles'}}) {
        next unless $gt =~ /\w+/;
        my $freq = _format_number(shift @allele_freq);
        $pop_row{"Alleles&nbsp;<br />$gt"} = $freq;
      }
      
      # Freqs genotypes ---------------------------------------------
      my @genotype_freq = @{$freq_data{$pop_id}{$ssid}{'GenotypeFrequency'} || []};
      
      foreach my $gt (@{$freq_data{$pop_id}{$ssid}{'Genotypes'}}) {
        my $freq = _format_number(shift @genotype_freq);
        $pop_row{"Genotypes&nbsp;<br />$gt"} = $freq;
      }
      
      # Add a name, size and description if it exists ---------------------------
      $pop_row{'pop'}  = _pop_url($object, $freq_data{$pop_id}{$ssid}{'pop_info'}{'Name'}, $freq_data{$pop_id}{$ssid}{'pop_info'}{'PopLink'}) . '&nbsp;';
      $pop_row{'Size'} = $freq_data{$pop_id}{$ssid}{'pop_info'}{'Size'};
      
      # wm2 - REMOVED DESCRIPTIONS AS THEY LOOKED BAD - CAN STILL VIEW BY CLICKING POP NAME TO LINK OUT TO dbSNP
      ## Descriptions too long. Only display first sentence
      #(my $description = $freq_data{$pop_id}{$ssid}{'pop_info'}{'Description'}) =~ s/International HapMap project.*/International HapMap project\.\.\./;
      #$description =~ s/<.*?>//g;
      #$description = substr($description, 0, 220) . '...' if length $description > 220;
      #
      #$pop_row{'Description'} = sprintf '<small>%s</small>', $description || '-';
      
      # Super and sub populations ----------------------------------------------
      my $super_string = _sort_extra_pops($object, $freq_data{$pop_id}{$ssid}{'pop_info'}{'Super-Population'});
      $pop_row{'Super-Population'} = $super_string;

      my $sub_string = _sort_extra_pops($object, $freq_data{$pop_id}{$ssid}{'pop_info'}{'Sub-Population'});
      $pop_row{'Sub-Population'} = $sub_string;


      push @rows, \%pop_row;
      map { $columns{$_} = 1 } grep $pop_row{$_}, keys %pop_row;
    }
  }
  
 # Format table columns ------------------------------------------------------
  my @header_row;
  
  foreach my $col (sort { $b cmp $a } keys %columns) {
    next if $col =~ /pop|ssid|submitter/;
    
    if ($col eq 'Description') {
      push @header_row, { key => $col, align => 'left', title => $col, sort => 'none' };
    } else {
      unshift @header_row, { key => $col, align => 'left', title => $col, sort => 'numeric' };
    }
  }
  
  if (exists $columns{'ssid'}) {
    unshift @header_row, { key => 'submitter', align => 'left', title => 'Submitter', sort => 'html'   };
    unshift @header_row, { key => 'ssid',      align => 'left', title => 'ssID',      sort => 'string' };
  }
  
  unshift @header_row, { key => 'pop', align =>'left', title => 'Population', sort => 'html' };
  
  $table->add_columns(@header_row);
  $table->add_rows(@rows);

  return $table;
}

sub _sort_extra_pops {

    ### Population_table
    ### Arg1      : data object
    ### Arg2      : hashref with population data
    ### Example   :     my $super_string = _sort_extra_pops($object, $freq_data{$pop_id}{pop_info}{"Super-Population"});
    ### Description : returns string with Population name (size)<br> description
    ### Returns  string

  my ( $object, $extra_pop ) = @_;

  my @pops;
  foreach my $pop_id (keys %$extra_pop  ) {
    my $display_pop = _pop_url( $object, $extra_pop->{$pop_id}{Name},
               $extra_pop->{$pop_id}{PopLink});
    my $size = $extra_pop->{$pop_id}{Size};
    $size = " (Size: $size)" if $size;
    my $string = "$display_pop $size";
       $string .= "<br /><small>".$extra_pop->{$pop_id}{Description}."</small>" if $extra_pop->{$pop_id}{Description};
  }
  return  (join "<br />", @pops);
}



sub _format_number {

  ### Population_genotype_alleles
  ### Arg1 : null or a number
  ### Returns "unknown" if null or formats the number to 3 decimal places

  my $number = shift;
  if ($number) {
    return sprintf("%.3f", $number );
  }
  return  "unknown";
}

sub _pop_url {

   ### Arg1        : data object
   ### Arg2        : Population name (to be displayed)
   ### Arg3        : dbSNP population ID (variable to be linked to)
   ### Example     : _pop_url($object, $pop_name, $pop_dbSNPID);
   ### Description : makes pop_name into a link
   ### Returns  string

  my ($object, $pop_name, $pop_dbSNP) = @_;
  return $pop_name unless $pop_dbSNP;
  return $object->get_ExtURL_link( $pop_name, 'DBSNPPOP',$pop_dbSNP->[0] );
}


1;
