package EnsEMBL::Web::Component::Gene::SVTable;

use strict;

use Bio::EnsEMBL::Variation::Utils::Constants;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self    = shift;
  my $hub     = $self->hub;
  my $object  = $self->object;  
  my $slice   = $object->slice;
  my $columns = [
     { key => 'id',          sort => 'string',        title => 'Name'   },
     { key => 'location',    sort => 'position_html', title => 'Chr:bp' },
     { key => 'size',        sort => 'string',        title => 'Genomic size (bp)' },
     { key => 'class',       sort => 'string',        title => 'Class'  },
     { key => 'source',      sort => 'string',        title => 'Source Study' },
     { key => 'description', sort => 'string',        title => 'Study description', width => '50%' },
  ];
  
  my $html  = $self->table($slice, $columns, 'Structural variants',         'sv',  'get_all_StructuralVariationFeatures');
     $html .= $self->table($slice, $columns, 'Copy number variants probes', 'cnv', 'get_all_CopyNumberVariantProbeFeatures');
  
  return $html;
}

sub table {
  my ($self, $slice, $columns, $title, $table_id, $function) = @_;
  my $hub = $self->hub;
  my $rows;
  
  foreach my $svf (@{$slice->$function}) {
    my $name        = $svf->variation_name;
    my $sv          = $svf->structural_variation;
    my $description = $sv->source_description;
    my $sv_class    = $sv->var_class;
    my $source      = $sv->source;
    
    if ($sv->study) {
      my $ext_ref    = $sv->study->external_reference;
      my $study_name = $sv->study->name;
      
      if ($table_id eq 'sv' && $study_name) {
        $source      .= ":$study_name";
        $source       = sprintf '<a rel="external" href="%s">%s</a>', $sv->study->url, $source;
        $description .= ': ' . $sv->study->description;
      }
      
      if ($ext_ref =~ /pubmed\/(.+)/) {
        my $pubmed_id   = $1;
        my $pubmed_link = $hub->get_ExtURL('PUBMED', $pubmed_id);
           $description =~ s/$pubmed_id/'<a href="'.$pubmed_link.'" target="_blank">'.$&.'<\/a>'/eg;
      }
    }
    
    # SV size (format the size with comma separations, e.g: 10000 to 10,000)
    my $sv_size    = $svf->end - $svf->start + 1;
    my $int_length = length $sv_size;
    
    if ($int_length > 3) {
      my $nb         = 0;
      my $int_string = '';
      
      while (length $sv_size > 3) {
        $sv_size    =~ /(\d{3})$/;
        $int_string = ",$int_string" if $int_string ne '';
        $int_string = "$1$int_string";
        $sv_size    = substr $sv_size, 0, (length($sv_size) - 3);
      }
      
      $sv_size = "$sv_size,$int_string";
    }  
      
    my $sv_link = $hub->url({
      type   => 'StructuralVariation',
      action => 'Summary',
      sv     => $name
    });      

    my $loc_string = $svf->seq_region_name . ':' . $svf->seq_region_start . '-' . $svf->seq_region_end;
        
    my $loc_link = $hub->url({
      type   => 'Location',
      action => 'View',
      r      => $loc_string,
    });
      
    my %row = (
      id          => qq{<a href="$sv_link">$name</a>},
      location    => qq{<a href="$loc_link">$loc_string</a>},
      size        => $sv_size,
      class       => $sv_class,
      source      => $source,
      description => $description,
    );
    
    push @$rows, \%row;
  }
  
  my $sv_table = $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'location asc' ] });
  
  return $self->display_table_with_toggle_button($title, $table_id, $table_id eq 'sv', $sv_table);
}

sub cnv_probe_table {
  my $self     = shift;
  my $slice    = shift;
  my $columns  = shift;
  my $hub      = $self->hub;
  my $title    = 'Copy number variants probes';
  my $table_id = 'cnv';
  my $rows;
  
  foreach my $svf (@{$slice->get_all_CopyNumberVariantProbeFeatures}) {
    my $name        = $svf->variation_name;
    my $sv          = $svf->structural_variation;
    my $description = $sv->source_description;
    my $sv_class    = $sv->var_class;
    my $source      = $sv->source;
    my ($ext_ref, $study_url, $study_name);
    
    if ($sv->study) {
      $ext_ref    = $sv->study->external_reference;
      $study_name = $sv->study->name;
    }
    
    # Add study information
    if ($sv->study) {
      $ext_ref    = $sv->study->external_reference;
      $study_name = $sv->study->name;
    }
    
    if ($ext_ref =~ /pubmed\/(.+)/) {
      my $pubmed_id   = $1;
      my $pubmed_link = $hub->get_ExtURL('PUBMED', $pubmed_id);
         $description =~ s/$pubmed_id/'<a href="'.$pubmed_link.'" target="_blank">'.$&.'<\/a>'/eg;
    }
      
    # SV size (format the size with comma separations, e.g: 10000 to 10,000)
    my $sv_size    = $svf->end - $svf->start + 1;
    my $int_length = length $sv_size;
    
    if ($int_length > 3) {
      my $nb         = 0;
      my $int_string = '';
      
      while (length $sv_size > 3) {
        $sv_size    =~ /(\d{3})$/;
        $int_string = ",$int_string" if $int_string ne '';
        $int_string = "$1$int_string";
        $sv_size    = substr $sv_size, 0, (length($sv_size) - 3);
      }
      
      $sv_size = "$sv_size,$int_string";
    }
    
    my $sv_link = $hub->url({
      type   => 'StructuralVariation',
      action => 'Summary',
      sv     => $name
    });      

    my $loc_string = $svf->seq_region_name . ':' . $svf->seq_region_start . '-' . $svf->seq_region_end;
        
    my $loc_link = $hub->url({
      type   => 'Location',
      action => 'View',
      r      => $loc_string,
    });
      
    my %row = (
      id          => qq{<a href="$sv_link">$name</a>},
      location    => qq{<a href="$loc_link">$loc_string</a>},
      size        => $sv_size,
      class       => $sv_class,
      source      => $source,
      description => $description,
    );
    
    push @$rows, \%row;
  }
  
  my $cnv_table = $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'location asc' ] });
  return $self->display_table_with_toggle_button($title, $table_id, 0, $cnv_table);
}


sub display_table_with_toggle_button {
  my $self  = shift;
  my $title = shift;
  my $id    = shift;
  my $state = shift;
  my $table = shift;
  
  my $is_show = 'show';
  my $is_open = 'open';
  if ($state==0) {
    $is_show = 'hide';
    $is_open = 'closed';
  }
  
  $table->add_option('data_table', "toggle_table $is_show");
  $table->add_option('id', $id.'_table');
  my $html = qq{
    <div>
      <h2 style="float:left">$title</h2>
      <span class="toggle_button" id="$id"><em class="$is_open" style="margin:5px"></em></span>
      <p class="invisible">.</p>
    </div>\n
  };
  $html .= $table->render;  
  $html .= qq{<br />};
    
  return $html;
}
1;
