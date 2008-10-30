package EnsEMBL::Web::Component::Variation::Mappings;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Variation);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}


sub content {
  my $self = shift;
  my $object = $self->object;
  my $html = '';

  ## first check we have a location
  unless ($object->core_objects->location ){
   $html = "<p>You must select a location from the panel above to see this information</p>";
   return $html;
  }

  my %mappings = %{ $object->variation_feature_mapping };

  return [] unless keys %mappings;

  my $source = $object->source;
  my $name = $object->name;
 
  my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );
  $table->add_columns(
      { 'key' => 'gene',          'title' =>'Gene'},
      { 'key' => 'trans',         'title' =>'Transcript'},
      { 'key' => 'type',          'title' =>'Type'},     
      { 'key' => 'trans_pos',     'title' =>'Relative position in transcript', 'align' =>'center'},
      { 'key' => 'prot_pos',      'title' =>'Relative position in protein',    'align' => 'center'},
      { 'key' => 'aa',            'title' =>'Amino acid'},
  );

  
  my $tsv_species =  ($object->species_defs->VARIATION_STRAIN &&  $object->species_defs->get_db eq 'core') ? 1 : 0;
  my $location = $object->core_objects->{'parameters'}{'r'};

  my $gene_adaptor = $object->database('core')->get_GeneAdaptor();
  my %genes;

  foreach my $varif_id (keys %mappings) {
    ## Check vari feature matches the location we are intrested in
    my $region = $mappings{$varif_id}{Chr};
    my $start  = $mappings{$varif_id}{start};
    my $end    = $mappings{$varif_id}{end};
    my $v_loc  = $region.":".$start . "-" . $end;
    next unless ($v_loc eq $location);
   
    my @transcript_variation_data = @{ $mappings{$varif_id}{transcript_vari} };
    unless( scalar @transcript_variation_data ) {      
      next;
    }

    foreach my $transcript_data (@transcript_variation_data ) {
      my $gene = $gene_adaptor->fetch_by_transcript_stable_id($transcript_data->{transcriptname}); 
      my $gene_name = $gene->stable_id if $gene;
      my $trans_name = $transcript_data->{transcriptname};
      my $gene_link = qq(<a href="/@{[$object->species]}/Gene/Variation_Gene?db=core;g=$gene_name;v=$name;source=$source;">$gene_name</a>);
      my $transcript_link = qq(<a href="/@{[$object->species]}/Transcript/Population?db=core;t=$trans_name;v=$name;source=$source">$trans_name</a>);
      my $trans_coords = _sort_start_end(
                     $transcript_data->{cdna_start}, $transcript_data->{cdna_end});
      my $pep_coords = _sort_start_end(
                     $transcript_data->{translation_start}, $transcript_data->{translation_end});

      my $type = $transcript_data->{conseq};
      my $aa =   $transcript_data->{pepallele} || 'n/a';

      ## Now need to add to data to a row, and process rows somehow so that a gene ID is only displayed once, regardless of the number of transcripts;
      
      my $row = {};
      $row->{'trans'} =   $transcript_link;
      $row->{'type'} = $type;
      $row->{'trans_pos'} = $trans_coords;
      $row->{'prot_pos'}  = $pep_coords;
      $row->{'aa'}  = $aa;
         
      if (exists $genes{$gene_name}){ 
         my @temp = @{$genes{$gene_name}};   
         push (@temp, $row);
         $genes{$gene_name} = \@temp;
      } else {
         $row->{'gene'} = $gene_link;
         my @temp;
         push (@temp, $row);
         $genes{$gene_name} = \@temp; 
      }
    }

    foreach my $g (keys %genes){
      my @rows = @{$genes{$g}};
      foreach my $row(@rows){ 
        $table->add_row($row);
      }
    }
   
  }


 return $table->render;
}

sub _sort_start_end {

 ### Mapping_table
 ### Arg1     : start and end coordinate
 ### Example  : $coord = _sort_star_end($start, $end)_
 ### Description : Returns $start-$end if they are defined, else 'n/a'
 ### Returns  string

  my ( $start, $end ) = @_;
  if ($start or $end){
    return " $start-$end&nbsp;";
  }
  else {return " n/a&nbsp;"};
}



1;
